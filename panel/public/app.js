// Astral Panel — interface. Tout texte venant du serveur de jeu est inséré via textContent ou esc() (pas d'injection HTML).
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmtBytes = (b) => { b = Number(b) || 0; const u = ['o', 'Ko', 'Mo', 'Go']; let i = 0; while (b >= 1024 && i < 3) { b /= 1024; i++; } return `${b.toFixed(i ? 1 : 0)} ${u[i]}`; };
const fmtMoney = (n) => '£' + Math.round(Number(n) || 0).toLocaleString('fr-FR');
const fmtDur = (s) => { s = Math.floor(s || 0); const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60; return h ? `${h} h ${String(m).padStart(2, '0')}` : `${m} min`; };
const fmtDate = (ts) => new Date(ts * 1000).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' });
const STATES = { running: 'En ligne', starting: 'Démarrage…', stopping: 'Arrêt…', offline: 'Hors ligne' };

async function api(path, opts = {}) {
	const res = await fetch(path, {
		method: opts.method || 'GET',
		headers: { 'X-Astral-Token': window.ASTRAL_TOKEN, ...(opts.body ? { 'Content-Type': 'application/json' } : {}) },
		body: opts.body ? JSON.stringify(opts.body) : undefined,
	});
	const data = await res.json().catch(() => ({}));
	if (!res.ok || data.error) throw new Error(data.error || `Erreur ${res.status}`);
	return data;
}
function toast(msg, kind = '') {
	const t = document.createElement('div'); t.className = `toast ${kind}`; t.textContent = msg;
	$('#toasts').append(t); setTimeout(() => t.remove(), 4500);
}

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------
const TITLES = { dashboard: 'Tableau de bord', console: 'Console', players: 'Joueurs', economy: 'Économie', community: 'Communauté', market: 'Marché', security: 'Sécurité', logs: 'Journaux', files: 'Fichiers', config: 'Configuration', backups: 'Sauvegardes' };
const loaders = {};
function go(page) {
	$$('#nav a').forEach((a) => a.classList.toggle('active', a.dataset.page === page));
	$$('.page').forEach((p) => p.classList.toggle('active', p.id === `page-${page}`));
	$('#page-title').textContent = TITLES[page];
	location.hash = page;
	loaders[page]?.();
}
$$('#nav a').forEach((a) => a.addEventListener('click', () => go(a.dataset.page)));
// Lien direct ou retour arrière (#market, #logs…) sans recharger la page
addEventListener('hashchange', () => { const p = location.hash.slice(1); if (p in TITLES && !$(`#page-${p}`).classList.contains('active')) go(p); });
$$('[data-goto]').forEach((a) => a.addEventListener('click', () => go(a.dataset.goto)));

// ---------------------------------------------------------------------------
// Alimentation
// ---------------------------------------------------------------------------
$$('[data-power]').forEach((b) => b.addEventListener('click', async () => {
	const signal = b.dataset.power;
	const labels = { start: 'démarrer', restart: 'redémarrer', stop: 'arrêter', kill: 'FORCER l\'arrêt (perte possible de données non sauvegardées)' };
	if (signal !== 'start' && !confirm(`Voulez-vous vraiment ${labels[signal]} le serveur ?`)) return;
	try { await api('/api/power', { method: 'POST', body: { signal } }); toast(`Signal « ${signal} » envoyé.`, 'good'); }
	catch (e) { toast(e.message, 'bad'); }
}));

// ---------------------------------------------------------------------------
// Console en direct + statistiques (SSE)
// ---------------------------------------------------------------------------
const consoleEl = $('#console'), miniEl = $('#mini-console');
function lineClass(l) { return /error|\[ERROR\]|ECHEC|ERREUR/i.test(l) ? 'err' : /\[Astral/.test(l) ? 'astral' : /OK|Connected/.test(l) ? 'ok' : ''; }
function appendLine(el, line, max) {
	const atBottom = el.scrollTop + el.clientHeight >= el.scrollHeight - 30;
	const span = document.createElement('span'); span.className = lineClass(line); span.textContent = line + '\n';
	el.append(span);
	while (el.childNodes.length > max) el.firstChild.remove();
	if (atBottom) el.scrollTop = el.scrollHeight;
}
const series = { cpu: [], ram: [] };
function spark(canvas, data, color, max) {
	const c = canvas, ctx = c.getContext('2d'); c.width = c.clientWidth * devicePixelRatio; c.height = 40 * devicePixelRatio;
	ctx.clearRect(0, 0, c.width, c.height); if (data.length < 2) return;
	const top = max || Math.max(...data, 1);
	ctx.beginPath();
	data.forEach((v, i) => { const x = (i / (data.length - 1)) * c.width, y = c.height - (v / top) * (c.height - 4) - 2; i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); });
	ctx.strokeStyle = color; ctx.lineWidth = 2 * devicePixelRatio; ctx.stroke();
	ctx.lineTo(c.width, c.height); ctx.lineTo(0, c.height); ctx.closePath();
	const g = ctx.createLinearGradient(0, 0, 0, c.height); g.addColorStop(0, color + '55'); g.addColorStop(1, color + '00'); ctx.fillStyle = g; ctx.fill();
}
let limits = null;
function setState(s) {
	$('#pill .dot').className = `dot ${s}`; $('#pill-text').textContent = STATES[s] || s; $('#k-state').textContent = STATES[s] || s;
}
const es = new EventSource(`/api/console/stream?token=${window.ASTRAL_TOKEN}`);
es.addEventListener('history', (e) => { for (const l of JSON.parse(e.data)) { appendLine(consoleEl, l, 1000); appendLine(miniEl, l, 120); } });
es.addEventListener('line', (e) => { const l = JSON.parse(e.data); appendLine(consoleEl, l, 1000); appendLine(miniEl, l, 120); });
es.addEventListener('status', (e) => setState(JSON.parse(e.data)));
es.addEventListener('console', (e) => { const s = JSON.parse(e.data); const b = $('#console-state'); b.textContent = `Console ${s}`; b.className = `badge ${s === 'connectée' ? 'ok' : ''}`; });
es.addEventListener('stats', (e) => {
	const s = JSON.parse(e.data);
	series.cpu.push(s.cpu_absolute); series.ram.push(s.memory_bytes / 1048576);
	for (const k of ['cpu', 'ram']) if (series[k].length > 60) series[k].shift();
	$('#k-cpu').textContent = `${s.cpu_absolute.toFixed(1)} %`;
	$('#k-ram').textContent = `${fmtBytes(s.memory_bytes)}${limits ? ' / ' + limits.memory + ' Mo' : ''}`;
	$('#k-uptime').textContent = s.uptime ? `Depuis ${fmtDur(s.uptime / 1000)}` : '';
	spark($('#c-cpu'), series.cpu, '#6ecdff', limits?.cpu || 100);
	spark($('#c-ram'), series.ram, '#aa82ff', limits?.memory);
	if (s.state) setState(s.state);
});
$('#cmd-form').addEventListener('submit', async (e) => {
	e.preventDefault(); const cmd = $('#cmd').value.trim(); if (!cmd) return;
	try { await api('/api/command', { method: 'POST', body: { command: cmd } }); $('#cmd').value = ''; } catch (err) { toast(err.message, 'bad'); }
});
$$('[data-cmd]').forEach((b) => b.addEventListener('click', () => api('/api/command', { method: 'POST', body: { command: b.dataset.cmd } }).catch((e) => toast(e.message, 'bad'))));

// ---------------------------------------------------------------------------
// Tableau de bord
// ---------------------------------------------------------------------------
loaders.dashboard = async () => {
	try {
		const o = await api('/api/overview'); limits = o.limits; setState(o.state);
		$('#page-sub').textContent = o.info?.name || o.name;
		$('#k-players').textContent = o.info ? `${o.info.players} / ${o.info.maxPlayers}` : '—';
		$('#k-map').textContent = o.info ? `Map ${o.info.map}` : 'Serveur injoignable';
		const v = (k) => o.startup.find((x) => x.key === k)?.value || '—';
		const facts = [
			['Adresse', o.address], ['Map', o.info?.map || v('SRCDS_MAP')], ['Gamemode', v('GAMEMODE')], ['Collection Workshop', v('WORKSHOP_ID')],
			['Tickrate', v('TICKRATE')], ['Slots', v('MAX_PLAYERS')], ['Disque', `${fmtBytes(o.resources.disk_bytes)} / ${o.limits.disk} Mo`],
			['VAC', o.info ? (o.info.vac ? 'Activé' : 'Désactivé') : '—'], ['Token Steam (GSLT)', v('STEAM_ACC') ? 'Configuré' : 'À configurer'],
		];
		$('#facts').innerHTML = facts.map(([k, val]) => `<dt>${esc(k)}</dt><dd>${esc(val)}</dd>`).join('');
	} catch (e) { toast(e.message, 'bad'); }
};

// ---------------------------------------------------------------------------
// Joueurs
// ---------------------------------------------------------------------------
loaders.players = async () => {
	const tb = $('#players-table tbody'); tb.innerHTML = '<tr><td colspan="4" class="muted">Chargement…</td></tr>';
	try {
		const list = await api('/api/players');
		tb.innerHTML = list.length ? '' : '<tr><td colspan="4" class="muted">Aucun joueur connecté.</td></tr>';
		for (const p of list) {
			const tr = document.createElement('tr');
			tr.innerHTML = `<td><strong></strong></td><td>${p.score}</td><td>${fmtDur(p.duration)}</td><td class="actions"></td>`;
			tr.querySelector('strong').textContent = p.name;
			const actions = tr.querySelector('.actions');
			const act = (label, cmd, ask) => {
				const b = document.createElement('button'); b.className = 'btn small'; b.textContent = label; b.style.marginRight = '6px';
				b.onclick = async () => {
					let extra = '';
					if (ask) { extra = prompt(ask); if (extra === null) return; }
					try { await api('/api/command', { method: 'POST', body: { command: cmd(p.name, extra) } }); toast(`${label} : envoyé`, 'good'); } catch (e) { toast(e.message, 'bad'); }
				};
				actions.append(b);
			};
			const quote = (s) => `"${s.replace(/"/g, '')}"`;
			act('Kick', (n, r) => `ulx kick ${quote(n)} ${quote(r || 'Expulsé par un administrateur')}`, 'Raison du kick :');
			act('Ban 1 j', (n, r) => `ulx ban ${quote(n)} 1440 ${quote(r || 'Banni 24 h')}`, 'Raison du ban (24 h) :');
			act('Téléporter à moi', (n) => `ulx bring ${quote(n)}`);
			act('Geler', (n) => `ulx freeze ${quote(n)}`);
			tb.append(tr);
		}
	} catch (e) { tb.innerHTML = `<tr><td colspan="4" class="bad">${esc(e.message)}</td></tr>`; }
};
$('#refresh-players').addEventListener('click', () => loaders.players());

// ---------------------------------------------------------------------------
// Économie
// ---------------------------------------------------------------------------
function bars(el, rows, value, label, extra, empty = 'Aucune donnée sur 24 h.') {
	const max = Math.max(...rows.map(value), 1);
	el.innerHTML = rows.length ? '' : `<p class="muted">${esc(empty)}</p>`;
	for (const r of rows) {
		const d = document.createElement('div'); d.className = 'bar-row';
		d.innerHTML = `<span></span><div class="bar-track"><div class="bar-fill" style="width:${(value(r) / max) * 100}%"></div></div><span class="muted"></span>`;
		d.children[0].textContent = label(r); d.children[2].textContent = extra(r);
		el.append(d);
	}
}
loaders.economy = async () => {
	try {
		const s = await api('/api/astral/summary');
		$('#e-accounts').textContent = s.totalPlayers; $('#e-created').textContent = fmtMoney(s.created); $('#e-destroyed').textContent = fmtMoney(s.destroyed); $('#e-alerts').textContent = s.alerts.length;
		bars($('#e-sources'), s.sources, (r) => r.gain + r.loss, (r) => r.source, (r) => `+${fmtMoney(r.gain)} / -${fmtMoney(r.loss)}`);
		bars($('#e-activity'), s.activity, (r) => r.n, (r) => r.category, (r) => `${r.n}`);
		$('#e-richest tbody').innerHTML = '';
		for (const r of s.richest) {
			const tr = document.createElement('tr'); tr.innerHTML = '<td></td><td></td><td class="muted"></td>';
			tr.children[0].textContent = r.name; tr.children[1].textContent = fmtMoney(r.money); tr.children[2].textContent = `Niv. ${r.level}`;
			tr.style.cursor = 'pointer'; tr.onclick = () => openPlayer(r.sid64);
			$('#e-richest tbody').append(tr);
		}
		$('#e-alert-list').innerHTML = s.alerts.length ? '' : '<p class="muted">Aucune alerte.</p>';
		for (const a of s.alerts) {
			const d = document.createElement('div'); d.className = 'item'; d.innerHTML = '<span></span><span class="muted"></span>';
			const data = JSON.parse(a.data); d.children[0].textContent = `${a.name} : +${fmtMoney(data.gain)} en ${data.window} s`; d.children[1].textContent = fmtDate(a.ts);
			$('#e-alert-list').append(d);
		}
	} catch (e) { toast(e.message, 'bad'); }
};
async function openPlayer(sid) {
	go('players');
	const card = $('#player-card'); card.hidden = false; card.innerHTML = '<p class="muted">Chargement…</p>';
	try {
		const p = await api('/api/astral/player?sid64=' + sid);
		card.innerHTML = `<div class="card-head"><h2></h2><span class="muted small">${esc(p.sid64)}</span></div><dl class="facts"></dl><div class="scroll" style="max-height:360px;margin-top:14px"><table class="table"><tbody></tbody></table></div>`;
		card.querySelector('h2').textContent = p.name;
		const pr = p.profile || {};
		card.querySelector('.facts').innerHTML = [['Argent', fmtMoney(pr.money)], ['Niveau', pr.level], ['XP', pr.xp], ['Karma', pr.karma], ['Temps de jeu', fmtDur(pr.time)]].map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v ?? '—')}</dd>`).join('');
		const tb = card.querySelector('tbody');
		for (const l of p.logs) {
			const tr = document.createElement('tr'); tr.innerHTML = '<td></td><td><span class="cat"></span></td><td class="data"></td>';
			tr.children[0].textContent = fmtDate(l.ts); tr.querySelector('.cat').textContent = l.category; tr.children[2].textContent = l.data;
			tb.append(tr);
		}
	} catch (e) { card.innerHTML = `<p class="bad">${esc(e.message)}</p>`; }
}

// ---------------------------------------------------------------------------
// Communauté (classements, factions, recherche, quêtes) — noms repris de sh_research.lua / sh_quests.lua
// ---------------------------------------------------------------------------
const TECHS = { drill_1: 'Forage optimisé', refine_1: 'Fonderie avancée', storage_1: 'Logistique', drill_2: 'Forage profond', fab_1: 'Ateliers automatisés', trade_1: 'Négoce', energy_1: 'Réseau intelligent' };
const QUESTS = { d_collect: 'Récolte du jour', d_buy: 'Agrandir la base', d_play: 'Présence', d_refine: 'Fonderie', d_sell: 'Commerce industriel', d_harvest: 'Main verte', d_fabricate: 'Atelier', w_collect: 'Magnat', w_play: 'Pilier du serveur', w_fabricate: 'Chaîne de production', w_raid: 'Conquérant', w_sell: 'Exportateur' };
const BOARDS = [
	['money', 'Fortune', (r) => fmtMoney(r.v)], ['level', 'Niveau', (r) => `Niv. ${r.v}`], ['time', 'Temps de jeu', (r) => fmtDur(r.v)],
	['industry', 'Industriels', (r) => fmtMoney(r.v)], ['produced', 'Producteurs', (r) => `${r.v.toLocaleString('fr-FR')} u.`],
];
let community = null, boardId = 'money';
function renderBoard() {
	const tb = $('#c-board tbody'); tb.innerHTML = '';
	$$('#c-board-tabs button').forEach((b) => b.classList.toggle('active', b.dataset.id === boardId));
	const def = BOARDS.find((b) => b[0] === boardId);
	const rows = community?.boards[boardId] || [];
	if (!rows.length) tb.innerHTML = '<tr><td class="muted">Personne n\'est encore classé ici.</td></tr>';
	rows.forEach((r, i) => {
		const tr = document.createElement('tr');
		tr.innerHTML = `<td class="rank r${i + 1}">${i + 1}</td><td></td><td class="num"></td>`;
		tr.children[1].textContent = r.name; tr.children[2].textContent = def[2](r);
		tr.style.cursor = 'pointer'; tr.onclick = () => openPlayer(r.sid64);
		tb.append(tr);
	});
}
for (const [id, label] of BOARDS) {
	const b = document.createElement('button'); b.textContent = label; b.dataset.id = id;
	b.onclick = () => { boardId = id; renderBoard(); };
	$('#c-board-tabs').append(b);
}
loaders.community = async () => {
	try {
		community = await api('/api/astral/community');
		const c = community;
		$('#c-profiles').textContent = c.profiles.total; $('#c-week').textContent = `${c.profiles.week} actif(s) cette semaine`;
		$('#c-factions').textContent = c.factions.length;
		$('#c-research').textContent = c.research.reduce((s, r) => s + r.n, 0);
		$('#c-quests').textContent = c.quests.reduce((s, r) => s + r.claimed, 0);
		renderBoard();
		const ft = $('#c-faction-table tbody'); ft.innerHTML = c.factions.length ? '' : '<tr><td colspan="4" class="muted">Aucune faction active.</td></tr>';
		for (const f of c.factions) {
			const tr = document.createElement('tr');
			tr.innerHTML = '<td><span class="swatch"></span><strong></strong></td><td></td><td></td><td class="muted"></td>';
			tr.querySelector('.swatch').style.background = f.color;
			tr.querySelector('strong').textContent = f.name + (f.locked ? ' 🔒' : '');
			tr.children[1].textContent = f.leader; tr.children[2].textContent = f.members; tr.children[3].textContent = fmtDate(f.created);
			ft.append(tr);
		}
		bars($('#c-research-bars'), c.research, (r) => r.n, (r) => TECHS[r.id] || r.id, (r) => `${r.n}`, 'Aucune technologie débloquée pour l\'instant.');
		bars($('#c-quest-bars'), c.quests, (r) => r.started, (r) => QUESTS[r.id] || r.id, (r) => `${r.claimed} / ${r.started}`, 'Aucune quête commencée.');
	} catch (e) { toast(e.message, 'bad'); }
};

// ---------------------------------------------------------------------------
// Marché entre joueurs — noms repris de sh_resources.lua
// ---------------------------------------------------------------------------
const RES = {
	iron_ore: 'Minerai de fer', copper_ore: 'Minerai de cuivre', coal: 'Charbon', silicon: 'Silicium', rare_ore: 'Minerai rare', energy_crystal: 'Cristal énergétique',
	iron_ingot: 'Lingot de fer', copper_ingot: 'Lingot de cuivre', silicon_wafer: 'Plaquette de silicium', rare_alloy: 'Alliage rare',
	steel_plate: "Plaque d'acier", circuit: 'Circuit électronique', alloy_frame: 'Châssis en alliage', power_cell: 'Cellule énergétique',
	wheat: 'Blé', tomato: 'Tomates', herbs: 'Herbes médicinales', astral_flower: 'Fleur astrale', ration: 'Ration de survie', medicine: 'Médicament', astral_essence: 'Essence astrale',
};
const resName = (id) => RES[id] || id;
loaders.market = async () => {
	try {
		const m = await api('/api/astral/market');
		$('#m-open').textContent = m.open.length;
		$('#m-stock').textContent = `${m.open.reduce((s, o) => s + o.qty_left, 0).toLocaleString('fr-FR')} unités sous séquestre`;
		$('#m-count').textContent = m.week.count; $('#m-volume').textContent = fmtMoney(m.week.volume); $('#m-tax').textContent = fmtMoney(m.week.tax);
		$('#m-rate').textContent = `Taxe actuelle : ${m.settings['Market.TaxPercent'] ?? 5} %`;
		const ot = $('#m-open-table tbody'); ot.innerHTML = m.open.length ? '' : '<tr><td colspan="4" class="muted">Aucune offre ouverte.</td></tr>';
		for (const o of m.open) {
			const tr = document.createElement('tr'); tr.innerHTML = '<td><strong></strong></td><td></td><td></td><td class="num"></td>';
			tr.querySelector('strong').textContent = resName(o.resource); tr.children[1].textContent = o.sellerName;
			tr.children[2].textContent = `${o.qty_left} / ${o.qty_total}`; tr.children[3].textContent = fmtMoney(o.unit_price);
			ot.append(tr);
		}
		const st = $('#m-sales-table tbody'); st.innerHTML = m.sales.length ? '' : '<tr><td colspan="5" class="muted">Aucune vente pour l\'instant.</td></tr>';
		for (const s of m.sales) {
			const tr = document.createElement('tr'); tr.innerHTML = '<td class="muted"></td><td></td><td></td><td></td><td class="num"></td>';
			tr.children[0].textContent = fmtDate(s.ts); tr.children[1].textContent = s.buyer || '—'; tr.children[2].textContent = s.seller || '—';
			tr.children[3].textContent = `${s.qty} × ${resName(s.resource)}`; tr.children[4].textContent = fmtMoney(s.cost);
			st.append(tr);
		}
	} catch (e) { toast(e.message, 'bad'); }
};
$('#m-refresh').addEventListener('click', () => loaders.market());

// ---------------------------------------------------------------------------
// Sécurité — rapport de sv_security.lua + blocages d'Astral Shield (journal « security »)
// ---------------------------------------------------------------------------
const SEV = { critique: 'Critique', haute: 'Haute', moyenne: 'Moyenne' };
let security = null, secFilter = 'all', secAddon = null, scanPoll = null;
// Ouvre le fichier concerné dans l'onglet Fichiers (uniquement les fichiers présents sur le disque, pas le contenu des .gma Workshop)
function openSecurityFile(p) {
	if (/^\[/.test(p)) return toast('Fichier contenu dans un addon Workshop (.gma) : à retirer depuis la collection Workshop.', '');
	const full = '/garrysmod/' + p.replace(/:\d+$/, '');
	cwd = full.split('/').slice(0, -1).join('/');
	go('files'); openFile(full);
}
function renderFindings() {
	const r = security?.report;
	const tb = $('#s-findings tbody');
	if (!r) { tb.innerHTML = '<tr><td colspan="5" class="muted">Aucune analyse pour l\'instant : clique sur « Lancer une analyse ».</td></tr>'; return; }
	const fixed = new Set((security.fixes || []).filter((x) => !x.restored).map((x) => `${x.path}:${x.line}`));
	const rows = r.findings.filter((f) => (secFilter === 'all' || f.severity === secFilter) && (!secAddon || f.addon === secAddon));
	tb.innerHTML = rows.length ? '' : `<tr><td colspan="5" class="good">${r.findings.length ? 'Aucune faille pour ce filtre.' : 'Aucune faille détectée dans ' + r.files.toLocaleString('fr-FR') + ' fichiers.'}</td></tr>`;
	for (const f of rows) {
		const tr = document.createElement('tr');
		tr.innerHTML = '<td><span class="sev"></span></td><td><strong></strong><code class="sec-code"></code></td><td></td><td><a class="sec-path"></a></td><td><button class="btn bad small"></button></td>';
		const btn = tr.querySelector('button');
		const editable = /^(addons|lua|gamemodes)\/.+\.lua$/.test(f.path);
		if (fixed.has(`${f.path}:${f.line}`)) { btn.textContent = 'Supprimée'; btn.disabled = true; btn.title = 'Relance une analyse après le redémarrage pour confirmer.'; }
		else if (!editable) { btn.textContent = 'Supprimer la ligne'; btn.disabled = true; btn.title = /^\[/.test(f.path) ? 'Fichier dans un addon Workshop (.gma) : retire l\'addon de la collection.' : 'Ce n\'est pas un fichier Lua : supprime le fichier ou l\'addon.'; }
		else { btn.textContent = 'Supprimer la ligne'; btn.onclick = () => fixLine(f, btn); }
		const sev = tr.querySelector('.sev'); sev.textContent = SEV[f.severity] || f.severity; sev.classList.add(f.severity);
		tr.querySelector('strong').textContent = f.kind; tr.querySelector('code').textContent = f.excerpt || '';
		tr.children[2].textContent = f.addon;
		const a = tr.querySelector('.sec-path'); a.textContent = `${f.path}:${f.line}`; a.title = 'Ouvrir dans l\'onglet Fichiers'; a.onclick = () => openSecurityFile(f.path);
		tb.append(tr);
	}
}
async function fixLine(f, btn) {
	if (!confirm(`Supprimer la ligne ${f.line} de ${f.path} ?\n\n${f.excerpt}\n\nUne copie du fichier d'origine est gardée. Si la suppression casse le fichier, il est remis à l'identique automatiquement.`)) return;
	btn.disabled = true; btn.textContent = 'Suppression…';
	try {
		const r = await api('/api/security/fix', { method: 'POST', body: { path: f.path, line: f.line, excerpt: f.excerpt, kind: f.kind, addon: f.addon } });
		toast(r.syntax === 'OK' ? 'Ligne supprimée, fichier vérifié. Redémarre le serveur pour appliquer.' : 'Ligne supprimée (syntaxe non vérifiée : ' + r.syntax + '). Redémarre le serveur pour appliquer.', r.syntax === 'OK' ? 'good' : '');
		loaders.security();
	} catch (e) { toast(e.message, 'bad'); btn.disabled = false; btn.textContent = 'Supprimer la ligne'; }
}
function renderFixes() {
	const tb = $('#s-fixes tbody'), list = security?.fixes || [];
	tb.innerHTML = list.length ? '' : '<tr><td colspan="5" class="muted">Aucune ligne supprimée.</td></tr>';
	const SYN = { OK: 'Vérifiée', INCERTAIN: 'Faille encore présente', SANS_REPONSE: 'Non vérifiée' };
	for (const x of list) {
		const tr = document.createElement('tr'); tr.innerHTML = '<td class="muted"></td><td><a class="sec-path"></a><div class="muted small"></div></td><td><code class="sec-code"></code></td><td></td><td><button class="btn small"></button></td>';
		tr.children[0].textContent = fmtDate(x.ts);
		const a = tr.querySelector('.sec-path'); a.textContent = `${x.path}:${x.line}`; a.onclick = () => openSecurityFile(x.path);
		tr.querySelector('.small').textContent = `${x.addon || ''} — ${x.kind || ''}`;
		tr.querySelector('code').textContent = x.removed;
		tr.children[3].textContent = SYN[x.syntax] || x.syntax; tr.children[3].className = x.syntax === 'OK' ? 'good' : '';
		const b = tr.querySelector('button');
		if (x.restored) { b.textContent = 'Restaurée'; b.disabled = true; }
		else {
			b.textContent = 'Restaurer';
			b.onclick = async () => {
				if (!confirm(`Remettre ${x.path} tel qu'il était avant la suppression ?`)) return;
				try { await api('/api/security/restore', { method: 'POST', body: { id: x.id } }); toast('Fichier restauré. Redémarre le serveur pour appliquer.', 'good'); loaders.security(); }
				catch (e) { toast(e.message, 'bad'); }
			};
		}
		tb.append(tr);
	}
}
loaders.security = async () => {
	try {
		security = await api('/api/security');
		const { report: r, counts, blocks } = security;
		const active = r ? r.shield.active : null;
		$('#s-shield').textContent = active === false ? 'Absent' : r ? 'Actif' : '—';
		$('#s-shield').className = active === false ? 'bad' : r ? 'good' : '';
		$('#s-shield-sub').textContent = r ? `${r.shield.blocked} blocage(s) depuis le démarrage` : 'Pas encore de rapport';
		$('#s-crit').textContent = r ? r.counts.critique : '—';
		$('#s-crit').className = r && r.counts.critique ? 'bad' : r ? 'good' : '';
		$('#s-other').textContent = r ? `${r.counts.haute} haute(s) · ${r.counts.moyenne} moyenne(s)` : '';
		$('#s-blocks').textContent = counts.week; $('#s-blocks').className = counts.day ? 'bad' : '';
		$('#s-blocks-sub').textContent = `7 jours · ${counts.day} sur 24 h · ${counts.total} au total`;
		$('#s-last').textContent = r ? fmtDate(r.finished) : 'Jamais';
		$('#s-last-sub').textContent = r ? `${r.files.toLocaleString('fr-FR')} fichiers (${fmtBytes(r.bytes)}) en ${r.duration} s · ${r.workshop} addon(s) Workshop · lancée par ${r.by}` : '';
		$('#s-hosts').textContent = r ? r.shield.hosts.sort().join(', ') : 'kvcdoor.ovh, panelpetitvac.xyz, sinax.site, vcmod.xyz';
		// Addons concernés (cliquer pour filtrer)
		const per = {};
		for (const f of r?.findings || []) { const p = (per[f.addon] ??= { critique: 0, haute: 0, moyenne: 0 }); p[f.severity]++; }
		const box = $('#s-addons'); box.innerHTML = '';
		for (const [name, c] of Object.entries(per).sort((a, b) => b[1].critique - a[1].critique || b[1].haute - a[1].haute)) {
			const b = document.createElement('button'); b.className = 'sec-addon' + (c.critique ? ' crit' : c.haute ? ' high' : '') + (secAddon === name ? ' active' : '');
			b.innerHTML = '<strong></strong><span></span>'; b.children[0].textContent = name;
			b.children[1].textContent = [c.critique && `${c.critique} critique(s)`, c.haute && `${c.haute} haute(s)`, c.moyenne && `${c.moyenne} moyenne(s)`].filter(Boolean).join(' · ');
			b.onclick = () => { secAddon = secAddon === name ? null : name; loaders.security(); };
			box.append(b);
		}
		$('#s-ignored').textContent = r?.ignored?.length ? 'Ignorés volontairement : ' + r.ignored.map((i) => `${i.path} (${i.reason})`).join(' · ') : '';
		renderFindings();
		renderFixes();
		const tb = $('#s-blocks-table tbody'); tb.innerHTML = blocks.length ? '' : '<tr><td colspan="5" class="good">Aucune tentative bloquée.</td></tr>';
		for (const b of blocks) {
			const tr = document.createElement('tr'); tr.innerHTML = '<td class="muted"></td><td><span class="sev critique"></span></td><td></td><td><a class="sec-path"></a></td><td class="data"></td>';
			tr.children[0].textContent = fmtDate(b.ts); tr.querySelector('.sev').textContent = b.kind || '?';
			tr.children[2].textContent = b.addon || 'inconnu (bouclier v1)';
			const a = tr.querySelector('.sec-path'); a.textContent = b.source || '?';
			if (b.source && /\.lua:\d+$/.test(b.source)) { a.title = (b.chain || []).join('\n'); a.onclick = () => openSecurityFile(b.source); }
			tr.children[4].textContent = b.detail || '';
			tb.append(tr);
		}
	} catch (e) { toast(e.message, 'bad'); }
};
for (const [id, label] of [['all', 'Toutes'], ['critique', 'Critiques'], ['haute', 'Hautes'], ['moyenne', 'Moyennes']]) {
	const b = document.createElement('button'); b.textContent = label; b.className = id === 'all' ? 'active' : '';
	b.onclick = () => { secFilter = id; $$('#s-filter button').forEach((x) => x.classList.toggle('active', x === b)); renderFindings(); };
	$('#s-filter').append(b);
}
$('#s-scan').addEventListener('click', async () => {
	const before = security?.report?.finished || 0, btn = $('#s-scan');
	try {
		await api('/api/security/scan', { method: 'POST' });
		btn.disabled = true; btn.textContent = 'Analyse en cours…';
		clearInterval(scanPoll);
		let tries = 0;
		scanPoll = setInterval(async () => {
			tries++;
			try { await loaders.security(); } catch {}
			if ((security?.report?.finished || 0) > before || tries > 40) {
				clearInterval(scanPoll); btn.disabled = false; btn.textContent = 'Lancer une analyse';
				toast(tries > 40 ? 'Pas de nouveau rapport (serveur hors ligne ?)' : 'Analyse terminée.', tries > 40 ? 'bad' : 'good');
			}
		}, 3000);
	} catch (e) { toast(e.message, 'bad'); }
});

// ---------------------------------------------------------------------------
// Journaux
// ---------------------------------------------------------------------------
const CATS = ['security', 'security_scan', 'upgrade', 'money', 'buy', 'collect', 'industry_sell', 'level', 'join', 'leave', 'faction_create', 'faction_disband', 'faction_join', 'faction_leave', 'raid_start', 'raid_end', 'market_list', 'market_buy', 'market_cancel', 'market_payout', 'research', 'quest_claim', 'admin_command', 'admin_menu', 'economy_alert', 'net_reject', 'net_error', 'diag'];
for (const c of CATS) $('#log-cat').insertAdjacentHTML('beforeend', `<option>${c}</option>`);
loaders.logs = async () => {
	const tb = $('#logs-table tbody'); tb.innerHTML = '<tr><td colspan="4" class="muted">Chargement…</td></tr>';
	try {
		const params = new URLSearchParams(); if ($('#log-cat').value) params.set('category', $('#log-cat').value); if ($('#log-q').value) params.set('q', $('#log-q').value);
		const rows = await api('/api/astral/logs?' + params);
		tb.innerHTML = rows.length ? '' : '<tr><td colspan="4" class="muted">Aucun résultat.</td></tr>';
		for (const r of rows) {
			const tr = document.createElement('tr'); tr.innerHTML = '<td></td><td><span class="cat"></span></td><td></td><td class="data"></td>';
			tr.children[0].textContent = fmtDate(r.ts); tr.querySelector('.cat').textContent = r.category; tr.children[2].textContent = r.name || '—'; tr.children[3].textContent = r.data;
			if (r.sid64) { tr.children[2].style.cursor = 'pointer'; tr.children[2].style.color = 'var(--accent)'; tr.children[2].onclick = () => openPlayer(r.sid64); }
			tb.append(tr);
		}
	} catch (e) { tb.innerHTML = `<tr><td colspan="4" class="bad">${esc(e.message)}</td></tr>`; }
};
$('#log-go').addEventListener('click', () => loaders.logs());

// ---------------------------------------------------------------------------
// Fichiers
// ---------------------------------------------------------------------------
let cwd = '/garrysmod', openPath = null;
const TEXT_EXT = /\.(lua|cfg|txt|json|vdf|ini|md|log|properties)$/i;
loaders.files = async () => {
	$('#cwd').textContent = cwd;
	const list = $('#file-list'); list.innerHTML = '<p class="muted">Chargement…</p>';
	try {
		const files = await api('/api/files?dir=' + encodeURIComponent(cwd));
		list.innerHTML = '';
		const add = (label, meta, fn) => { const d = document.createElement('div'); d.className = 'item'; d.innerHTML = '<span></span><span class="muted small"></span>'; d.children[0].textContent = label; d.children[1].textContent = meta; d.onclick = fn; list.append(d); };
		if (cwd !== '/') add('↩ ..', '', () => { cwd = cwd.split('/').slice(0, -1).join('/') || '/'; loaders.files(); });
		for (const f of files) {
			const full = (cwd === '/' ? '' : cwd) + '/' + f.name;
			if (!f.file) add('📁 ' + f.name, '', () => { cwd = full; loaders.files(); });
			else add('📄 ' + f.name, fmtBytes(f.size), () => TEXT_EXT.test(f.name) ? openFile(full) : toast('Fichier binaire : édition non disponible.', 'bad'));
		}
	} catch (e) { list.innerHTML = `<p class="bad">${esc(e.message)}</p>`; }
};
async function openFile(p) {
	try {
		const f = await api('/api/file?path=' + encodeURIComponent(p));
		openPath = p; $('#editor').value = f.content; $('#editor-title').textContent = p; $('#save-file').disabled = false;
	} catch (e) { toast(e.message, 'bad'); }
}
$('#save-file').addEventListener('click', async () => {
	if (!openPath || !confirm(`Enregistrer ${openPath} sur le serveur ?`)) return;
	try { await api('/api/file', { method: 'POST', body: { path: openPath, content: $('#editor').value } }); toast('Fichier enregistré. Redémarre le serveur pour appliquer les changements Lua.', 'good'); }
	catch (e) { toast(e.message, 'bad'); }
});
$('#editor').addEventListener('keydown', (e) => {
	if (e.key === 'Tab') { e.preventDefault(); const t = e.target, s = t.selectionStart; t.value = t.value.slice(0, s) + '\t' + t.value.slice(t.selectionEnd); t.selectionStart = t.selectionEnd = s + 1; }
	if (e.key === 's' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); $('#save-file').click(); }
});

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
loaders.config = async () => {
	const box = $('#startup'); box.innerHTML = '<p class="muted">Chargement…</p>';
	try {
		const o = await api('/api/overview'); box.innerHTML = '';
		for (const v of o.startup) {
			const row = document.createElement('div'); row.className = 'field';
			row.innerHTML = '<label><strong></strong><small></small></label><input><button class="btn small">Appliquer</button>';
			row.querySelector('strong').textContent = v.name; row.querySelector('small').textContent = v.key;
			const input = row.querySelector('input'); input.value = v.value ?? '';
			if (v.key === 'STEAM_ACC') { input.type = 'password'; input.placeholder = 'Token GSLT (steamcommunity.com/dev/managegameservers, App ID 4000)'; }
			const btn = row.querySelector('button'); btn.disabled = !v.editable;
			btn.onclick = async () => { try { await api('/api/startup', { method: 'POST', body: { key: v.key, value: input.value } }); toast(`${v.name} mis à jour. Redémarre pour appliquer.`, 'good'); } catch (e) { toast(e.message, 'bad'); } };
			box.append(row);
		}
	} catch (e) { box.innerHTML = `<p class="bad">${esc(e.message)}</p>`; }
};

// ---------------------------------------------------------------------------
// Sauvegardes
// ---------------------------------------------------------------------------
loaders.backups = async () => {
	const tb = $('#backups-table tbody');
	try {
		const list = await api('/api/backups');
		tb.innerHTML = list.map((b) => `<tr><td>${esc(b.name)}</td><td class="muted">${fmtBytes(b.size)}</td></tr>`).join('') || '<tr><td class="muted">Aucune sauvegarde.</td></tr>';
	} catch (e) { tb.innerHTML = `<tr><td class="bad">${esc(e.message)}</td></tr>`; }
};
$('#do-backup').addEventListener('click', async (e) => {
	const b = e.target; b.disabled = true; b.textContent = 'Sauvegarde en cours…';
	const out = $('#backup-out'); out.hidden = false; out.textContent = 'Export de la base puis archive des fichiers…';
	try { const r = await api('/api/backups', { method: 'POST' }); out.textContent = r.output; toast(r.ok ? 'Sauvegarde terminée.' : 'Sauvegarde en échec.', r.ok ? 'good' : 'bad'); loaders.backups(); }
	catch (err) { out.textContent = err.message; }
	b.disabled = false; b.textContent = 'Sauvegarder maintenant';
});

// Démarrage
go(location.hash.slice(1) in TITLES ? location.hash.slice(1) : 'dashboard');
setInterval(() => { if ($('#page-dashboard').classList.contains('active')) loaders.dashboard(); }, 30000);
