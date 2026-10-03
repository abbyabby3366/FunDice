/**
 * FunDice Operations Console - Client Controller
 * White Theme, Left Sidebar, Real-time Filters, Inspectors & Odds Calculator
 */

let lastData = null;
let gamesFilter = 'all';
let gamesSearchQuery = '';
let playersFilter = 'all';
let playersSearchQuery = '';
let invitesFilter = 'all';
let invitesSearchQuery = '';

// 1. Navigation & Tab Controller
function switchTab(tabId) {
  const cleanId = (tabId || 'overview').replace('#', '').trim();
  const tabs = document.querySelectorAll('.dashboard-tab');
  const navBtns = document.querySelectorAll('.nav-item');

  let activeSection = document.getElementById('tab-' + cleanId);
  if (!activeSection && tabs.length > 0) activeSection = tabs[0];

  tabs.forEach(s => s.classList.toggle('hidden', s !== activeSection));
  const finalId = activeSection ? activeSection.id.replace('tab-', '') : cleanId;

  navBtns.forEach(btn => {
    const isTarget = btn.getAttribute('data-tab') === finalId;
    btn.classList.toggle('active', isTarget);
    btn.setAttribute('aria-selected', isTarget ? 'true' : 'false');
  });

  const activeBtn = document.querySelector(`.nav-item[data-tab="${finalId}"] .nav-label`);
  const breadcrumb = document.getElementById('active-tab-title');
  if (breadcrumb) {
    breadcrumb.textContent = activeBtn ? activeBtn.textContent : (finalId.charAt(0).toUpperCase() + finalId.slice(1));
  }

  if (window.location.hash !== '#' + finalId && window.history?.replaceState) {
    window.history.replaceState(null, '', '#' + finalId);
  }
}
window.switchTab = switchTab;

// 2. Strict Date & Time formatting: DD-MM-YY and GMT+8 (Asia/Kuala_Lumpur)
function formatGmt8(isoOrMs) {
  if (!isoOrMs) return { primary: '—', secondary: '' };
  const d = new Date(isoOrMs);
  if (isNaN(d.getTime())) return { primary: '—', secondary: '' };

  const formatter = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Kuala_Lumpur',
    day: '2-digit', month: '2-digit', year: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
    hour12: false,
  });

  const parts = formatter.formatToParts(d);
  const getP = (type) => parts.find(p => p.type === type)?.value || '';

  const dateStr = `${getP('day')}-${getP('month')}-${getP('year')}`; // DD-MM-YY
  const timeStr = `${getP('hour')}:${getP('minute')}:${getP('second')} (GMT+8)`;
  return { primary: timeStr, secondary: dateStr };
}

// Tables: Render date & time on two stacked separate rows (Primary on top, secondary greyed out)
function renderDateTimeCell(isoOrMs) {
  const { primary, secondary } = formatGmt8(isoOrMs);
  if (primary === '—') return '<span>—</span>';
  return `<div class="datetime-cell"><span class="dt-primary">${primary}</span><span class="dt-secondary">${secondary}</span></div>`;
}

function formatUptime(seconds) {
  const s = Math.floor(seconds % 60);
  const m = Math.floor((seconds / 60) % 60);
  const h = Math.floor(seconds / 3600);
  if (h > 0) return `${h}h ${m}m ${s}s`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

function showToast(message) {
  const toast = document.getElementById('toast');
  if (!toast) return;
  toast.textContent = message;
  toast.classList.remove('hidden');
  clearTimeout(toast._timeout);
  toast._timeout = setTimeout(() => toast.classList.add('hidden'), 2200);
}

function copyToClipboard(text, label = 'ID') {
  navigator.clipboard.writeText(text).then(() => showToast(`Copied ${label} to clipboard!`)).catch(() => showToast(`Failed to copy`));
}

function updateClock() {
  const clockEl = document.getElementById('clock-display');
  if (!clockEl) return;
  const { primary, secondary } = formatGmt8(new Date());
  clockEl.textContent = `${secondary} • ${primary}`;
}

// 3. Renderers with Search & Filter
function renderGamesTable() {
  if (!lastData?.games) return;
  const tbody = document.getElementById('games-tbody');
  const allGames = lastData.games;

  document.getElementById('count-games-all').textContent = allGames.length;
  document.getElementById('count-games-playing').textContent = allGames.filter(g => g.status === 'playing').length;
  document.getElementById('count-games-finished').textContent = allGames.filter(g => g.status === 'finished').length;

  let filtered = allGames;
  if (gamesFilter === 'playing') filtered = filtered.filter(g => g.status === 'playing');
  if (gamesFilter === 'finished') filtered = filtered.filter(g => g.status === 'finished');
  if (gamesSearchQuery) {
    const q = gamesSearchQuery.toLowerCase();
    filtered = filtered.filter(g => g.id.toLowerCase().includes(q) || g.players.some(p => p.name.toLowerCase().includes(q)));
  }

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" class="empty-cell">No games match the current filter.</td></tr>';
    return;
  }

  tbody.innerHTML = filtered.map(g => {
    const statusBadge = g.status === 'playing' ? '<span class="badge badge-playing">● In Play</span>' : '<span class="badge badge-finished">Finished</span>';
    const playersStr = g.players.map(p => `<strong>${p.name}</strong> (${p.diceCount}🎲)`).join(' vs ');
    const bidStr = g.currentBid ? `${g.currentBid.quantity} &times; [${g.currentBid.face}] by ${g.currentBid.by}` : (g.status === 'playing' ? 'Awaiting bid' : '—');
    const turnStr = g.status === 'playing' ? `Turn: <strong>${g.turnPlayer}</strong><br><small style="color:var(--text-muted)">${bidStr}</small>` : '—';
    const winStr = g.winner ? `🏆 <strong>${g.winner}</strong><br><small style="color:var(--text-muted)">${g.endReason || ''}</small>` : 'In progress';

    return `<tr>
      <td><span class="copy-id" title="Click to copy full ID" onclick="copyToClipboard('${g.id}', 'Game ID')">${g.id.slice(0, 8)}...</span></td>
      <td>${statusBadge}</td>
      <td>Round ${g.round}</td>
      <td>${playersStr}</td>
      <td>${turnStr}</td>
      <td>${winStr}</td>
      <td>${renderDateTimeCell(g.createdAt)}</td>
      <td><button class="btn-inspect" onclick="inspectGame('${g.id}')">Inspect</button></td>
    </tr>`;
  }).join('');
}

function renderPlayersTable() {
  if (!lastData?.users) return;
  const tbody = document.getElementById('players-tbody');
  const allUsers = lastData.users;

  document.getElementById('count-players-all').textContent = allUsers.length;
  document.getElementById('count-players-online').textContent = allUsers.filter(u => u.isOnline).length;
  document.getElementById('count-players-offline').textContent = allUsers.filter(u => !u.isOnline).length;

  let filtered = allUsers;
  if (playersFilter === 'online') filtered = filtered.filter(u => u.isOnline);
  if (playersFilter === 'offline') filtered = filtered.filter(u => !u.isOnline);
  if (playersSearchQuery) {
    const q = playersSearchQuery.toLowerCase();
    filtered = filtered.filter(u => u.name.toLowerCase().includes(q) || u.id.toLowerCase().includes(q));
  }

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" class="empty-cell">No players match the current filter.</td></tr>';
    return;
  }

  tbody.innerHTML = filtered.map(u => {
    const statusBadge = u.isOnline ? '<span class="badge badge-online">● Online</span>' : '<span class="badge badge-offline">Offline</span>';
    return `<tr>
      <td><span class="copy-id" title="Click to copy full ID" onclick="copyToClipboard('${u.id}', 'Player ID')">${u.id.slice(0, 8)}...</span></td>
      <td><strong>${u.name}</strong></td>
      <td>${statusBadge}</td>
      <td><code>${u.socketCount}</code></td>
      <td>${u.rollCount}</td>
      <td>${renderDateTimeCell(u.lastSeenAt)}</td>
      <td>${renderDateTimeCell(u.createdAt)}</td>
      <td><button class="btn-inspect" onclick="inspectPlayer('${u.id}')">Profile</button></td>
    </tr>`;
  }).join('');
}

function renderInvitesTable() {
  if (!lastData?.invites) return;
  const tbody = document.getElementById('invites-tbody');
  const allInvites = lastData.invites;

  document.getElementById('count-invites-all').textContent = allInvites.length;
  document.getElementById('count-invites-pending').textContent = allInvites.filter(i => i.status === 'pending').length;
  document.getElementById('count-invites-resolved').textContent = allInvites.filter(i => i.status !== 'pending').length;

  let filtered = allInvites;
  if (invitesFilter === 'pending') filtered = filtered.filter(i => i.status === 'pending');
  if (invitesFilter === 'resolved') filtered = filtered.filter(i => i.status !== 'pending');
  if (invitesSearchQuery) {
    const q = invitesSearchQuery.toLowerCase();
    filtered = filtered.filter(i => i.from.name.toLowerCase().includes(q) || i.to.name.toLowerCase().includes(q) || i.id.toLowerCase().includes(q));
  }

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" class="empty-cell">No invitations match the current filter.</td></tr>';
    return;
  }

  tbody.innerHTML = filtered.map(i => {
    const badgeClass = `badge-${i.status}`;
    return `<tr>
      <td><span class="copy-id" title="Click to copy full ID" onclick="copyToClipboard('${i.id}', 'Invite ID')">${i.id.slice(0, 8)}...</span></td>
      <td><strong>${i.from.name}</strong></td>
      <td><strong>${i.to.name}</strong></td>
      <td><span class="badge ${badgeClass}">${i.status}</span></td>
      <td>${renderDateTimeCell(i.createdAt)}</td>
      <td>${renderDateTimeCell(i.expiresAt)}</td>
    </tr>`;
  }).join('');
}

// 4. Modal Inspectors
function openModal(title, htmlContent) {
  const modal = document.getElementById('inspector-modal');
  document.getElementById('modal-title').textContent = title;
  document.getElementById('modal-content').innerHTML = htmlContent;
  modal.classList.remove('hidden');
}

function closeModal() {
  const modal = document.getElementById('inspector-modal');
  if (modal) modal.classList.add('hidden');
}
window.closeModal = closeModal;

function inspectGame(gameId) {
  if (!lastData?.games) return;
  const g = lastData.games.find(x => x.id === gameId);
  if (!g) return;

  const { primary: createdTime, secondary: createdDate } = formatGmt8(g.createdAt);
  const playersHtml = g.players.map(p => `
    <div style="background:var(--canvas-bg); padding:0.6rem; border-radius:var(--radius-md); border:1px solid var(--card-border); margin-bottom:0.4rem;">
      <div style="display:flex; justify-content:space-between; align-items:center;">
        <strong>${p.name}</strong>
        <span class="badge ${p.online ? 'badge-online' : 'badge-offline'}">${p.online ? 'Connected' : 'Disconnected'}</span>
      </div>
      <div style="font-size:0.78rem; color:var(--text-muted); margin-top:0.25rem;">
        Dice remaining: <strong>${p.diceCount}</strong> &bull; Peeks left: <strong>${p.peeksLeft}</strong>
      </div>
    </div>
  `).join('');

  const bidHtml = g.currentBid
    ? `<div style="font-family:var(--font-mono); font-size:0.85rem;">${g.currentBid.quantity} &times; Die [${g.currentBid.face}] by <strong>${g.currentBid.by}</strong></div>`
    : '<div style="color:var(--text-muted);">None (awaiting opening bid)</div>';

  const html = `
    <div style="display:flex; flex-direction:column; gap:0.85rem;">
      <div>
        <div style="font-size:0.75rem; color:var(--text-muted); text-transform:uppercase;">Game ID</div>
        <div style="font-family:var(--font-mono); font-size:0.85rem; font-weight:600; cursor:pointer;" onclick="copyToClipboard('${g.id}', 'Game ID')">
          ${g.id} <span style="font-size:0.72rem; color:var(--primary); font-weight:normal;">(Click to copy)</span>
        </div>
      </div>
      <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.5rem;">
        <div><div style="font-size:0.75rem; color:var(--text-muted);">Status</div><span class="badge ${g.status === 'playing' ? 'badge-playing' : 'badge-finished'}">${g.status}</span></div>
        <div><div style="font-size:0.75rem; color:var(--text-muted);">Round</div><strong>Round ${g.round}</strong></div>
      </div>
      <div><div style="font-size:0.75rem; color:var(--text-muted); margin-bottom:0.35rem;">Players in Match</div>${playersHtml}</div>
      <div><div style="font-size:0.75rem; color:var(--text-muted); margin-bottom:0.2rem;">Current Active Bid</div>${bidHtml}</div>
      <div><div style="font-size:0.75rem; color:var(--text-muted);">Match Started</div><div style="font-family:var(--font-mono); font-size:0.8rem;">${createdDate} ${createdTime}</div></div>
    </div>
  `;
  openModal('Match Inspector', html);
}
window.inspectGame = inspectGame;

function inspectPlayer(userId) {
  if (!lastData?.users) return;
  const u = lastData.users.find(x => x.id === userId);
  if (!u) return;

  const reg = formatGmt8(u.createdAt);
  const seen = formatGmt8(u.lastSeenAt);

  const html = `
    <div style="display:flex; flex-direction:column; gap:0.85rem;">
      <div>
        <div style="font-size:0.75rem; color:var(--text-muted); text-transform:uppercase;">Player ID</div>
        <div style="font-family:var(--font-mono); font-size:0.85rem; font-weight:600; cursor:pointer;" onclick="copyToClipboard('${u.id}', 'Player ID')">
          ${u.id} <span style="font-size:0.72rem; color:var(--primary); font-weight:normal;">(Click to copy)</span>
        </div>
      </div>
      <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.5rem;">
        <div><div style="font-size:0.75rem; color:var(--text-muted);">Player Name</div><strong style="font-size:1.05rem;">${u.name}</strong></div>
        <div><div style="font-size:0.75rem; color:var(--text-muted);">Network Status</div><span class="badge ${u.isOnline ? 'badge-online' : 'badge-offline'}">${u.isOnline ? 'Online' : 'Offline'}</span></div>
      </div>
      <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.5rem;">
        <div><div style="font-size:0.75rem; color:var(--text-muted);">Active Sockets</div><code>${u.socketCount}</code></div>
        <div><div style="font-size:0.75rem; color:var(--text-muted);">Rolls Recorded</div><strong>${u.rollCount}</strong></div>
      </div>
      <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.5rem;">
        <div><div style="font-size:0.75rem; color:var(--text-muted);">Registered (GMT+8)</div><div style="font-family:var(--font-mono); font-size:0.78rem;">${reg.secondary}<br>${reg.primary}</div></div>
        <div><div style="font-size:0.75rem; color:var(--text-muted);">Last Seen (GMT+8)</div><div style="font-family:var(--font-mono); font-size:0.78rem;">${seen.secondary}<br>${seen.primary}</div></div>
      </div>
    </div>
  `;
  openModal('Player Profile', html);
}
window.inspectPlayer = inspectPlayer;

// 5. Data Export (JSON)
function exportData(type) {
  if (!lastData?.[type]) {
    showToast('No server data available to export');
    return;
  }
  const blob = new Blob([JSON.stringify(lastData[type], null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `fundice-${type}-${Date.now()}.json`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  showToast(`Exported ${type}.json successfully!`);
}

// 6. Liar's Dice Odds Calculator
function calcCombinations(n, k) {
  if (k < 0 || k > n) return 0;
  if (k === 0 || k === n) return 1;
  let c = 1;
  for (let i = 1; i <= k; i++) c = (c * (n - (k - i))) / i;
  return c;
}

function updateCalculator() {
  const totalDice = parseInt(document.getElementById('calc-total-dice')?.value || '10', 10);
  const face = parseInt(document.getElementById('calc-face')?.value || '6', 10);
  const qty = parseInt(document.getElementById('calc-qty')?.value || '4', 10);

  const p = face === 1 ? (1 / 6) : (1 / 3);
  const expected = (totalDice * p).toFixed(1);

  let probSum = 0;
  for (let k = qty; k <= totalDice; k++) {
    probSum += calcCombinations(totalDice, k) * Math.pow(p, k) * Math.pow(1 - p, totalDice - k);
  }

  const probPercent = Math.min(100, Math.max(0, probSum * 100));
  const probValEl = document.getElementById('calc-prob-val');
  const probSubEl = document.getElementById('calc-prob-sub');
  const riskValEl = document.getElementById('calc-risk-val');

  if (probValEl) probValEl.textContent = `${probPercent.toFixed(1)}%`;
  if (probSubEl) probSubEl.textContent = `Expected face count: ${expected} dice`;

  let risk = 'Risky (Likely Bluff)';
  let riskColor = 'var(--rose)';
  if (probPercent >= 75) { risk = 'Very Safe'; riskColor = 'var(--emerald)'; }
  else if (probPercent >= 55) { risk = 'Statistically Likely'; riskColor = '#0284c7'; }
  else if (probPercent >= 35) { risk = 'Moderate Chance'; riskColor = 'var(--amber)'; }
  else if (probPercent >= 15) { risk = 'High Risk'; riskColor = '#ea580c'; }

  if (riskValEl) {
    riskValEl.textContent = risk;
    riskValEl.style.color = riskColor;
  }
}

// 7. Auto-fetch Dashboard Update
async function updateDashboard() {
  const errorBanner = document.getElementById('error-banner');
  const errorMsg = document.getElementById('error-message');

  try {
    const res = await fetch('/api/admin/status');
    if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    const data = await res.json();
    lastData = data;
    if (errorBanner) errorBanner.classList.add('hidden');

    document.getElementById('metric-online').textContent = data.metrics.onlineUsers;
    document.getElementById('metric-total-users').textContent = `${data.metrics.totalUsers} registered in memory`;
    document.getElementById('metric-games').textContent = data.metrics.activeGames;
    document.getElementById('metric-invites').textContent = data.metrics.pendingInvites;
    document.getElementById('metric-uptime').textContent = formatUptime(data.server.uptime);
    document.getElementById('metric-env').textContent = `${data.config.nodeEnv} • ${data.server.nodeVersion}`;

    const bg = document.getElementById('badge-games');
    if (bg) bg.textContent = data.metrics.activeGames;
    const bp = document.getElementById('badge-players');
    if (bp) bp.textContent = data.metrics.onlineUsers;
    const bi = document.getElementById('badge-invites');
    if (bi) bi.textContent = data.metrics.pendingInvites;

    const sideSub = document.getElementById('side-sub-status');
    if (sideSub) sideSub.textContent = `Port ${data.config.port} • ${data.config.nodeEnv}`;

    document.getElementById('sys-node').textContent = data.server.nodeVersion;
    document.getElementById('sys-heap').textContent = `${data.server.memory.heapUsedMB} MB / ${data.server.memory.heapTotalMB} MB`;
    document.getElementById('sys-env').textContent = data.config.nodeEnv;
    document.getElementById('sys-port').textContent = String(data.config.port);

    if (data.database && document.getElementById('sys-db')) {
      const isConnected = data.database.status === 'connected';
      const badge = isConnected
        ? '<span class="badge badge-online">● Connected</span>'
        : `<span class="badge badge-offline">${data.database.status || 'disconnected'}</span>`;
      const counts = isConnected
        ? ` <span style="color:var(--text-muted); font-size:12px;">(${data.database.usersCount || 0} users, ${data.database.rollsCount || 0} rolls, ${data.database.gamesCount || 0} games)</span>`
        : '';
      document.getElementById('sys-db').innerHTML = `${badge}${counts}`;
    }
    const sTime = formatGmt8(data.server.serverTime);
    document.getElementById('sys-time').textContent = `${sTime.secondary} ${sTime.primary}`;

    renderGamesTable();
    renderPlayersTable();
    renderInvitesTable();

    const configGrid = document.getElementById('config-grid');
    if (configGrid && !configGrid.children.length) {
      configGrid.innerHTML = `
        <div class="config-row"><span class="config-key">Dice Per Player</span><span class="config-val">${data.config.diceCount} dice</span></div>
        <div class="config-row"><span class="config-key">Roll History Kept</span><span class="config-val">${data.config.rollHistory} rolls</span></div>
        <div class="config-row"><span class="config-key">Peeks Allowed Per Match</span><span class="config-val">${data.config.peeksPerGame} peeks</span></div>
        <div class="config-row"><span class="config-key">Peek Caught Probability</span><span class="config-val">${Math.round(data.config.peekCaughtChance * 100)}%</span></div>
        <div class="config-row"><span class="config-key">Invite TTL</span><span class="config-val">${data.config.inviteTtlSec}s</span></div>
        <div class="config-row"><span class="config-key">Disconnect Grace Period</span><span class="config-val">${data.config.disconnectGraceSec}s</span></div>
        <div class="config-row"><span class="config-key">Session Token Lifetime</span><span class="config-val">${data.config.tokenTtlDays} days</span></div>
        <div class="config-row"><span class="config-key">Rematch Window</span><span class="config-val">${data.config.rematchWindowMin} mins</span></div>
        <div class="config-row"><span class="config-key">User Idle Sweep</span><span class="config-val">${data.config.userIdleTtlHours} hours</span></div>
        <div class="config-row"><span class="config-key">WebSocket Ping Interval</span><span class="config-val">${data.config.pingIntervalSec}s</span></div>
        <div class="config-row"><span class="config-key">Max Sockets Per User</span><span class="config-val">${data.config.maxSocketsPerUser}</span></div>
        <div class="config-row"><span class="config-key">JWT Secret State</span><span class="badge ${data.config.jwtSecretConfigured ? 'badge-online' : 'badge-pending'}">${data.config.jwtSecretConfigured ? 'Key Set' : 'Auto-generated'}</span></div>
      `;
    }
  } catch (err) {
    if (errorBanner) errorBanner.classList.remove('hidden');
    if (errorMsg) errorMsg.textContent = `Backend connection interrupted (${err.message}). Retrying automatically...`;
  }
}

// 8. Event Binding & Initialization
function initApp() {
  document.querySelectorAll('.nav-item').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const tabId = btn.getAttribute('data-tab');
      if (tabId) {
        switchTab(tabId);
        document.getElementById('sidebar')?.classList.remove('open');
      }
    });
  });

  const toggleBtn = document.getElementById('sidebar-toggle');
  const sidebar = document.getElementById('sidebar');
  if (toggleBtn && sidebar) {
    toggleBtn.addEventListener('click', () => sidebar.classList.toggle('open'));
  }

  // Filter & Search bindings
  const setupFilterSearch = (filterGroupId, searchInputId, filterVarSetter, searchVarSetter, renderFn) => {
    document.querySelectorAll(`#${filterGroupId} .filter-pill`).forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll(`#${filterGroupId} .filter-pill`).forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        filterVarSetter(btn.dataset.filter);
        renderFn();
      });
    });
    document.getElementById(searchInputId)?.addEventListener('input', (e) => {
      searchVarSetter(e.target.value);
      renderFn();
    });
  };

  setupFilterSearch('games-filter', 'games-search', (v) => { gamesFilter = v; }, (v) => { gamesSearchQuery = v; }, renderGamesTable);
  setupFilterSearch('players-filter', 'players-search', (v) => { playersFilter = v; }, (v) => { playersSearchQuery = v; }, renderPlayersTable);
  setupFilterSearch('invites-filter', 'invites-search', (v) => { invitesFilter = v; }, (v) => { invitesSearchQuery = v; }, renderInvitesTable);

  document.getElementById('export-games-btn')?.addEventListener('click', () => exportData('games'));
  document.getElementById('export-players-btn')?.addEventListener('click', () => exportData('users'));
  document.getElementById('export-invites-btn')?.addEventListener('click', () => exportData('invites'));

  ['calc-total-dice', 'calc-face', 'calc-qty'].forEach(id => {
    document.getElementById(id)?.addEventListener('input', updateCalculator);
  });
  updateCalculator();

  document.getElementById('modal-close-btn')?.addEventListener('click', closeModal);
  document.getElementById('inspector-modal')?.addEventListener('click', (e) => {
    if (e.target.id === 'inspector-modal') closeModal();
  });
  window.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeModal(); });

  window.addEventListener('hashchange', () => {
    const hash = window.location.hash.replace('#', '');
    if (hash) switchTab(hash);
  });
  switchTab(window.location.hash.replace('#', '') || 'overview');

  updateClock();
  setInterval(updateClock, 1000);
  updateDashboard();
  setInterval(updateDashboard, 3000);
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initApp);
} else {
  initApp();
}
