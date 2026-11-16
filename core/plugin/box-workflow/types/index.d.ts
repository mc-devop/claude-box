// What `run-actions --status` printed last: the job in out/actions.txt.
export type ActionsStatus = {
  title: string
  pending: number
  last: 'none' | 'passed' | 'aborted' | 'running'
  ran: string
  reason: string
}

// The project's group, from /etc/claude-box/groups (dev writes it).
export type Groups = { name: string; members: { name: string; path: string }[]; autotake: boolean }

// A message from another session, held until the owner takes or drops it.
export type HeldMessage = { id: string; text: string; at: number }

declare module 'claude-code' {
  interface PluginState {
    'box-workflow': {
      actions: ActionsStatus | null
      autotake: string[]
      group: Groups | null
      groupTrust: boolean
      inbox: HeldMessage[]
      offer: string[] | null
      open: string | null
      project: string
    }
  }
}
