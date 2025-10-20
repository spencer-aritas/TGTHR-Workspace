export async function postSync(path: string, body: unknown) {
  try {
    const res = await fetch(`/api${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    if (res.status === 202) return { queued: true }               // SW fallback
    if (res.ok) return await res.json().catch(() => ({}))         // normal success
    throw new Error(await res.text().catch(() => 'Request failed'))
  } catch {
    // if SW didn't catch it for some reason, still act as queued
    return { queued: true }
  }
}