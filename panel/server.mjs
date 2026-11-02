// Astral Panel — serveur local (Node ≥ 20, une seule dépendance : mysql2).
// Écoute UNIQUEMENT sur 127.0.0.1. La clé API YorkHost (variable d'environnement GMOD_PANEL_KEY)
// et le mot de passe MySQL restent dans ce processus : le navigateur ne les voit jamais.
// Chaque requête /api doit porter le jeton de session (X-Astral-Token) injecté dans la page au démarrage,
// ce qui empêche un autre site ouvert dans le navigateur d'utiliser le panel à ta place.

import http from 'node:http';
import dgram from 'node:dgram';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import { readFile, readdir, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import mysql from 'mysql2/promise';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PROJECT = path.resolve(HERE, '..');
const PORT = Number(process.env.ASTRAL_PANEL_PORT || 8420);
const PANEL_URL = 'https://panel.yorkhost.fr';
const SERVER_ID = '434e787a';
const API = `${PANEL_URL}/api/client/servers/${SERVER_ID}`;
const KEY = process.env.GMOD_PANEL_KEY;
if (!KEY) { console.error("Variable d'environnement GMOD_PANEL_KEY absente."); process.exit(1); }
const TOKEN = crypto.randomBytes(24).toString('hex');

// ---------------------------------------------------------------------------
// API YorkHost (Pterodactyl)
// ---------------------------------------------------------------------------
async function ptero(pathname, { method = 'GET', body, raw = false, text = false, buffer = false } = {}) {
	const res = await fetch(API + pathname, {
		method,
		headers: {
			Authorization: `Bearer ${KEY}`,
			Accept: 'application/json',
			...(body !== undefined ? { 'Content-Type': raw ? 'text/plain; charset=utf-8' : 'application/json' } : {}),
		},
		body: body === undefined ? undefined : (raw ? body : JSON.stringify(body)),
	});
	if (!res.ok) throw new Error(`YorkHost ${res.status} sur ${pathname} : ${(await res.text()).slice(0, 200)}`);
	if (res.status === 204) return null;
	if (buffer) return Buffer.from(await res.arrayBuffer());
	return text ? res.text() : res.json();
}

// ---------------------------------------------------------------------------
// Suppression d'une ligne fautive (onglet Sécurité). Le fichier est lu et réécrit octet pour octet (latin1),
// une copie d'origine est gardée dans data/astral/failles_sauvegardes/, et la syntaxe est vérifiée par le serveur
// de jeu : si la ligne retirée casse le fichier, l'original est remis aussitôt.
// ---------------------------------------------------------------------------
const FIX_LOG = '/garrysmod/data/astral/failles_corrections.json';
const FIX_DIR = '/garrysmod/data/astral/failles_sauvegardes';
const readRemote = async (p) => (await ptero('/files/contents?file=' + encodeURIComponent(p), { buffer: true })).toString('latin1');
const writeRemote = (p, s) => ptero('/files/write?file=' + encodeURIComponent(p), { method: 'POST', body: Buffer.from(s, 'latin1'), raw: true });
// Journal des corrections : JSON en UTF-8 (≠ fichiers Lua, manipulés en latin1)
const readFixes = async () => { try { return JSON.parse((await ptero('/files/contents?file=' + encodeURIComponent(FIX_LOG), { buffer: true })).toString('utf8')); } catch { return []; } };
const writeFixes = (list) => ptero('/files/write?file=' + encodeURIComponent(FIX_LOG), { method: 'POST', body: Buffer.from(JSON.stringify(list, null, 1), 'utf8'), raw: true });
// Même normalisation que l'extrait produit par sv_security.lua (caractères de contrôle → espace, 200 premiers, ASCII seul pour comparer)
const sameLine = (line, excerpt) => {
	const norm = (s) => s.replace(/[\x00-\x1f\x7f]/g, ' ').trim().slice(0, 200).replace(/[^\x20-\x7e]/g, '');
	const a = norm(line), b = norm(excerpt);
	return a.length > 0 && b.length > 0 && (a.startsWith(b) || b.startsWith(a));
};
function checkPath(p) {
	if (typeof p !== 'string' || !/^(addons|lua|gamemodes)\/[\w\-./ !]+\.lua$/.test(p) || p.includes('..')) throw new Error('Seules les lignes des fichiers .lua de addons/, lua/ ou gamemodes/ peuvent être supprimées.');
	return '/garrysmod/' + p;
}
async function syntaxCheck(p) {
	const id = crypto.randomBytes(4).toString('hex');
	const start = consoleLines.length;
	wsSend('send command', [`astral_securite_syntaxe ${id} "${p}"`]);
	for (let i = 0; i < 25; i++) {
		await new Promise((r) => setTimeout(r, 200));
		const hit = consoleLines.slice(Math.max(0, start - 5)).find((l) => l.includes(`[Astral Syntaxe] ${id} `));
		if (hit) { const m = hit.split(`[Astral Syntaxe] ${id} `)[1]; return { state: m.split(' ')[0], msg: m.slice(m.indexOf(' ') + 1).trim() }; }
	}
	return { state: 'SANS_REPONSE', msg: 'le serveur de jeu n\'a pas répondu' };
}

// ---------------------------------------------------------------------------
// Console en direct : une seule connexion WebSocket vers YorkHost, relayée en SSE aux onglets ouverts
// ---------------------------------------------------------------------------
const consoleLines = [];
const sseClients = new Set();
let consoleState = 'déconnectée';
let serverState = 'inconnu';
let latestStats = null;
let ws = null;

function pushLine(line) {
	consoleLines.push(line);
	if (consoleLines.length > 500) consoleLines.shift();
	broadcast('line', line);
}
function broadcast(event, data) {
	const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
	for (const res of sseClients) res.write(payload);
}

async function connectConsole() {
	try {
		const { data } = await ptero('/websocket');
		ws = new WebSocket(data.socket, { headers: { Origin: PANEL_URL } });
		ws.onopen = () => ws.send(JSON.stringify({ event: 'auth', args: [data.token] }));
		ws.onmessage = async (msg) => {
			const m = JSON.parse(msg.data);
			switch (m.event) {
				case 'auth success':
					consoleState = 'connectée'; broadcast('console', consoleState);
					ws.send(JSON.stringify({ event: 'send logs', args: [null] }));
					break;
				case 'console output': pushLine(String(m.args[0]).replace(/\x1b\[[0-9;]*m/g, '')); break;
				case 'status': serverState = m.args[0]; broadcast('status', serverState); break;
				case 'stats': latestStats = JSON.parse(m.args[0]); broadcast('stats', latestStats); break;
				case 'token expiring': {
					const t = await ptero('/websocket');
					ws.send(JSON.stringify({ event: 'auth', args: [t.data.token] }));
					break;
				}
			}
		};
		ws.onclose = () => { consoleState = 'reconnexion…'; broadcast('console', consoleState); setTimeout(connectConsole, 5000); };
		ws.onerror = () => {};
	} catch (e) {
		consoleState = 'erreur : ' + e.message; broadcast('console', consoleState);
		setTimeout(connectConsole, 10000);
	}
}

function wsSend(event, args) {
	if (!ws || ws.readyState !== 1) throw new Error('Console non connectée');
	ws.send(JSON.stringify({ event, args }));
}

// ---------------------------------------------------------------------------
// Requêtes Source (A2S) : nom, map, joueurs en ligne
// ---------------------------------------------------------------------------
let gameAddr = null;
function a2s(type) {
	return new Promise((resolve, reject) => {
		const sock = dgram.createSocket('udp4');
		const timer = setTimeout(() => { sock.close(); reject(new Error('A2S : pas de réponse')); }, 3000);
		const header = Buffer.from([0xff, 0xff, 0xff, 0xff]);
		const send = (challenge) => {
			let pkt;
			if (type === 'info') pkt = Buffer.concat([header, Buffer.from('TSource Engine Query\0', 'latin1'), challenge || Buffer.alloc(0)]);
			else pkt = Buffer.concat([header, Buffer.from([0x55]), challenge || Buffer.from([0xff, 0xff, 0xff, 0xff])]);
			sock.send(pkt, gameAddr.port, gameAddr.ip);
		};
		sock.on('message', (buf) => {
			const kind = buf[4];
			if (kind === 0x41) return send(buf.subarray(5, 9));
			clearTimeout(timer); sock.close();
			try { resolve(type === 'info' ? parseInfo(buf) : parsePlayers(buf)); } catch (e) { reject(e); }
		});
		send();
	});
}
function readString(buf, o) { const end = buf.indexOf(0, o); return [buf.toString('utf8', o, end), end + 1]; }
function parseInfo(buf) {
	let o = 6, name, map, folder, game;
	[name, o] = readString(buf, o); [map, o] = readString(buf, o); [folder, o] = readString(buf, o); [game, o] = readString(buf, o);
	o += 2;
	return { name, map, game, players: buf[o], maxPlayers: buf[o + 1], bots: buf[o + 2], vac: buf[o + 6] === 1 };
}
function parsePlayers(buf) {
	const count = buf[5]; let o = 6; const list = [];
	for (let i = 0; i < count && o < buf.length; i++) {
		o += 1; let name; [name, o] = readString(buf, o);
		const score = buf.readInt32LE(o); const duration = buf.readFloatLE(o + 4); o += 8;
		list.push({ name, score, duration: Math.round(duration) });
	}
	return list;
}

// ---------------------------------------------------------------------------
// Base Astral (lecture seule) : identifiants récupérés via l'API au démarrage, jamais écrits sur disque
// ---------------------------------------------------------------------------
let pool = null;
async function db() {
	if (pool) return pool;
	const { data } = await ptero('/databases?include=password');
	const a = data[0].attributes;
	pool = mysql.createPool({
		host: a.host.address, port: a.host.port, user: a.username,
		password: a.relationships.password.attributes.password, database: a.name,
		connectionLimit: 3, charset: 'utf8mb4',
	});
	return pool;
}
async function q(sql, params = []) { const [rows] = await (await db()).query(sql, params); return rows; }

// Noms connus : profils astral_players (migration 4), complétés par les connexions journalisées
async function names() {
	const [rows, profiles] = await Promise.all([
		q("SELECT sid64, data FROM astral_logs WHERE category = 'join' ORDER BY id DESC LIMIT 2000"),
		q('SELECT sid64, name FROM astral_players').catch(() => []),
	]);
	const map = {};
	for (const p of profiles) if (p.name) map[p.sid64] = p.name;
	for (const r of rows) if (r.sid64 && !map[r.sid64]) { try { map[r.sid64] = JSON.parse(r.data).name; } catch {} }
	return map;
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------
const routes = {
	'GET /api/overview': async () => {
		const [details, resources, startup] = await Promise.all([ptero(''), ptero('/resources'), ptero('/startup')]);
		const a = details.attributes;
		const alloc = a.relationships.allocations.data.find((x) => x.attributes.is_default)?.attributes;
		if (alloc) gameAddr = { ip: alloc.ip_alias && /^\d/.test(alloc.ip_alias) ? alloc.ip_alias : alloc.ip, port: alloc.port };
		let info = null; try { info = await a2s('info'); } catch {}
		return {
			name: a.name, node: a.node, limits: a.limits, address: alloc ? `${alloc.ip}:${alloc.port}` : null,
			state: resources.attributes.current_state, resources: resources.attributes.resources,
			startup: startup.data.map((v) => ({ key: v.attributes.env_variable, name: v.attributes.name, value: v.attributes.server_value, editable: v.attributes.is_editable, description: v.attributes.description })),
			info, console: consoleState,
		};
	},
	'GET /api/players': async () => {
		if (!gameAddr) await routes['GET /api/overview']();
		return a2s('players');
	},
	'POST /api/power': async (body) => {
		if (!['start', 'stop', 'restart', 'kill'].includes(body.signal)) throw new Error('Signal invalide');
		await ptero('/power', { method: 'POST', body: { signal: body.signal } });
		return { ok: true };
	},
	'POST /api/command': async (body) => {
		const cmd = String(body.command || '').trim();
		if (!cmd || cmd.length > 255) throw new Error('Commande vide ou trop longue (255 caractères max).');
		wsSend('send command', [cmd]);
		return { ok: true };
	},
	'GET /api/files': async (_, url) => {
		const dir = url.searchParams.get('dir') || '/';
		const res = await ptero('/files/list?directory=' + encodeURIComponent(dir));
		return res.data.map((f) => ({ name: f.attributes.name, file: f.attributes.is_file, size: f.attributes.size, modified: f.attributes.modified_at }))
			.sort((x, y) => (x.file - y.file) || x.name.localeCompare(y.name));
	},
	'GET /api/file': async (_, url) => {
		const p = url.searchParams.get('path');
		return { path: p, content: await ptero('/files/contents?file=' + encodeURIComponent(p), { text: true }) };
	},
	'POST /api/file': async (body) => {
		if (!body.path || typeof body.content !== 'string') throw new Error('Chemin ou contenu manquant');
		await ptero('/files/write?file=' + encodeURIComponent(body.path), { method: 'POST', body: body.content.replace(/\r\n/g, '\n'), raw: true });
		return { ok: true };
	},
	'POST /api/startup': async (body) => {
		const res = await ptero('/startup/variable', { method: 'PUT', body: { key: body.key, value: String(body.value) } });
		return { value: res.attributes.server_value };
	},
	'GET /api/backups': async () => {
		const dir = path.join(PROJECT, 'backups');
		const files = (await readdir(dir).catch(() => [])).filter((f) => f.endsWith('.tar.gz'));
		const list = await Promise.all(files.map(async (f) => ({ name: f, size: (await stat(path.join(dir, f))).size })));
		return list.sort((a, b) => b.name.localeCompare(a.name));
	},
	'POST /api/backups': async () => new Promise((resolve) => {
		const ps = spawn('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(PROJECT, 'tools', 'backup.ps1')], { env: process.env });
		let out = '';
		ps.stdout.on('data', (d) => { out += d; }); ps.stderr.on('data', (d) => { out += d; });
		ps.on('close', (code) => resolve({ ok: code === 0, output: out.trim() }));
	}),
	'GET /api/astral/summary': async () => {
		const since = Math.floor(Date.now() / 1000) - 86400;
		const [nm, players, richest, money, alerts, counts] = await Promise.all([
			names(),
			q('SELECT COUNT(*) AS n FROM basewars'),
			q('SELECT sid64, money, level FROM basewars ORDER BY money DESC LIMIT 10'),
			q("SELECT data FROM astral_logs WHERE category = 'money' AND ts >= ? LIMIT 50000", [since]),
			q("SELECT ts, sid64, data FROM astral_logs WHERE category = 'economy_alert' ORDER BY id DESC LIMIT 20"),
			q('SELECT category, COUNT(*) AS n FROM astral_logs WHERE ts >= ? GROUP BY category ORDER BY n DESC', [since]),
		]);
		const sources = {};
		let created = 0, destroyed = 0;
		for (const r of money) {
			let d; try { d = JSON.parse(r.data); } catch { continue; }
			const s = (sources[d.source] ??= { gain: 0, loss: 0, count: 0 });
			if (d.delta > 0) { s.gain += d.delta; created += d.delta; } else { s.loss -= d.delta; destroyed -= d.delta; }
			s.count++;
		}
		return {
			totalPlayers: players[0].n,
			richest: richest.map((r) => ({ name: nm[r.sid64] || r.sid64, sid64: r.sid64, money: Number(r.money), level: r.level })),
			sources: Object.entries(sources).map(([source, v]) => ({ source, ...v })).sort((a, b) => b.gain - a.gain),
			created, destroyed,
			alerts: alerts.map((a) => ({ ts: a.ts, name: nm[a.sid64] || a.sid64, data: a.data })),
			activity: counts,
		};
	},
	'GET /api/astral/logs': async (_, url) => {
		const cat = url.searchParams.get('category');
		const search = url.searchParams.get('q');
		const where = []; const params = [];
		if (cat) { where.push('category = ?'); params.push(cat); }
		if (search) { where.push('(data LIKE ? OR sid64 = ?)'); params.push(`%${search}%`, search); }
		const rows = await q(`SELECT id, ts, category, sid64, data FROM astral_logs ${where.length ? 'WHERE ' + where.join(' AND ') : ''} ORDER BY id DESC LIMIT 300`, params);
		const nm = await names();
		return rows.map((r) => ({ ...r, name: r.sid64 ? (nm[r.sid64] || r.sid64) : null }));
	},
	// Communauté : classements (mêmes requêtes que sv_stats.lua), factions actives, recherche, quêtes
	'GET /api/astral/community': async () => {
		const REAL = "LIKE '7656119%'";   // vrais comptes Steam uniquement (pas de bots de test)
		const week = Math.floor(Date.now() / 1000) - 7 * 86400;
		const [nm, money, level, time, industry, produced, factions, members, research, quests, profiles] = await Promise.all([
			names(),
			q(`SELECT sid64, money AS v FROM basewars WHERE sid64 ${REAL} ORDER BY money DESC LIMIT 10`),
			q(`SELECT sid64, level AS v, xp AS v2 FROM basewars WHERE sid64 ${REAL} ORDER BY level DESC, xp DESC LIMIT 10`),
			q(`SELECT sid64, \`time\` AS v FROM basewars WHERE sid64 ${REAL} ORDER BY \`time\` DESC LIMIT 10`),
			q(`SELECT sid64, industry_earned AS v FROM astral_players WHERE sid64 ${REAL} AND industry_earned > 0 ORDER BY industry_earned DESC LIMIT 10`).catch(() => []),
			q(`SELECT sid64, produced AS v FROM astral_players WHERE sid64 ${REAL} AND produced > 0 ORDER BY produced DESC LIMIT 10`).catch(() => []),
			q('SELECT name, leader, color_r, color_g, color_b, pass_hash IS NOT NULL AS locked, created_at FROM astral_factions WHERE disbanded_at IS NULL ORDER BY created_at').catch(() => []),
			q('SELECT faction, COUNT(*) AS n FROM astral_faction_members WHERE faction IS NOT NULL GROUP BY faction').catch(() => []),
			q('SELECT tech_id, COUNT(*) AS n FROM astral_research GROUP BY tech_id ORDER BY n DESC').catch(() => []),
			q('SELECT quest_id, SUM(claimed) AS claimed, COUNT(*) AS started FROM astral_quests GROUP BY quest_id ORDER BY claimed DESC').catch(() => []),
			q('SELECT COUNT(*) AS n, SUM(last_seen >= ?) AS week FROM astral_players WHERE sid64 ' + REAL, [week]).catch(() => [{ n: 0, week: 0 }]),
		]);
		const board = (rows) => rows.map((r) => ({ sid64: r.sid64, name: nm[r.sid64] || 'Joueur hors ligne', v: Number(r.v), v2: Number(r.v2 || 0) }));
		const count = Object.fromEntries(members.map((m) => [m.faction, Number(m.n)]));
		// Le chef est stocké au format SteamID (STEAM_0:X:Y) par SpaceVX : conversion en SteamID64 pour retrouver son nom
		const toSid64 = (s) => { const m = /^STEAM_\d:(\d):(\d+)$/.exec(s || ''); return m ? (76561197960265728n + BigInt(m[2]) * 2n + BigInt(m[1])).toString() : null; };
		return {
			boards: { money: board(money), level: board(level), time: board(time), industry: board(industry), produced: board(produced) },
			factions: factions.map((f) => {
				const sid = toSid64(f.leader);
				return { name: f.name, leader: (sid && nm[sid]) || f.leader, color: `rgb(${f.color_r},${f.color_g},${f.color_b})`, locked: !!f.locked, members: count[f.name] || 0, created: f.created_at };
			}),
			research: research.map((r) => ({ id: r.tech_id, n: Number(r.n) })),
			quests: quests.map((r) => ({ id: r.quest_id, claimed: Number(r.claimed || 0), started: Number(r.started) })),
			profiles: { total: Number(profiles[0]?.n || 0), week: Number(profiles[0]?.week || 0) },
		};
	},
	// Marché entre joueurs : offres ouvertes (astral_market) et ventes récentes (journal market_buy), lecture seule
	'GET /api/astral/market': async () => {
		const since = Math.floor(Date.now() / 1000) - 7 * 86400;
		const [nm, open, sales, totals, settings] = await Promise.all([
			names(),
			q('SELECT id, seller, seller_name, resource, qty_total, qty_left, unit_price, created_at FROM astral_market WHERE status = 0 ORDER BY resource, unit_price LIMIT 300').catch(() => []),
			q("SELECT ts, sid64, data FROM astral_logs WHERE category = 'market_buy' ORDER BY id DESC LIMIT 100"),
			q("SELECT data FROM astral_logs WHERE category = 'market_buy' AND ts >= ? LIMIT 20000", [since]),
			q("SELECT path, value FROM astral_settings WHERE path LIKE 'Market.%'").catch(() => []),
		]);
		let volume = 0, tax = 0, count = 0;
		for (const r of totals) { try { const d = JSON.parse(r.data); volume += d.cost || 0; tax += d.tax || 0; count++; } catch {} }
		return {
			open: open.map((o) => ({ ...o, unit_price: Number(o.unit_price), sellerName: nm[o.seller] || o.seller_name })),
			sales: sales.map((s) => { let d = {}; try { d = JSON.parse(s.data); } catch {} return { ts: s.ts, buyer: nm[s.sid64] || s.sid64, seller: nm[d.seller] || d.seller, resource: d.resource, qty: d.qty, cost: d.cost, tax: d.tax }; }),
			week: { count, volume, tax },
			settings: Object.fromEntries(settings.map((s) => [s.path, s.value])),
		};
	},
	// Sécurité : rapport d'analyse des fichiers (écrit par sv_security.lua) et blocages en direct d'Astral Shield
	'GET /api/security': async () => {
		const now = Math.floor(Date.now() / 1000);
		const [report, blocks, counts] = await Promise.all([
			ptero('/files/contents?file=' + encodeURIComponent('/garrysmod/data/astral/securite_analyse.json'), { text: true }).then((t) => JSON.parse(t)).catch(() => null),
			q("SELECT id, ts, data FROM astral_logs WHERE category = 'security' ORDER BY id DESC LIMIT 200"),
			q("SELECT SUM(ts >= ?) AS day, SUM(ts >= ?) AS week, COUNT(*) AS total FROM astral_logs WHERE category = 'security'", [now - 86400, now - 7 * 86400]),
		]);
		return {
			report,
			fixes: await readFixes(),
			blocks: blocks.map((b) => { let d = {}; try { d = JSON.parse(b.data); } catch {} return { id: b.id, ts: b.ts, ...d }; }),
			counts: { day: Number(counts[0]?.day || 0), week: Number(counts[0]?.week || 0), total: Number(counts[0]?.total || 0) },
			serverState,
		};
	},
	'POST /api/security/scan': async () => {
		wsSend('send command', ['astral_securite_analyse']);
		return { ok: true };
	},
	// Supprime UNE ligne : elle est remplacée par un commentaire, ce qui garde les numéros de ligne intacts
	'POST /api/security/fix': async (body) => {
		const full = checkPath(body.path);
		const n = Number(body.line);
		const original = await readRemote(full);
		const eol = original.includes('\r\n') ? '\r\n' : '\n';
		const lines = original.split(eol);
		if (!Number.isInteger(n) || n < 1 || n > lines.length) throw new Error('Ligne introuvable dans le fichier.');
		if (!sameLine(lines[n - 1], String(body.excerpt || ''))) throw new Error('Le fichier a changé depuis l\'analyse : relance une analyse avant de supprimer.');
		const removed = lines[n - 1];
		const indent = removed.match(/^\s*/)[0];
		// Le fichier est manipulé en latin1 (octet pour octet) : le commentaire ajouté est converti depuis l'UTF-8
		const note = `-- [Astral Shield] ligne supprimée depuis le panel le ${new Date().toLocaleString('fr-FR')} (${String(body.kind || 'faille').replace(/[\r\n]/g, ' ').slice(0, 80)})`;
		lines[n - 1] = indent + Buffer.from(note, 'utf8').toString('latin1');
		const ts = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
		const backup = `${FIX_DIR}/${ts}_${body.path.replace(/[^\w.-]+/g, '_')}.txt`;
		await writeRemote(backup, original);
		await writeRemote(full, lines.join(eol));
		const check = await syntaxCheck(body.path);
		if (check.state === 'ERREUR') {
			await writeRemote(full, original);
			throw new Error(`Supprimer cette ligne casserait le fichier (${check.msg}). Le fichier a été remis à l'identique : la faille s'étend sur plusieurs lignes, retire l'addon ou corrige-le à la main.`);
		}
		const fixes = await readFixes();
		const fix = { id: ts + '_' + crypto.randomBytes(2).toString('hex'), ts: Math.floor(Date.now() / 1000), path: body.path, line: n, kind: body.kind, addon: body.addon, removed: Buffer.from(removed.slice(0, 300), 'latin1').toString('utf8'), backup, syntax: check.state, restored: false };
		fixes.unshift(fix);
		await writeFixes(fixes.slice(0, 200));
		return fix;
	},
	'POST /api/security/restore': async (body) => {
		const fixes = await readFixes();
		const fix = fixes.find((f) => f.id === body.id);
		if (!fix || fix.restored) throw new Error('Correction introuvable ou déjà annulée.');
		await writeRemote(checkPath(fix.path), await readRemote(fix.backup));
		fix.restored = Math.floor(Date.now() / 1000);
		await writeFixes(fixes);
		return { ok: true };
	},
	'GET /api/astral/player': async (_, url) => {
		const sid = url.searchParams.get('sid64');
		if (!/^\d{17}$/.test(sid || '')) throw new Error('SteamID64 invalide');
		const [row, logs] = await Promise.all([
			q('SELECT money, karma, time, xp, level FROM basewars WHERE sid64 = ?', [sid]),
			q('SELECT ts, category, data FROM astral_logs WHERE sid64 = ? ORDER BY id DESC LIMIT 200', [sid]),
		]);
		return { sid64: sid, profile: row[0] || null, logs, name: (await names())[sid] || sid };
	},
};

// ---------------------------------------------------------------------------
// Serveur HTTP
// ---------------------------------------------------------------------------
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png' };

const server = http.createServer(async (req, res) => {
	const url = new URL(req.url, `http://${req.headers.host}`);
	try {
		if (url.pathname.startsWith('/api/')) {
			const token = req.headers['x-astral-token'] || url.searchParams.get('token');
			if (token !== TOKEN) { res.writeHead(403); return res.end('Jeton invalide'); }
			if (url.pathname === '/api/console/stream') {
				res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
				res.write(`event: history\ndata: ${JSON.stringify(consoleLines)}\n\n`);
				res.write(`event: status\ndata: ${JSON.stringify(serverState)}\n\n`);
				res.write(`event: console\ndata: ${JSON.stringify(consoleState)}\n\n`);
				if (latestStats) res.write(`event: stats\ndata: ${JSON.stringify(latestStats)}\n\n`);
				sseClients.add(res);
				req.on('close', () => sseClients.delete(res));
				return;
			}
			const handler = routes[`${req.method} ${url.pathname}`];
			if (!handler) { res.writeHead(404); return res.end('Route inconnue'); }
			let body = {};
			if (req.method === 'POST') {
				const chunks = []; for await (const c of req) chunks.push(c);
				body = chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {};
			}
			const data = await handler(body, url);
			res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
			return res.end(JSON.stringify(data));
		}
		// Fichiers statiques
		const file = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
		const full = path.join(HERE, 'public', path.normalize(file).replace(/^(\.\.[/\\])+/, ''));
		if (!full.startsWith(path.join(HERE, 'public'))) { res.writeHead(403); return res.end(); }
		let content = await readFile(full);
		if (file === 'index.html') content = Buffer.from(content.toString('utf8').replace('__ASTRAL_TOKEN__', TOKEN));
		res.writeHead(200, { 'Content-Type': MIME[path.extname(full)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
		res.end(content);
	} catch (e) {
		res.writeHead(e.code === 'ENOENT' ? 404 : 500, { 'Content-Type': 'application/json; charset=utf-8' });
		res.end(JSON.stringify({ error: e.message }));
	}
});

server.listen(PORT, '127.0.0.1', () => {
	console.log(`Astral Panel prêt : http://127.0.0.1:${PORT}`);
	connectConsole();
});
