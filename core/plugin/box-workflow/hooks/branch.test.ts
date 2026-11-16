import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

// git answers per command: the branch, and how far behind main it is.
function git(on: On, branch: string | null, behind: { code: number; out: string }) {
  on('process.run', ($, e) => ({ value: answer(e.argv.join(' ')) }))
  function answer(a: string) {
    if (a === 'git rev-parse --abbrev-ref HEAD') {
      return branch === null
        ? { exitCode: 128, stdout: '', stderr: 'fatal: not a git repository', isStdoutTruncated: false, isStderrTruncated: false }
        : { exitCode: 0, stdout: `${branch}\n`, stderr: '', isStdoutTruncated: false, isStderrTruncated: false }
    }
    if (a === 'git rev-list --count HEAD..main') {
      return { exitCode: behind.code, stdout: behind.out, stderr: '', isStdoutTruncated: false, isStderrTruncated: false }
    }
    if (a.startsWith('run-actions ')) {
      return { exitCode: 2, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false }
    }
    throw new Error(`unexpected command: ${a}`)
  }
}
function status(on: On): { text: string | undefined | null } {
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: undefined }))
  on('turn.complete', ($, e) => ({ text: e.answer, reason: 'answer' }))
  const seen = { text: null as string | undefined | null }
  on('ui.status', ($, e) => { seen.text = e.text; return { value: undefined } })
  return seen
}
const START = { cwd: '/work/p', surface: 'terminal', isInteractive: true } as const
const TURN = { answer: '', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' } as const

test('on main: marked', async ($, on) => {
  git(on, 'main', { code: 0, out: '0\n' })
  const s = status(on)
  await $.session.start(START)
  expect(s.text).toBe("main: Claude doesn't commit here")
})

test('a claude/ branch behind main: how far', async ($, on) => {
  git(on, 'claude/x', { code: 0, out: '3\n' })
  const s = status(on)
  await $.turn.complete(TURN)
  expect(s.text).toBe('claude/x · 3 behind main')
})

test('a claude/ branch up to date: the branch alone', async ($, on) => {
  git(on, 'claude/x', { code: 0, out: '0\n' })
  const s = status(on)
  await $.session.start(START)
  expect(s.text).toBe('claude/x')
})

test('detached HEAD', async ($, on) => {
  git(on, 'HEAD', { code: 0, out: '0\n' })
  const s = status(on)
  await $.session.start(START)
  expect(s.text).toBe('detached HEAD')
})

test('no main: the branch alone', async ($, on) => {
  git(on, 'claude/x', { code: 128, out: '' })
  const s = status(on)
  await $.session.start(START)
  expect(s.text).toBe('claude/x')
})

test('not a git repo: cleared, no error', async ($, on) => {
  git(on, null, { code: 0, out: '' })
  const s = status(on)
  await $.session.start(START)
  expect(s.text).toBe(undefined)
})
