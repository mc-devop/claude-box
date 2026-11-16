import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const OK = { isStdoutTruncated: false, isStderrTruncated: false, stderr: '' }
type World = { status: string; check: { code: number; out: string }; calls: string[]; toasts: string[]; prompts: string[] }

// run-actions answers from `w`; toasts and calls are recorded there.
function world(on: On, status: string): World {
  const w: World = { status, check: { code: 0, out: 'ok\n' }, calls: [], toasts: [], prompts: [] }
  on('process.run', ($, e) => {
    const a = e.argv.join(' ')
    w.calls.push(a)
    if (a === 'run-actions --status out/actions.txt') return { value: { ...OK, exitCode: 0, stdout: w.status } }
    if (a === 'run-actions --check out/actions.txt') return { value: { ...OK, exitCode: w.check.code, stdout: w.check.out } }
    if (a.startsWith('git ')) return { value: { ...OK, exitCode: 128, stdout: '' } }
    throw new Error(`unexpected command: ${a}`)
  })
  on('ui.toast', ($, e) => { w.toasts.push(e.text); return { value: undefined } })
  on('prompt.submit', ($, e) => { w.prompts.push(e.text); return { text: e.text } })
  on('ui.status', () => ({ value: undefined }))
  // The engine's own band: empty.
  on('ui.render', ($, e) => h($.ui.resolve(e).Box, {}))
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: undefined }))
  on('tool.call', () => ({ result: { text: 'written', isError: false } }))
  return w
}
const st = (title: string, pending: number, last = 'none', ran = '', reason?: string) =>
  `title=${title}\npending=${pending}\nlast=${last}\nran=${ran}\n` + (reason ? `reason=${reason}\n` : '')
const START = { cwd: '/work/p', surface: 'terminal', isInteractive: true } as const
const BAND = { component: 'AbovePrompt', props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 80 } } as const

test('a write to out/actions.txt is checked; a problem is a toast', async ($, on) => {
  const w = world(on, st('job', 1))
  w.check = { code: 1, out: 'step 2: no > explanation above it\nstep 3: runs dev (the owner runs dev commands)\n' }
  await $.tool.call({ tool: 'Write', file_path: '/work/p/out/actions.txt', content: 'x' })
  expect(w.calls).toContain('run-actions --check out/actions.txt')
  expect(w.toasts).toEqual(['out/actions.txt: step 2: no > explanation above it'])
})

test('a clean out/actions.txt: no toast; other files: not checked', async ($, on) => {
  const w = world(on, st('job', 1))
  await $.tool.call({ tool: 'Edit', file_path: '/work/p/out/actions.txt', old_string: 'a', new_string: 'b' })
  await $.tool.call({ tool: 'Write', file_path: '/work/p/README.md', content: 'x' })
  expect(w.calls.filter(c => c.includes('--check'))).toEqual(['run-actions --check out/actions.txt'])
  expect(w.toasts).toEqual([])
})

test('steps to run: the band', async ($, on) => {
  world(on, st('Merge x, push', 2))
  await $.session.start(START)
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ plugin: 'box-workflow', surface, ...BAND })
    expect(await ui.find({ text: 'dev run: Merge x, push, 2 steps to run' })).toBeDefined()
    await ui.unmount()
  }
})

test('nothing to run, or no out/actions.txt: no band, no toast', async ($, on) => {
  const w = world(on, st('', 0))
  await $.session.start(START)
  const ui = await $.ui.mount({ plugin: 'box-workflow', surface: 'terminal', ...BAND })
  expect(await ui.find({ text: /dev run/ })).toBeUndefined()
  expect(w.toasts).toEqual([])
})

test('a run ends: one toast for passed, one for aborted', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on, st('job', 2))
  await $.session.start(START)
  w.status = st('job', 0, 'passed', '2026-10-07T10:00:00+02:00')
  await clock.advance(10_000)
  await clock.advance(10_000)
  expect(w.toasts).toEqual(['dev run passed: job'])
  w.status = st('job2', 1, 'aborted', '2026-10-07T11:00:00+02:00', 'step 2: unexpected output')
  await $.tool.call({ tool: 'Write', file_path: '/work/p/out/actions.txt', content: 'x' })
  expect(w.toasts).toEqual(['dev run passed: job', 'dev run aborted at step 2: unexpected output'])
})

test('a log from another file: no toast', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on, st('job', 2))
  await $.session.start(START)
  w.status = st('job', 2, 'none')
  await clock.advance(10_000)
  expect(w.toasts).toEqual([])
})

test('if the check fails to run, the write still returns its result', async ($, on) => {
  on('process.run', () => { throw new Error('no run-actions') })
  on('tool.call', () => ({ result: { text: 'written', isError: false } }))
  on('ui.toast', () => ({ value: undefined }))
  const r = await $.tool.call({ tool: 'Write', file_path: '/work/p/out/actions.txt', content: 'x' })
  expect(r).toEqual({ result: { text: 'written', isError: false } })
})

const TURN = { answer: '', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' } as const

test('written with Bash: after the turn, the band, and the check once', async ($, on) => {
  const w = world(on, st('', 0))
  on('turn.complete', ($, e) => ({ text: e.answer, reason: 'answer' }))
  await $.session.start(START)
  w.status = st('job', 2)
  w.check = { code: 1, out: 'step 1: no > explanation above it\n' }
  await $.turn.complete(TURN)
  await $.turn.complete(TURN)
  const ui = await $.ui.mount({ plugin: 'box-workflow', surface: 'terminal', ...BAND })
  expect(await ui.find({ text: 'dev run: job, 2 steps to run' })).toBeDefined()
  expect(w.toasts).toEqual(['out/actions.txt: step 1: no > explanation above it'])
})

test('no out/actions.txt: a turn runs no check', async ($, on) => {
  const w = world(on, st('', 0))
  on('turn.complete', ($, e) => ({ text: e.answer, reason: 'answer' }))
  await $.session.start(START)
  await $.turn.complete(TURN)
  expect(w.calls.filter(c => c.includes('--check'))).toEqual([])
  expect(w.toasts).toEqual([])
})

test('a run ends: Claude is told to read the log and carry on, without the log\'s text', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on, st('job', 2))
  await $.session.start(START)
  w.status = st('job', 0, 'passed', '2026-10-07T10:00:00+02:00')
  await clock.advance(10_000)
  await clock.advance(1)
  w.status = st('job2', 1, 'aborted', '2026-10-07T11:00:00+02:00', 'step 2: unexpected output: rm -rf token=abc')
  await $.tool.call({ tool: 'Write', file_path: '/work/p/out/actions.txt', content: 'x' })
  await clock.advance(1)
  expect(w.prompts).toEqual([
    'dev run finished: job, passed. Read out/actions.log and carry on.',
    'dev run finished: job2, aborted at step 2. Read out/actions.log and carry on.',
  ])
})

test('no run ended: Claude gets no prompt', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on, st('job', 2))
  await $.session.start(START)
  await clock.advance(10_000)
  await clock.advance(1)
  expect(w.prompts).toEqual([])
})

test('a run ends after /clear: Claude is still told', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on, st('job', 2))
  // $.state as the session keeps it, so /clear can empty it.
  const kept = new Map<string, unknown>()
  on('state.get', ($, e) => ({ value: { value: kept.get(e.key), version: 0 } }))
  on('state.set', ($, e) => { kept.set(e.key, e.value); return { value: { isSet: true, version: 0 } } })
  on('session.end', () => ({ sessionId: 's1' }))
  await $.session.start(START)
  // /clear: the session ends, its $.state goes, no session.start follows.
  await $.session.end({ reason: 'clear' })
  kept.clear()
  w.status = st('job', 0, 'passed', '2026-10-07T10:00:00+02:00')
  await clock.advance(10_000)
  await clock.advance(1)
  expect(w.prompts).toEqual(['dev run finished: job, passed. Read out/actions.log and carry on.'])
})

test('a run longer than a poll: Claude is told when it ends', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on, st('job', 2))
  await $.session.start(START)
  // A poll sees it running: same ran as when it ends.
  w.status = st('job', 1, 'running', '2026-10-07T10:00:00+02:00')
  await clock.advance(10_000)
  w.status = st('job', 0, 'passed', '2026-10-07T10:00:00+02:00')
  await clock.advance(10_000)
  await clock.advance(1)
  expect(w.toasts).toEqual(['dev run passed: job'])
  expect(w.prompts).toEqual(['dev run finished: job, passed. Read out/actions.log and carry on.'])
})
