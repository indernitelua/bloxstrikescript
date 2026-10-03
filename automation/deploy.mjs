import fs from 'node:fs/promises';
const mode = process.argv[2];
if (mode === 'core') {
  const token = process.env.LICENSE_ADMIN_TOKEN;
  if (!token) throw new Error('Missing LICENSE_ADMIN_TOKEN secret');
  const source = await fs.readFile('netanyahu.core.lua', 'utf8');
  if (!source.includes('MoonVeil') || Buffer.byteLength(source) > 1900000) throw new Error('Expected obfuscated core within service size limit');
  const response = await fetch('https://netanyahu-licenses.vladosikthebestkid.workers.dev/admin/core', {method: 'POST', headers: {Authorization: 'Bearer ' + token, 'Content-Type': 'application/json'}, body: JSON.stringify({source})});
  if (!response.ok) throw new Error('Core upload failed: HTTP ' + response.status);
  console.log('Obfuscated core uploaded to D1');
} else if (mode === 'worker') {
  const token = process.env.CLOUDFLARE_API_TOKEN;
  if (!token) throw new Error('Missing CLOUDFLARE_API_TOKEN secret');
  const headers = {Authorization: 'Bearer ' + token};
  async function api(route, init = {}) {
    const response = await fetch('https://api.cloudflare.com/client/v4' + route, {...init, headers});
    const data = await response.json();
    if (!response.ok || !data.success) throw new Error('Cloudflare request failed: HTTP ' + response.status);
    return data.result;
  }
  const accounts = await api('/accounts');
  const matches = [];
  for (const account of accounts) {
    const scripts = await api('/accounts/' + account.id + '/workers/scripts');
    if (scripts.some(script => script.id === 'netanyahu-configs')) matches.push(account.id);
  }
  if (matches.length !== 1) throw new Error('Token must access exactly one account containing netanyahu-configs');
  const route = '/accounts/' + matches[0] + '/workers/scripts/netanyahu-configs';
  const settings = await api(route + '/settings');
  if (!settings.bindings?.some(binding => binding.name === 'DB' && binding.type === 'd1')) throw new Error('Existing DB binding missing');
  const metadata = {main_module: 'worker.mjs', bindings: settings.bindings.filter(binding => !['secret_text', 'secret_key'].includes(binding.type)), keep_bindings: ['secret_text', 'secret_key'], compatibility_date: settings.compatibility_date, compatibility_flags: settings.compatibility_flags || []};
  if (settings.observability) metadata.observability = settings.observability;
  if (settings.limits) metadata.limits = settings.limits;
  const body = new FormData();
  body.append('metadata', new Blob([JSON.stringify(metadata)], {type: 'application/json'}));
  body.append('worker.mjs', new Blob([await fs.readFile('automation/community-worker.mjs')], {type: 'application/javascript+module'}), 'worker.mjs');
  await api(route, {method: 'PUT', body});
  console.log('Community Worker published with existing bindings');
} else throw new Error('Expected worker or core');
