import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { ActionsStatus } from '../types'

import { autoGroupText, autoLine, autoText, bandLine, branchLine, expiredDone, firstLine, heldToast, matchesMember, offerLine, parseGroups, parseStatus, pick, runPrompt, runToast, sender, senderCopy, takeText } from './lines'

// claude-box's mods: messages from other sessions held for the owner's go,
// the job in out/actions.txt (run-actions, in the image, reads it), and the
// branch in the status line.
const actions = atom({ plugin: 'box-workflow', key: 'actions' } as const, null)
// Senders whose messages go on as the owner's prompt, set by /autotake;
// '*' (from /autotake on) is every sender.
const autotake = atom({ plugin: 'box-workflow', key: 'autotake' } as const, [])
// The project's group from /etc/claude-box/groups, which dev mounts
// read-only: Claude can't widen it. Its trust is on with the owner's
// "autotake group" until /autotake off; it's never stored or offered back.
const group = atom({ plugin: 'box-workflow', key: 'group' } as const, null)
const groupTrust = atom({ plugin: 'box-workflow', key: 'groupTrust' } as const, false)
const inbox = atom({ plugin: 'box-workflow', key: 'inbox' } as const, [])
// Last session's autotake, kept in the plugin's store under the project. The
// store is a file in ~/.claude, which Claude can write: after a restart it's
// only offered back, until the owner presses Restore or Leave off.
const offer = atom({ plugin: 'box-workflow', key: 'offer' } as const, null)
const open = atom({ plugin: 'box-workflow', key: 'open' } as const, null)
const project = atom({ plugin: 'box-workflow', key: 'project' } as const, '')
// Deliveries that pass: the session's own agents (they carry an agentId) and
// the owner's own channels. Everything else, unknown kinds too, is held.
const PASS = new Set(['bridge', 'task-notification', 'scheduled-trigger', 'slack-ping'])
// Backstop at prompt.submit: another session's message as a prompt.
const OTHER_SESSION = new Set(['peer', 'peer-send-message', 'projects-relay', 'coordinator'])
// How Claude Code frames a subagent's report to its session.
const AGENT_MESSAGE = /^<agent-message from="([^"]+)">/
// /take and /dismiss run only when the owner typed them: at the terminal or
// through Remote Control (the phone, where the band's buttons don't act).
const OWNER = new Set(['composer', 'bridge'])
const FILE = 'out/actions.txt'
const POLL_MS = 10_000

let timer: { cancel: () => void } | null = null
// The job's state as last read. /clear empties $.state but keeps this and the
// timer; a reload keeps $.state but starts this over.
let seen: ActionsStatus | null = null
// What the last check reported, so the same mistakes toast once.
let lastCheck = ''

// Sets autotake and keeps it for the project's next session. A store that
// fails only loses the offer after a restart.
async function setAutotake($: EngineInterface, list: string[]): Promise<void> {
  await update($, autotake, () => list)
  await update($, offer, () => null)
  const key = `autotake:${await read($, project)}`
  try {
    if (list.length === 0) await $.store.delete(key)
    else await $.store.set(key, list)
  } catch {}
}

// Reads the project's group; none, or a file that can't be read: no group.
async function loadGroup($: EngineInterface): Promise<void> {
  try {
    const r = await $.process.run(['cat', '/etc/claude-box/groups'])
    const g = r.exitCode === 0 ? parseGroups(r.stdout) : null
    await update($, group, () => g)
    await update($, groupTrust, () => g?.autotake ?? false)
  } catch {}
}

// The group member a sender is, or undefined.
async function memberOf($: EngineInterface, from: string | null): Promise<{ name: string; path: string } | undefined> {
  const g = await read($, group)
  return from === null || g === null ? undefined : g.members.find(m => matchesMember(from, m.name))
}

// The group for /autotake's answer, while its trust is on.
async function trustedGroup($: EngineInterface): Promise<{ name: string; members: string[] } | null> {
  const g = await read($, group)
  return g !== null && (await read($, groupTrust)) ? { name: g.name, members: g.members.map(m => m.name) } : null
}

// Offers last session's autotake back, if this session has none yet.
async function offerAutotake($: EngineInterface): Promise<void> {
  try {
    const kept = await $.store.get(`autotake:${await read($, project)}`)
    const list = Array.isArray(kept) ? kept.filter((s): s is string => typeof s === 'string' && s !== '') : []
    if (list.length > 0 && (await read($, autotake)).length === 0) await update($, offer, () => list)
  } catch {}
}

async function showBranch($: EngineInterface): Promise<void> {
  const head = await $.process.run(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])
  if (head.exitCode !== 0) {
    $.ui.status(undefined)
    return
  }
  const behind = await $.process.run(['git', 'rev-list', '--count', 'HEAD..main'])
  $.ui.status(branchLine(head.stdout.trim(), behind.exitCode === 0 ? Number(behind.stdout.trim()) : 0))
}

// Reads the job's state; a run that ended since the last read is a toast.
// Polls while there are steps to run or a run is going.
async function refreshActions($: EngineInterface): Promise<void> {
  const ran = await $.process.run(['run-actions', '--status', FILE])
  if (ran.exitCode !== 0) return
  const now = parseStatus(ran.stdout)
  const before = seen ?? (await read($, actions))
  seen = now
  const toast = runToast(before, now)
  const prompt = runPrompt(before, now)
  await update($, actions, () => now)
  if (toast !== null) $.ui.toast(toast)
  // Not from inside the hook that noticed, which may hold the turn: just after.
  if (prompt !== null) $.clock.after(0, () => void $.prompt.submit({ text: prompt }))
  const waiting = now.pending > 0 || now.last === 'running'
  if (waiting && timer === null) timer = $.clock.every(POLL_MS, () => void refreshActions($))
  if (!waiting && timer !== null) {
    timer.cancel()
    timer = null
  }
}

// Checks out/actions.txt; new mistakes are a toast.
async function checkActions($: EngineInterface): Promise<void> {
  const check = await $.process.run(['run-actions', '--check', FILE])
  const found = check.exitCode === 0 ? '' : (check.stdout.trim() || check.stderr.trim()).split('\n')[0]
  if (found !== '' && found !== lastCheck) $.ui.toast(`${FILE}: ${found}`)
  lastCheck = found
}

// Deletes the folders in out/done older than 14 days; used drafts are moved
// there under the day they were used. Nothing to sweep or a failure: no matter.
async function sweepDone($: EngineInterface): Promise<void> {
  try {
    const today = new Date(await $.clock.now()).toISOString().slice(0, 10)
    for (const name of expiredDone(await $.fs.list('out/done'), today))
      await $.process.run(['rm', '-rf', '--', `out/done/${name}`])
  } catch {}
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    await update($, project, () => e.cwd.split('/').filter(Boolean).pop() ?? '')
    await showBranch($)
    await refreshActions($)
    await sweepDone($)
    await loadGroup($)
    await offerAutotake($)
    // Last, so the parts above show even if registering fails.
    await $.command.register({ name: 'take', description: 'Send a held message on as your prompt', argumentHint: '[number]' })
    await $.command.register({ name: 'dismiss', description: 'Drop a held message', argumentHint: '[number]' })
    await $.command.register({ name: 'autotake', description: "Send a session's messages on as your prompt", argumentHint: '[sender | on | off]' })
    return started
  })

  // Also catches out/actions.txt written another way than Write or Edit.
  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    await showBranch($)
    await refreshActions($)
    const now = await read($, actions)
    if (now !== null && (now.title !== '' || now.pending > 0)) await checkActions($)
    return done
  })

  on('tool.call', async ($, e, next) => {
    const done = await next(e)
    if ((e.tool === 'Write' || e.tool === 'Edit') && e.file_path.endsWith(`/${FILE}`)) {
      lastCheck = ''
      await checkActions($)
      await refreshActions($)
    }
    return done
  })

  // Held: nothing is queued, shown or read by the model until the owner
  // takes it into the prompt box and presses Enter, or let its sender
  // through with /autotake (the sender as Claude Code's wrapper names it).
  on('session.receive', async ($, e, next) => {
    if (PASS.has(e.origin.kind) || e.agentId !== undefined) return next(e)
    const from = sender(e.text)
    if (from !== null && (await read($, autotake)).some(s => s === '*' || s === from)) {
      // Runs once the session is idle, as a plugin's prompt does.
      $.clock.after(0, () => void $.prompt.submit({ text: autoText(e.text), asUser: true }))
      $.ui.toast(`Taken by /autotake: ${firstLine(e.text)}`)
      return { consumed: 'sent on as the owner\'s prompt by /autotake' }
    }
    if ((await read($, groupTrust)) && (await memberOf($, from)) !== undefined) {
      $.clock.after(0, () => void $.prompt.submit({ text: autoGroupText(e.text), asUser: true }))
      $.ui.toast(`Taken by autotake group: ${firstLine(e.text)}`)
      return { consumed: 'sent on as the owner\'s prompt by autotake group' }
    }
    const held = await read($, inbox)
    const id = String(Math.max(0, ...held.map(m => Number(m.id))) + 1)
    const at = await $.clock.now()
    await update($, inbox, list => [...list, { id, text: e.text, at }])
    $.ui.toast(heldToast(e.text))
    return { consumed: 'held in the box-workflow inbox for the owner' }
  }).catch(($, e, next) =>
    // A hook that fails is skipped, which would deliver the message: refuse it
    // instead. The sender's copy in its out/ is still there.
    next.called ? next(e) : { consumed: 'box-workflow could not hold it; refused' },
  )

  // The output is a transcript line Claude reads: it names the number only.
  on('command.run', { command: 'take' }, async ($, e) => {
    if (!OWNER.has(e.origin.kind)) return { text: 'Only you can take a held message: type /take yourself.' }
    const m = pick(await read($, inbox), e.args)
    if (m === undefined) return { text: `No held message ${e.args.trim()}.` }
    await update($, inbox, list => list.filter(x => x.id !== m.id))
    // Not from inside the command, which would wait on itself: just after.
    $.clock.after(0, () => void $.prompt.submit({ text: takeText(m.text), asUser: true }))
    return { text: `Took held message ${m.id}.` }
  })

  on('command.run', { command: 'dismiss' }, async ($, e) => {
    if (!OWNER.has(e.origin.kind)) return { text: 'Only you can dismiss a held message: type /dismiss yourself.' }
    const m = pick(await read($, inbox), e.args)
    if (m === undefined) return { text: `No held message ${e.args.trim()}.` }
    await update($, inbox, list => list.filter(x => x.id !== m.id))
    return { text: `Dismissed held message ${m.id}.` }
  })

  on('command.run', { command: 'autotake' }, async ($, e) => {
    if (!OWNER.has(e.origin.kind)) return { text: 'Only you can turn on autotake: type /autotake yourself.' }
    const arg = e.args.trim()
    const list = await read($, autotake)
    if (arg === 'off') {
      await setAutotake($, [])
      await update($, groupTrust, () => false)
    } else if (arg === 'on') await setAutotake($, ['*'])
    else if (arg !== '') await setAutotake($, list.includes(arg) ? list : [...list, arg])
    return { text: autoLine(await read($, autotake), await trustedGroup($)) }
  })

  // Should a message from another session reach the prompt by a route that
  // skipped the hold, it's dropped there too. A subagent's report comes this
  // way as a peer's: it passes when the id it's framed with is this session's.
  on('prompt.submit', async ($, e, next) => {
    if (!OTHER_SESSION.has(e.origin.kind)) return next(e)
    const from = AGENT_MESSAGE.exec(e.text)?.[1]
    if (from !== undefined && (await $.agent.list()).some(a => a.id === from)) return next(e)
    return { drop: 'held for the owner: box-workflow' }
  }).catch(($, e, next) =>
    next.called || !OTHER_SESSION.has(e.origin?.kind) ? next(e) : { drop: 'box-workflow could not check it; refused' },
  )

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const now = await read($, actions)
    const held = await read($, inbox)
    const opened = await read($, open)
    const here = await read($, project)
    const offered = await read($, offer)
    const g = await read($, group)
    const pathOf = (from: string | null) => (from === null || g === null ? null : g.members.find(m => matchesMember(from, m.name))?.path ?? null)
    const showActions = now !== null && now.pending > 0
    if (e.props.hasSurvey || (!showActions && held.length === 0 && offered === null)) return next(e)
    const { Box, Button, Text } = $.ui.resolve(e)
    const drop = (id: string) => update($, inbox, list => list.filter(m => m.id !== id))
    return (
      <Box flexDirection="column">
        {offered !== null ? (
          <Box>
            <Text>{offerLine(offered)}</Text>
            <Button key="autotake-restore" label="Restore" onPress={() => setAutotake($, offered)} />
            <Button key="autotake-leave" label="Leave off" onPress={() => setAutotake($, [])} />
          </Box>
        ) : null}
        {held.map(m => (
          <Box key={`msg-${m.id}`} flexDirection="column">
            <Box>
              <Text>{`${m.id}. ${firstLine(m.text)} `}</Text>
              <Button key={`read-${m.id}`} label="Read" onPress={() => update($, open, o => (o === m.id ? null : m.id))} />
              <Button
                key={`take-${m.id}`}
                label="Take it"
                onPress={async () => {
                  await $.prompt.fill({ text: takeText(m.text), mode: 'replace' })
                  await drop(m.id)
                }}
              />
              <Button key={`dismiss-${m.id}`} label="Dismiss" onPress={() => drop(m.id)} />
            </Box>
            {opened === m.id ? <Text>{m.text}</Text> : null}
            {opened === m.id ? <Text dimColor>{senderCopy(here, sender(m.text), pathOf(sender(m.text)))}</Text> : null}
          </Box>
        ))}
        {showActions ? <Text>{bandLine(now)}</Text> : null}
      </Box>
    )
  })
}
