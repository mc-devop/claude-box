import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import { expiredDone } from './lines'

const OK = { isStdoutTruncated: false, isStderrTruncated: false, stderr: '' }
type Entry = { name: string; kind: 'file' | 'dir' | 'other'; size: number; mtimeMs: number; isLink: boolean }
type World = { done: Entry[] | null; rmCode: number; removed: string[]; commands: string[] }

const dir = (name: string): Entry => ({ name, kind: 'dir', size: 0, mtimeMs: 0, isLink: false })
const file = (name: string): Entry => ({ name, kind: 'file', size: 1, mtimeMs: 1, isLink: false })
const link = (name: string): Entry => ({ name, kind: 'other', size: 0, mtimeMs: 0, isLink: true })

// out/done lists as `w.done` (null: missing); rm and the registered
// commands are recorded there. Today is 2026-10-17.
function world(on: On, done: Entry[] | null): World {
  const w: World = { done, rmCode: 0, removed: [], commands: [] }
  on('process.run', ($, e) => {
    if (e.argv[0] === 'rm') {
      w.removed.push(e.argv.join(' '))
      return { value: { ...OK, exitCode: w.rmCode, stdout: '' } }
    }
    if (e.argv[0] === 'run-actions') return { value: { ...OK, exitCode: 0, stdout: 'title=\npending=0\n' } }
    return { value: { ...OK, exitCode: 128, stdout: '' } }
  })
  on('fs.list', ($, e) => {
    if (e.path.endsWith('/out/done') && w.done !== null) return { value: w.done }
    throw Object.assign(new Error(`ENOENT: ${e.path}`), { code: 'ENOENT' })
  })
  on('clock.now', () => ({ value: Date.parse('2026-10-17T09:00:00Z') }))
  on('ui.status', () => ({ value: undefined }))
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => { w.commands.push(e.name); return { value: undefined } })
  return w
}
const START = { cwd: '/work/p', surface: 'terminal', isInteractive: true } as const

test('only date folders more than 14 days old expire', () => {
  const entries = [dir('2026-10-01'), dir('2026-10-03'), dir('2026-10-10'), dir('old'), file('2026-09-01'), link('2026-09-02')]
  expect(expiredDone(entries, '2026-10-17')).toEqual(['2026-10-01'])
})

test('session start deletes the expired folders in out/done and nothing else', async ($, on) => {
  const w = world(on, [dir('2026-10-01'), dir('2026-10-10'), dir('old')])
  await $.session.start(START)
  expect(w.removed).toEqual(['rm -rf -- out/done/2026-10-01'])
})

test('without out/done, session start deletes nothing and goes on', async ($, on) => {
  const w = world(on, null)
  await $.session.start(START)
  expect(w.removed).toEqual([])
  expect(w.commands).toContain('take')
})

test('a failed delete does not stop session start', async ($, on) => {
  const w = world(on, [dir('2026-09-01')])
  w.rmCode = 1
  await $.session.start(START)
  expect(w.removed).toEqual(['rm -rf -- out/done/2026-09-01'])
  expect(w.commands).toContain('take')
})
