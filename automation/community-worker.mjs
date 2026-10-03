const setups = new WeakMap();
const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store"
};

function reply(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers });
}

async function setup(db) {
  if (!setups.has(db)) {
    const promise = db.batch([
      db.prepare("CREATE TABLE IF NOT EXISTS configs (id TEXT PRIMARY KEY, name TEXT NOT NULL, author TEXT NOT NULL, description TEXT NOT NULL, code TEXT NOT NULL, owner_hash TEXT NOT NULL, ip_hash TEXT NOT NULL, created_at INTEGER NOT NULL, deleted INTEGER NOT NULL DEFAULT 0)"),
      db.prepare("CREATE INDEX IF NOT EXISTS configs_created ON configs(deleted, created_at DESC, id DESC)"),
      db.prepare("CREATE INDEX IF NOT EXISTS configs_owner ON configs(owner_hash, created_at)"),
      db.prepare("CREATE INDEX IF NOT EXISTS configs_ip ON configs(ip_hash, created_at)"),
      db.prepare("CREATE TABLE IF NOT EXISTS config_votes (config_id TEXT NOT NULL, voter_hash TEXT NOT NULL, value INTEGER NOT NULL CHECK(value IN (-1, 1)), PRIMARY KEY(config_id, voter_hash))"),
      db.prepare("CREATE INDEX IF NOT EXISTS config_votes_value ON config_votes(config_id, value)"),
      db.prepare("CREATE TABLE IF NOT EXISTS config_downloads (config_id TEXT NOT NULL, actor_hash TEXT NOT NULL, PRIMARY KEY(config_id, actor_hash))"),
      db.prepare("CREATE TABLE IF NOT EXISTS effect_presence (actor_hash TEXT PRIMARY KEY, room TEXT NOT NULL, user_id INTEGER NOT NULL, effects TEXT NOT NULL, updated_at INTEGER NOT NULL)"),
      db.prepare("CREATE INDEX IF NOT EXISTS effect_presence_room ON effect_presence(room, updated_at)")
    ]).catch(error => { setups.delete(db); throw error; });
    setups.set(db, promise);
  }
  await setups.get(db);
}

async function digest(value) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, "0")).join("");
}

function token(request) {
  const match = /^Bearer ([a-f0-9]{64})$/.exec(request.headers.get("Authorization") || "");
  return match?.[1];
}

function decodeUtf8(bytes) {
  const text = new TextDecoder("utf-8").decode(bytes);
  const encoded = new TextEncoder().encode(text);
  if (encoded.length !== bytes.length || encoded.some((value, index) => value !== bytes[index])) throw new Error("invalid_utf8");
  return text;
}

async function readBody(request) {
  if (!request.body) throw new Error("invalid_json");
  const reader = request.body.getReader();
  const chunks = [];
  let length = 0;
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    length += value.byteLength;
    if (length > 260000) { await reader.cancel(); throw new Error("too_large"); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  try { return JSON.parse(decodeUtf8(bytes)); }
  catch { throw new Error("invalid_json"); }
}

function validText(value, max, required = false) {
  return typeof value === "string" && value.length <= max && (!required || value.trim().length > 0) && !/[\u0000-\u001f\u007f]/.test(value);
}

function validCode(code) {
  if (typeof code !== "string" || code.length > 250000 || !/^ARVN1:[A-Za-z0-9+/]+={0,2}$/.test(code)) return false;
  try {
    const decoded = atob(code.slice(6));
    const bytes = Uint8Array.from(decoded, c => c.charCodeAt(0));
    const value = JSON.parse(decodeUtf8(bytes));
    return value !== null && typeof value === "object" && !Array.isArray(value);
  } catch { return false; }
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
    const url = new URL(request.url);
    if (url.pathname === "/" && request.method === "GET") return reply({ service: "netanyahu.cc configs", version: 4, storage: env.DB ? "bound" : "missing", routes: ["GET /configs", "GET /configs/:id", "POST /configs", "DELETE /configs/:id", "POST /configs/:id/vote", "POST /configs/:id/download", "POST /effects"] });
    if (!env.DB) return reply({ error: "missing_DB_binding" }, 503);
    try {
      await setup(env.DB);
      if (url.pathname === "/effects" && request.method === "POST") {
        const key = token(request);
        if (!key) return reply({error: "owner_token_required"}, 401);
        const body = await readBody(request);
        if (!body || !/^[0-9]+:[a-f0-9-]{36}$/.test(body.room || "") || !Number.isSafeInteger(body.userId) || body.userId < 1 || typeof body.enabled !== "boolean") return reply({error: "invalid_presence"}, 400);
        const actor = await digest(key);
        const now = Date.now();
        const old = await env.DB.prepare("SELECT updated_at FROM effect_presence WHERE actor_hash = ?").bind(actor).first();
        if (body.enabled && old && now - old.updated_at < 8000) return reply({error: "rate_limited"}, 429);
        await env.DB.prepare("DELETE FROM effect_presence WHERE updated_at < ?").bind(now - 30000).run();
        if (!body.enabled) {
          await env.DB.prepare("DELETE FROM effect_presence WHERE actor_hash = ?").bind(actor).run();
          return reply({players: []});
        }
        const input = body.effects;
        if (!input || typeof input !== "object" || Array.isArray(input)) return reply({error: "invalid_effects"}, 400);
        const effects = {};
        for (const name of ["body_sparkles", "body_glow", "body_aura", "body_trail", "body_rainbow"]) effects[name] = input[name] === true;
        for (const [name, min, max, fallback] of [["body_effect_density",1,80,25],["body_sparkle_size",0.05,0.8,0.2],["body_glow_brightness",0.1,3,1],["body_trail_lifetime",0.1,2,0.5],["body_rainbow_speed",1,100,15]]) effects[name] = Number.isFinite(input[name]) ? Math.max(min, Math.min(max, input[name])) : fallback;
        if (!Array.isArray(input.color) || input.color.length !== 3 || !input.color.every(x => Number.isFinite(x) && x >= 0 && x <= 1)) return reply({error: "invalid_color"}, 400);
        effects.color = input.color;
        if (input.weapon != null) {
          const weapon = input.weapon;
          const wears = ["Factory New", "Minimal Wear", "Field-Tested", "Well-Worn", "Battle-Scarred"];
          if (!weapon || !validText(weapon.name, 80, true) || !validText(weapon.skin, 120, true) || !wears.includes(weapon.wear)) return reply({error: "invalid_weapon"}, 400);
          effects.weapon = {name: weapon.name, skin: weapon.skin, wear: weapon.wear};
        }
        const count = await env.DB.prepare("SELECT COUNT(*) AS count FROM effect_presence WHERE room = ? AND actor_hash != ?").bind(body.room, actor).first();
        if (count.count >= 64) return reply({error: "room_full"}, 429);
        await env.DB.prepare("INSERT INTO effect_presence(actor_hash, room, user_id, effects, updated_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(actor_hash) DO UPDATE SET room=excluded.room,user_id=excluded.user_id,effects=excluded.effects,updated_at=excluded.updated_at").bind(actor, body.room, body.userId, JSON.stringify(effects), now).run();
        const rows = await env.DB.prepare("SELECT user_id, effects FROM effect_presence WHERE room = ? AND actor_hash != ? AND updated_at >= ? ORDER BY updated_at DESC LIMIT 64").bind(body.room, actor, now - 30000).all();
        return reply({players: rows.results.map(row => ({userId: row.user_id, effects: JSON.parse(row.effects)})), ttl: 30});
      }
      if (url.pathname === "/configs" && request.method === "GET") {
        const rawLimit = Number(url.searchParams.get("limit") || 20);
        const limit = Number.isFinite(rawLimit) ? Math.max(1, Math.min(50, Math.floor(rawLimit))) : 20;
        const query = (url.searchParams.get("q") || "").trim();
        if (query.length > 80) return reply({ error: "query_too_long" }, 400);
        const sort = url.searchParams.get("sort") || "newest";
        const column = { newest: "created_at", usage: "downloads", likes: "likes", dislikes: "dislikes" }[sort];
        if (!column) return reply({ error: "invalid_sort" }, 400);
        const before = url.searchParams.get("before") || "";
        let score = Number.MAX_SAFE_INTEGER, stamp = Number.MAX_SAFE_INTEGER, id = "";
        if (before) {
          const match = /^(newest|usage|likes|dislikes):(\d{1,16}):(\d{10,16}):([a-f0-9-]{36})$/.exec(before);
          if (!match || match[1] !== sort || !Number.isSafeInteger(Number(match[2])) || !Number.isSafeInteger(Number(match[3]))) return reply({ error: "invalid_cursor" }, 400);
          score = Number(match[2]); stamp = Number(match[3]); id = match[4];
        }
        const key = token(request);
        const actor = key ? await digest(key) : "";
        const result = await env.DB.prepare(`WITH ranked AS (SELECT c.id, c.name, c.author, c.description, c.created_at, (SELECT count(*) FROM config_votes WHERE config_id = c.id AND value = 1) AS likes, (SELECT count(*) FROM config_votes WHERE config_id = c.id AND value = -1) AS dislikes, (SELECT count(*) FROM config_downloads WHERE config_id = c.id) AS downloads, coalesce((SELECT value FROM config_votes WHERE config_id = c.id AND voter_hash = ?), 0) AS my_vote FROM configs c WHERE c.deleted = 0 AND (? = '' OR instr(lower(c.name), lower(?)) > 0 OR instr(lower(c.author), lower(?)) > 0)) SELECT * FROM ranked WHERE ${column} < ? OR (${column} = ? AND (created_at < ? OR (created_at = ? AND id < ?))) ORDER BY ${column} DESC, created_at DESC, id DESC LIMIT ?`)
          .bind(actor, query, query, query, score, score, stamp, stamp, id, limit + 1).all();
        const rows = result.results || [];
        const more = rows.length > limit;
        const items = rows.slice(0, limit);
        const last = items.at(-1);
        return reply({ version: 2, sort, items, next: more && last ? `${sort}:${last[column]}:${last.created_at}:${last.id}` : null });
      }
      if (url.pathname === "/configs" && request.method === "POST") {
        const key = token(request);
        if (!key) return reply({ error: "owner_token_required" }, 401);
        const body = await readBody(request);
        if (!body || !validText(body.name, 48, true) || !validText(body.author, 48, true) || !validText(body.description ?? "", 240) || !validCode(body.code)) return reply({ error: "invalid_config" }, 400);
        const owner = await digest(key);
        const ip = request.headers.get("CF-Connecting-IP");
        if (!ip) return reply({ error: "client_address_unavailable" }, 503);
        const ipHash = await digest(ip);
        const now = Date.now();
        const since = now - 86400000;
        const id = crypto.randomUUID();
        const result = await env.DB.prepare("INSERT INTO configs (id, name, author, description, code, owner_hash, ip_hash, created_at) SELECT ?, ?, ?, ?, ?, ?, ?, ? WHERE (SELECT count(*) FROM configs WHERE owner_hash = ? AND created_at >= ?) < 5 AND (SELECT count(*) FROM configs WHERE ip_hash = ? AND created_at >= ?) < 5 AND (SELECT count(*) FROM configs WHERE deleted = 0) < 2000")
          .bind(id, body.name.trim(), body.author.trim(), (body.description || "").trim(), body.code, owner, ipHash, now, owner, since, ipHash, since).run();
        if (!result.meta?.changes) return reply({ error: "upload_limit_or_catalog_full" }, 429);
        return reply({ id, name: body.name.trim(), created_at: now }, 201);
      }
      const action = /^\/configs\/([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})\/(vote|download)$/.exec(url.pathname);
      if (action && request.method === "POST") {
        const key = token(request);
        if (!key) return reply({ error: "owner_token_required" }, 401);
        const actor = await digest(key);
        const row = await env.DB.prepare("SELECT id, name, author, description, code, created_at FROM configs WHERE id = ? AND deleted = 0").bind(action[1]).first();
        if (!row) return reply({ error: "not_found" }, 404);
        if (action[2] === "download") {
          await env.DB.prepare("INSERT OR IGNORE INTO config_downloads (config_id, actor_hash) SELECT id, ? FROM configs WHERE id = ? AND deleted = 0").bind(actor, action[1]).run();
          return reply(row);
        }
        const body = await readBody(request);
        if (!body || ![1, -1, 0].includes(body.value)) return reply({ error: "invalid_vote" }, 400);
        if (body.value === 0) await env.DB.prepare("DELETE FROM config_votes WHERE config_id = ? AND voter_hash = ?").bind(action[1], actor).run();
        else await env.DB.prepare("INSERT INTO config_votes (config_id, voter_hash, value) SELECT id, ?, ? FROM configs WHERE id = ? AND deleted = 0 ON CONFLICT(config_id, voter_hash) DO UPDATE SET value = excluded.value").bind(actor, body.value, action[1]).run();
        return reply({ voted: body.value });
      }
      const match = /^\/configs\/([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$/.exec(url.pathname);
      if (match && request.method === "GET") {
        const row = await env.DB.prepare("SELECT id, name, author, description, code, created_at FROM configs WHERE id = ? AND deleted = 0").bind(match[1]).first();
        return row ? reply(row) : reply({ error: "not_found" }, 404);
      }
      if (match && request.method === "DELETE") {
        const key = token(request);
        if (!key) return reply({ error: "owner_token_required" }, 401);
        const result = await env.DB.prepare("UPDATE configs SET deleted = 1, code = '' WHERE id = ? AND owner_hash = ? AND deleted = 0").bind(match[1], await digest(key)).run();
        return result.meta?.changes ? reply({ deleted: true }) : reply({ error: "not_found" }, 404);
      }
      return reply({ error: "not_found" }, 404);
    } catch (error) {
      if (error.message === "too_large") return reply({ error: "too_large" }, 413);
      if (error.message === "invalid_json") return reply({ error: "invalid_json" }, 400);
      console.error("config service failure", error);
      return reply({ error: "storage_error" }, 500);
    }
  }
};
