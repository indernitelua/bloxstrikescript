import { DatabaseSync } from 'node:sqlite';
import assert from 'node:assert/strict';
import worker from './community-worker.mjs';

const sqlite = new DatabaseSync(':memory:');
const db = {
  prepare(sql) {
    let args = [];
    return {
      bind(...values) { args = values; return this; },
      async run() { const result = sqlite.prepare(sql).run(...args); return { meta: { changes: Number(result.changes) } }; },
      async all() { return { results: sqlite.prepare(sql).all(...args) }; },
      async first() { return sqlite.prepare(sql).get(...args) || null; }
    };
  },
  async batch(statements) { for (const statement of statements) await statement.run(); }
};
const owner = 'a'.repeat(64);
const code = 'ARVN1:' + Buffer.from(JSON.stringify({ rage: true, __version: '3.0' })).toString('base64');
async function call(path, method = 'GET', body, key = owner, ip = '127.0.0.1') {
  const request = new Request('https://test.local' + path, {
    method,
    headers: { 'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json', 'CF-Connecting-IP': ip },
    ...(body !== undefined ? { body: typeof body === 'string' ? body : JSON.stringify(body) } : {})
  });
  const response = await worker.fetch(request, { DB: db });
  return { status: response.status, data: response.status === 204 ? null : await response.json() };
}
assert.equal((await call('/configs')).data.items.length, 0);
const room = '114234929420007:11111111-1111-1111-1111-111111111111';
const presence = {room, userId: 123, enabled: true, effects: {color: [0.5, 0.2, 1], body_sparkles: true, body_effect_density: 999}};
assert.equal((await call('/effects', 'POST', presence, '')).status, 401);
assert.equal((await call('/effects', 'POST', {...presence, room: 'bad'})).status, 400);
assert.equal((await call('/effects', 'POST', presence)).status, 200);
assert.equal((await call('/effects', 'POST', presence)).status, 429);
const peerPresence = {...presence, userId: 456};
const peerResult = await call('/effects', 'POST', peerPresence, 'c'.repeat(64));
assert.equal(peerResult.data.players[0].userId, 123);
assert.equal(peerResult.data.players[0].effects.body_effect_density, 80);
assert.equal((await call('/effects', 'POST', {...presence, room: room.replace('11111111', '22222222')}, 'd'.repeat(64))).data.players.length, 0);
assert.equal((await call('/effects', 'POST', {...presence, enabled: false})).status, 200);
sqlite.prepare('UPDATE effect_presence SET updated_at = ?').run(Date.now() - 31000);
assert.equal((await call('/effects', 'POST', presence)).data.players.length, 0);
assert.equal((await call('/effects', 'POST', {...presence, enabled: false})).status, 200);
assert.equal((await call('/configs', 'POST', {})).status, 400);
assert.equal((await call('/configs', 'POST', '{')).status, 400);
assert.equal((await call('/configs', 'POST', { name: 'bad', author: 'vlad', code: 'loadstring()' })).status, 400);
assert.equal((await call('/configs', 'POST', { name: 'bad', author: 'vlad', code }, '')).status, 401);
const ids = [];
for (let i = 0; i < 5; i++) {
  const result = await call('/configs', 'POST', { name: 'test ' + i, author: 'vlad', code });
  assert.equal(result.status, 201);
  ids.push(result.data.id);
}
assert.equal((await call('/configs', 'POST', { name: 'sixth', author: 'vlad', code })).status, 429);
assert.equal((await call('/configs/' + ids[0])).data.code, code);
assert.equal((await call('/configs/' + ids[0], 'DELETE', undefined, 'b'.repeat(64))).status, 404);
const page = await call('/configs?limit=2');
assert.equal(page.data.items.length, 2);
assert.ok(page.data.next);
const page2 = await call('/configs?limit=2&before=' + encodeURIComponent(page.data.next));
assert.equal(page2.data.items.length, 2);
assert.equal(new Set([...page.data.items, ...page2.data.items].map(v => v.id)).size, 4);
assert.equal((await call('/configs?q=missing')).data.items.length, 0);
assert.equal((await call('/configs/' + ids[1] + '/vote', 'POST', { value: 1 })).status, 200);
assert.equal((await call('/configs/' + ids[1] + '/vote', 'POST', { value: 1 })).status, 200);
let ratings = (await call('/configs?sort=likes')).data.items;
assert.equal(ratings[0].id, ids[1]);
assert.equal(ratings[0].likes, 1);
assert.equal(ratings[0].my_vote, 1);
assert.equal((await call('/configs/' + ids[1] + '/vote', 'POST', { value: -1 })).status, 200);
ratings = (await call('/configs?sort=dislikes')).data.items;
assert.equal(ratings[0].id, ids[1]);
assert.equal(ratings[0].likes, 0);
assert.equal(ratings[0].dislikes, 1);
assert.equal((await call('/configs/' + ids[1] + '/vote', 'POST', { value: 0 })).status, 200);
assert.equal((await call('/configs?sort=likes')).data.items.find(v => v.id === ids[1]).dislikes, 0);
assert.equal((await call('/configs/' + ids[1] + '/vote', 'POST', { value: 9 })).status, 400);
assert.equal((await call('/configs/' + ids[1] + '/vote', 'POST', { value: '1' })).status, 400);
assert.equal((await call('/configs/' + ids[1] + '/vote', 'POST', { value: 1 }, '')).status, 401);
for (const key of [owner, owner, 'b'.repeat(64)]) assert.equal((await call('/configs/' + ids[2] + '/download', 'POST', undefined, key)).data.code, code);
const usage = (await call('/configs?sort=usage')).data.items;
assert.equal(usage[0].id, ids[2]);
assert.equal(usage[0].downloads, 2);
const usagePage = (await call('/configs?sort=usage&limit=2')).data;
const usagePage2 = (await call('/configs?sort=usage&limit=2&before=' + encodeURIComponent(usagePage.next))).data;
assert.equal(new Set([...usagePage.items, ...usagePage2.items].map(v => v.id)).size, 4);
assert.equal((await call('/configs?sort=likes&before=' + encodeURIComponent(usagePage.next))).status, 400);
assert.equal((await call('/configs?sort=invalid')).status, 400);
assert.equal((await call('/configs/' + ids[0], 'DELETE')).status, 200);
assert.equal((await call('/configs/' + ids[0])).status, 404);
assert.equal((await call('/configs/' + ids[0] + '/vote', 'POST', { value: 1 })).status, 404);
assert.equal((await call('/configs/' + ids[0] + '/download', 'POST')).status, 404);
assert.equal((await call('/configs', 'POST', { name: 'bypass', author: 'vlad', code })).status, 429);
assert.equal((await call('/configs', 'POST', 'x'.repeat(260001))).status, 413);
assert.equal((await call('/configs', 'OPTIONS')).status, 204);
console.log('Passed: publication, listing, pagination, ownership, quotas, validation, votes, vote changes/removal, unique downloads, all sort modes and sorted pagination.');

{
const room = '114234929420007:11111111-1111-1111-1111-111111111111';
const presence = {room, userId: 123, enabled: true, effects: {color: [0.5, 0.2, 1], weapon: {name: 'Karambit', skin: 'Stock', wear: 'Factory New'}}};
assert.equal((await call('/effects', 'POST', presence, 'd'.repeat(64))).status, 200);
const peers = await call('/effects', 'POST', {...presence, userId: 456}, 'e'.repeat(64));
assert.deepEqual(peers.data.players[0].effects.weapon, presence.effects.weapon);
assert.equal((await call('/effects', 'POST', {...presence, room: room.replace('11111111', '22222222')}, 'f'.repeat(64))).data.players.length, 0);
assert.equal((await call('/effects', 'POST', {...presence, effects: {...presence.effects, weapon: {name: 'Karambit', skin: 'Stock', wear: 'bad'}}}, '9'.repeat(64))).status, 400);
assert.equal((await call('/effects', 'POST', {...presence, enabled: false}, 'd'.repeat(64))).status, 200);
console.log('Passed: shared weapon roundtrip, room isolation, wear validation and presence removal.');

}
