// node drive.mjs PORT URL STEP… — a tab opened at URL, then each STEP: sleep:MS · sh:COMMAND · tab:URL (another tab,
// left open behind this one) · a JavaScript expression; each answer printed as a line "JS expr => value"
import { execSync } from 'node:child_process';
const [port, url, ...steps] = process.argv.slice(2);
const base = `http://127.0.0.1:${port}`;
const open = async u => (await fetch(`${base}/json/new?${encodeURIComponent(u)}`, { method: 'PUT' })).json();
const conn = t => new Promise(res => { const ws = new WebSocket(t.webSocketDebuggerUrl); let id = 0; const wait = new Map();
  ws.onmessage = m => { const d = JSON.parse(m.data); if (d.id && wait.has(d.id)) { wait.get(d.id)(d); wait.delete(d.id); } };
  ws.onopen = () => res({ send: (method, params = {}) => new Promise(r => { const i = ++id; wait.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); }) }); });
const c = await conn(await open(url));
await c.send('Page.enable'); await c.send('Page.bringToFront');
const loaded = async w => { for (let i = 0; i < 100; i++) { const r = await w.send('Runtime.evaluate', { expression: 'document.readyState + location.protocol', returnByValue: true }); if (r.result?.result?.value === 'completehttp:') return; await new Promise(r => setTimeout(r, 200)); } };
await loaded(c);
const say = async (who, s) => { const res = await Promise.race([who.send('Runtime.evaluate', { expression: s, awaitPromise: true, returnByValue: true, userGesture: true }), new Promise(r => setTimeout(() => r({ timeout: true }), 40000))]);
  console.log('JS', s.slice(0, 60), '=>', JSON.stringify(res.timeout ? 'TIMEOUT' : (res.result?.result?.value ?? res.result?.exceptionDetails?.exception?.description ?? res))); };
for (const s of steps) {
  if (s.startsWith('sleep:')) { await new Promise(r => setTimeout(r, +s.slice(6))); continue; }
  if (s.startsWith('sh:')) { try { process.stdout.write(execSync(s.slice(3), { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })); } catch (e) { console.log('SH-FAIL', e.message.slice(0, 300)); } continue; }
  if (s.startsWith('tab:')) { const u = s.slice(4); const t = await open(u); const o = await conn(t); await loaded(o); await say(o, 'play()'); await c.send('Page.bringToFront'); await new Promise(r => setTimeout(r, 600)); continue; }
  await say(c, s);
}
process.exit(0);
