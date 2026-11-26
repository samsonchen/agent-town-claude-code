// Tests for the hooks in hooks/register.ts: what reaches the app when /compact runs.
// Run: claude plugin test plugin

import { describe, expect, mock, test } from 'claude-code/testing'

type Posted = { type: string; [k: string]: unknown }

/** The engine and an app beneath the plugin; returns the events the app received. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
/** A command typed by the user at a terminal, as the engine stamps it. */
const typed = { origin: { kind: 'composer' as const }, presentation: { isFullscreen: false, columns: 80 } }

function world(on: any, repoFound: Promise<void> = Promise.resolve()) {
  const clock = mock.clock(on, { now: 1_000_000 })
  mock.store(on)
  const posted: Posted[] = []
  on('session.id', () => ({ value: 'session-1' }))
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  on('env.get', (_: any, e: any) => ({ value: e.name === 'HOME' ? '/home/test' : undefined }))
  on('session.repo', async () => {
    await repoFound
    return { value: { root: '/work/town', remote: 'github.com/example/town' } }
  })
  on('session.root', () => ({ value: '/work/town' }))
  on('settings.read', () => ({ value: {} }))
  on('session.version', () => ({ value: { version: '2.1.319' } }))
  on('session.model', () => ({ value: 'claude-opus-5-5' }))
  on('session.usage', () => ({ value: undefined }))
  on('command.register', () => ({ value: { command: 'town' } }))
  on('fs.exists', () => ({ value: true }))
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  on('fs.read', (_: any, e: any) =>
    /[\\/]\.claude-plugin[\\/]plugin\.json$/.test(String(e.path)) // Windows hosts pass backslash paths
      ? { value: JSON.stringify({ name: 'town-link', version: '9.8.7' }) }
      : { value: JSON.stringify({ protocol: 1, port: 50000, token: 'test-token' }) })
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  on('http.fetch', (_: any, e: any) => {
    const body = JSON.parse(String(e.init?.body ?? e.body ?? '{}')) as { events?: Posted[] }
    posted.push(...(body.events ?? []))
    return { value: { status: 204, headers: {}, text: '' } }
  })
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  on('session.start', (_: any, e: any) => ({ cwd: e.cwd }))
  return { clock, posted }
}

const compactEvents = (posted: Posted[]) =>
  posted.filter(ev => ev.type.startsWith('compact.')).map(({ type, trigger, outcome, tokensBefore, tokensAfter }) => ({
    type,
    ...(trigger !== undefined ? { trigger } : {}),
    ...(outcome !== undefined ? { outcome } : {}),
    ...(tokensBefore !== undefined ? { tokensBefore } : {}),
    ...(tokensAfter !== undefined ? { tokensAfter } : {}),
  }))

describe('/compact', () => {
  test('shows even when no session.compact is raised inside the command', async ($, on) => {
    const { clock, posted } = world(on)
    // Another plugin (or a precomputed summary) compacts without raising session.compact.
    on('command.run', () => ({}))

    await $.session.start({ cwd: '/work/town', surface: 'terminal', isInteractive: true })
    await $.command.run({ command: 'compact', args: '', ...typed })
    await clock.advance(1_000)

    expect(compactEvents(posted)).toEqual([
      { type: 'compact.start', trigger: 'manual' },
      { type: 'compact.end', outcome: 'done' },
    ])
  })

  test('a failed /compact ends the scene', async ($, on) => {
    const { clock, posted } = world(on)
    on('command.run', () => {
      throw new Error('compaction failed')
    })

    await $.session.start({ cwd: '/work/town', surface: 'terminal', isInteractive: true })
    await $.command.run({ command: 'compact', args: '', ...typed }).catch(() => undefined)
    await clock.advance(1_000)

    expect(compactEvents(posted)).toEqual([
      { type: 'compact.start', trigger: 'manual' },
      { type: 'compact.end', outcome: 'failed' },
    ])
  })
})

describe('Stop hook', () => {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const note = ($: any, text: string, agentId?: string) =>
    $.session.append({
      message: { type: 'user', role: 'user', isMeta: true, content: [{ type: 'text', text }] },
      door: 'note',
      origin: { kind: 'engine' },
      uuid: 'note-1',
      ...(agentId ? { agentId } : {}),
    })

  test("a Stop block's reason reaches the app with the return", async ($, on) => {
    const { clock, posted } = world(on)

    await $.session.start({ cwd: '/work/town', surface: 'terminal', isInteractive: true })
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await ($.prompt as any).submit({ text: 'fix the login bug' }).catch(() => undefined)
    await note($, 'Stop hook feedback:\nTests are failing')
    await clock.advance(1_000)

    const returns = posted.filter(ev => ev.type === 'ticket.return')
    expect(returns.map(ev => ev.reason)).toEqual(['Tests are failing'])
  })

  test("another note, or a subagent's, is no return", async ($, on) => {
    const { clock, posted } = world(on)

    await $.session.start({ cwd: '/work/town', surface: 'terminal', isInteractive: true })
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await ($.prompt as any).submit({ text: 'fix the login bug' }).catch(() => undefined)
    await note($, 'Some other note')
    await note($, 'Stop hook feedback:\nNot done', 'agent-1')
    await clock.advance(1_000)

    expect(posted.filter(ev => ev.type === 'ticket.return')).toEqual([])
  })
})

describe('/town', () => {
  test('shows the plugin version from plugin.json', async ($, on) => {
    world(on)

    await $.session.start({ cwd: '/work/town', surface: 'terminal', isInteractive: true })
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const result = (await $.command.run({ command: 'town', args: '', ...typed })) as any
    expect(String(result.text).split('\n')[0]).toBe('Version 9.8.7.')
  })
})

describe('session start', () => {
  test('an event raised while the session is still starting carries its project and session', async ($, on) => {
    // Right after a reboot, finding the repository can take a while; the context is measured meanwhile.
    let release: () => void = () => {}
    const { clock, posted } = world(on, new Promise<void>(r => (release = r)))

    const started = $.session.start({ cwd: '/work/town', surface: 'terminal', isInteractive: true })
    await clock.advance(10)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await ($.session as any).measure({ changed: ['context'], context: { window: 1_000_000, used: 20_000 } }).catch(() => undefined)
    release()
    await started
    await clock.advance(1_000)

    const open = posted[0]
    expect(open?.type).toBe('session.open')
    expect(open?.projectId).toMatch(/^[0-9a-f]{16}$/)
    expect(posted.map(ev => [ev.type, ev.sessionId, ev.projectId]).filter(([, s, p]) => s !== 'session-1' || p !== open?.projectId)).toEqual([])
  })
})
