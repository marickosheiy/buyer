// Start Lumear's existing API without duplicating its login/database rules.
// This launcher requires Python; it is not a Node-only backend rewrite.
const { spawn, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = __dirname;
const backend = path.join(root, 'backend');
const cloud = path.join(backend, '.env.cloud');
const local = path.join(backend, '.env.mysql');
const config = process.argv.includes('--local') ? local :
  (fs.existsSync(cloud) ? cloud : local);
const env = { ...process.env };
if (fs.existsSync(config)) {
  for (const line of fs.readFileSync(config, 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/)) {
    if (!line.trim() || line.trimStart().startsWith('#')) continue;
    const split = line.indexOf('=');
    if (split < 1) continue;
    const key = line.slice(0, split).trim();
    let value = line.slice(split + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) value = value.slice(1, -1);
    if (env[key] === undefined) env[key] = value;
  }
}
env.HOST ||= env.NODE_ENV === 'production' ? '0.0.0.0' : '127.0.0.1';
const venv = path.join(backend, '.venv', process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python');
const python = env.PYTHON || (fs.existsSync(venv) ? venv : (process.platform === 'win32' ? 'python' : 'python3'));
const api = spawn(python, [path.join(backend, 'host_api.py')], {
  cwd: root, env, stdio: 'inherit', windowsHide: true,
});
api.on('error', () => {
  console.error('Could not start Lumear. Install Python and backend/requirements-hosting.txt.');
  process.exitCode = 1;
});
let stopping = false;
function stop(signal) {
  if (stopping) return;
  stopping = true;
  if (process.platform === 'win32' && api.pid) {
    // Stop only this launcher's Python process tree, including the venv child.
    spawnSync('taskkill', ['/PID', String(api.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' });
  } else {
    api.kill(signal);
  }
}
process.on('SIGINT', () => stop('SIGINT'));
process.on('SIGTERM', () => stop('SIGTERM'));
api.on('exit', (code) => { process.exitCode = stopping ? 0 : (code ?? 1); });
