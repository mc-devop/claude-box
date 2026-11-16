// What the parts show, from what git and run-actions printed. No $ here:
// a hooks module's $ never crosses an import.
import type { ActionsStatus, Groups, HeldMessage } from '../types'

// The status line for a branch (from git rev-parse --abbrev-ref HEAD) and
// how far it is behind local main.
export function branchLine(branch: string, behind: number): string {
  if (branch === 'main') return "main: Claude doesn't commit here"
  if (branch === 'HEAD') return 'detached HEAD'
  return behind > 0 ? `${branch} · ${behind} behind main` : branch
}

// run-actions --status's key=value lines.
export function parseStatus(out: string): ActionsStatus {
  const kv = new Map(out.split('\n').map(l => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]))
  return {
    title: kv.get('title') ?? '',
    pending: Number(kv.get('pending') ?? 0),
    last: (kv.get('last') ?? 'none') as ActionsStatus['last'],
    ran: kv.get('ran') ?? '',
    reason: kv.get('reason') ?? '',
  }
}

// The toast for a run that ended since `before`, or null. A run longer than a
// poll was seen running, with the same ran as when it ends.
export function runToast(before: ActionsStatus | null, now: ActionsStatus): string | null {
  if (before === null || now.ran === '' || (now.ran === before.ran && now.last === before.last)) return null
  if (now.last === 'passed') return `dev run passed: ${now.title}`
  if (now.last === 'aborted') return `dev run aborted at ${now.reason}`
  return null
}

export function bandLine(s: ActionsStatus): string {
  return `dev run: ${s.title}, ${s.pending === 1 ? '1 step' : `${s.pending} steps`} to run`
}

// Claude Code wraps a message between boxes in a tag naming the sender:
// <cross-session-message from="..." from-name="<name>" ...> ... </cross-session-message>
const WRAPPER = /^\s*<cross-session-message\b[^>]*>/
const CLOSE = /<\/cross-session-message>\s*$/

// The sender's name from the wrapper, or null.
export function sender(text: string): string | null {
  const open = WRAPPER.exec(text)
  const name = open ? /\bfrom-name="([^"]*)"/.exec(open[0]) : null
  return name ? name[1] : null
}

// A held message's row: its own first line, which the sending rule makes
// "From <project>: <summary>"; the sender's name in front if it isn't.
export function firstLine(text: string): string {
  const body = text.replace(WRAPPER, '').replace(CLOSE, '')
  const line = body.split('\n').find(l => l.trim() !== '')?.trim() ?? ''
  const name = sender(text)
  return name !== null && !line.startsWith('From ') ? `From ${name}: ${line}` : line
}

export function heldToast(text: string): string {
  return `Held for you: ${firstLine(text)}`
}

// Where the sender keeps its copy, should this session end first: at its
// path from the group file, or /projects/<sender>; remote: another machine.
export function senderCopy(project: string, from: string | null, path: string | null): string {
  if (path === 'remote') return "If this session ends first, the sender's copy stays in its project, on another machine."
  return `If this session ends first, the sender's copy stays: ${path ?? `/projects/${from ?? '<sender>'}`}/out/handoff-${project}.md`
}

// /etc/claude-box/groups as dev writes it: "group <name>", then
// "member <name> <path under /projects, or remote>" lines (a path may hold
// spaces, a name can't), and "autotake group" last when the owner's config
// has it. A line of another shape counts for nothing. Null without a group.
export function parseGroups(text: string): Groups | null {
  const lines = text.split('\n').filter(l => l !== '')
  const name = /^group ([A-Za-z0-9][A-Za-z0-9._-]*)$/.exec(lines[0] ?? '')?.[1]
  if (name === undefined) return null
  const members = lines.flatMap(l => {
    const m = /^member ([A-Za-z0-9][A-Za-z0-9._-]*) (\/projects\/.+|remote)$/.exec(l)
    return m ? [{ name: m[1], path: m[2] }] : []
  })
  return { name, members, autotake: lines.length > 1 && lines[lines.length - 1] === 'autotake group' }
}

// A sender is a member when it has the member's name, or that name plus
// the short suffix Remote Control may add (claude-box-d2).
export function matchesMember(sender: string, member: string): boolean {
  if (sender === member) return true
  return sender.startsWith(`${member}-`) && /^[a-z0-9]{1,4}$/.test(sender.slice(member.length + 1))
}

// What Take it puts in the prompt box; the owner's Enter sends it.
export function takeText(text: string): string {
  return `Message from another session (read it before you press Enter):\n\n${text}`
}

// What /autotake sends on as the owner's prompt, with no Enter.
export function autoText(text: string): string {
  return `Message from another session (let through by your /autotake):\n\n${text}`
}

// The same for a group member, let through by the owner's autotake group.
export function autoGroupText(text: string): string {
  return `Message from another session (let through by your autotake group):\n\n${text}`
}

// /autotake's answer: the senders let through, the group's members first
// while its trust is on, or that there are none.
export function autoLine(senders: readonly string[], group: { name: string; members: readonly string[] } | null): string {
  if (senders.includes('*')) return 'Taking messages from every session as your prompt until /autotake off.'
  const parts = [
    ...(group !== null ? [`group ${group.name} (${group.members.length > 0 ? group.members.join(', ') : 'no other members yet'})`] : []),
    ...(senders.length > 0 ? [senders.join(', ')] : []),
  ]
  if (parts.length === 0) return 'Autotake is off; messages are held for you.'
  return `Taking messages from ${parts.join(' and from ')} as your prompt until /autotake off.`
}

// The row after a restart offering last session's autotake back.
export function offerLine(senders: readonly string[]): string {
  return `Autotake was on last session for ${senders.includes('*') ? 'every session' : senders.join(', ')} `
}

// The held message an argument names: its number, or the oldest when none.
export function pick(held: readonly HeldMessage[], args: string): HeldMessage | undefined {
  const n = args.trim()
  return n === '' ? held[0] : held.find(m => m.id === n)
}

// What Claude is told when a run ended since `before`, or null: the title
// and the step only; the log's own text stays in the log for Claude to read.
export function runPrompt(before: ActionsStatus | null, now: ActionsStatus): string | null {
  if (runToast(before, now) === null) return null
  const how = now.last === 'passed' ? 'passed' : `aborted at ${/^step \d+/.exec(now.reason)?.[0] ?? 'a step'}`
  return `dev run finished: ${now.title}, ${how}. Read out/actions.log and carry on.`
}

// The folders in out/done that expire: named YYYY-MM-DD, the day a draft was
// used, and more than 14 days before today (YYYY-MM-DD).
export function expiredDone(entries: { name: string; kind: string }[], today: string): string[] {
  const cutoff = Date.parse(today) - 14 * 86_400_000
  return entries
    .filter(e => e.kind === 'dir' && /^\d{4}-\d{2}-\d{2}$/.test(e.name) && Date.parse(e.name) < cutoff)
    .map(e => e.name)
}
