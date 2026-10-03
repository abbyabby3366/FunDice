// Tab switching
function switchTab(tabId) {
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  document.querySelectorAll('main > section').forEach(s => s.classList.add('hidden'));
  const targetBtn = Array.from(document.querySelectorAll('.tab-btn')).find(b => b.getAttribute('onclick')?.includes(tabId));
  if (targetBtn) targetBtn.classList.add('active');
  const targetSection = document.getElementById('tab-' + tabId);
  if (targetSection) targetSection.classList.remove('hidden');
}

// Date & Time formatting adhering strictly to DD-MM-YY and GMT+8 (Malaysia Time)
function formatGmt8(isoOrMs) {
  if (!isoOrMs) return { primary: '—', secondary: '' };
  const d = new Date(isoOrMs);
  if (isNaN(d.getTime())) return { primary: '—', secondary: '' };

  const formatter = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Kuala_Lumpur',
    day: '2-digit',
    month: '2-digit',
    year: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
  const parts = formatter.formatToParts(d);
  const getP = (type) => parts.find(p => p.type === type)?.value || '';

  const dateStr = `${getP('day')}-${getP('month')}-${getP('year')}`; // DD-MM-YY
  const timeStr = `${getP('hour')}:${getP('minute')}:${getP('second')} (GMT+8)`;
  return { primary: timeStr, secondary: dateStr };
}

function renderDateTimeCell(isoOrMs) {
  const { primary, secondary } = formatGmt8(isoOrMs);
  if (primary === '—') return '<span>—</span>';
  return `<div class="datetime-cell">
    <span class="dt-primary">${primary}</span>
    <span class="dt-secondary">${secondary}</span>
  </div>`;
}

function renderDice(diceArr) {
  if (!Array.isArray(diceArr) || diceArr.length === 0) return '—';
  return `<div class="dice-group">${diceArr.map(d => `<span class="die-face">${d}</span>`).join('')}</div>`;
}

function formatUptime(seconds) {
  const s = Math.floor(seconds % 60);
  const m = Math.floor((seconds / 60) % 60);
  const h = Math.floor(seconds / 3600);
  if (h > 0) return `${h}h ${m}m ${s}s`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

// Auto-fetch loop
async function updateDashboard() {
  const errorBanner = document.getElementById('error-banner');
  const errorMsg = document.getElementById('error-message');

  try {
    const res = await fetch('/api/admin/status');
    if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    const data = await res.json();
    errorBanner.classList.add('hidden');

    // Metrics
    document.getElementById('metric-online').textContent = data.metrics.onlineUsers;
    document.getElementById('metric-total-users').textContent = `${data.metrics.totalUsers} registered in memory`;
    document.getElementById('metric-games').textContent = data.metrics.activeGames;
    document.getElementById('metric-invites').textContent = data.metrics.pendingInvites;
    document.getElementById('metric-uptime').textContent = formatUptime(data.server.uptime);
    document.getElementById('metric-env').textContent = `${data.config.nodeEnv} • ${data.server.nodeVersion}`;

    // System
    document.getElementById('sys-node').textContent = data.server.nodeVersion;
    document.getElementById('sys-heap').textContent = `${data.server.memory.heapUsedMB} MB / ${data.server.memory.heapTotalMB} MB`;
    document.getElementById('sys-env').textContent = data.config.nodeEnv;
    document.getElementById('sys-port').textContent = data.config.port;
    if (data.database && document.getElementById('sys-db')) {
      const isConnected = data.database.status === 'connected';
      const badge = isConnected
        ? '<span class="badge badge-online">Connected</span>'
        : `<span class="badge badge-offline">${data.database.status || 'disconnected'}</span>`;
      const counts = isConnected
        ? ` <span style="color:var(--text-dim); font-size:12px;">(${data.database.usersCount || 0} users, ${data.database.rollsCount || 0} rolls, ${data.database.gamesCount || 0} games)</span>`
        : '';
      document.getElementById('sys-db').innerHTML = `${badge}${counts}`;
    }
    const sTime = formatGmt8(data.server.serverTime);
    document.getElementById('sys-time').textContent = `${sTime.secondary} ${sTime.primary}`;

    // Games Table
    const gamesTbody = document.getElementById('games-tbody');
    if (data.games.length === 0) {
      gamesTbody.innerHTML = '<tr><td colspan="7" style="text-align: center; color: var(--text-dim);">No active or recent games.</td></tr>';
    } else {
      gamesTbody.innerHTML = data.games.map(g => {
        const statusBadge = g.status === 'playing' ? '<span class="badge badge-playing">Playing</span>' : '<span class="badge badge-finished">Finished</span>';
        const playersStr = g.players.map(p => `${p.name} (${p.diceCount}🎲)`).join(' vs ');
        const bidStr = g.currentBid ? `${g.currentBid.quantity} &times; [${g.currentBid.face}] by ${g.currentBid.by}` : (g.status === 'playing' ? 'Awaiting bid' : '—');
        const turnStr = g.status === 'playing' ? `Turn: <strong>${g.turnPlayer}</strong><br><small style="color:var(--text-dim)">${bidStr}</small>` : '—';
        const winStr = g.winner ? `🏆 <strong>${g.winner}</strong><br><small style="color:var(--text-dim)">${g.endReason || ''}</small>` : 'In progress';
        return `<tr>
          <td><code>${g.id.slice(0, 16)}...</code></td>
          <td>${statusBadge}</td>
          <td>Round ${g.round}</td>
          <td>${playersStr}</td>
          <td>${turnStr}</td>
          <td>${winStr}</td>
          <td>${renderDateTimeCell(g.createdAt)}</td>
        </tr>`;
      }).join('');
    }

    // Players Table
    const playersTbody = document.getElementById('players-tbody');
    if (data.users.length === 0) {
      playersTbody.innerHTML = '<tr><td colspan="7" style="text-align: center; color: var(--text-dim);">No players connected.</td></tr>';
    } else {
      playersTbody.innerHTML = data.users.map(u => {
        const statusBadge = u.isOnline ? '<span class="badge badge-online">Online</span>' : '<span class="badge badge-offline">Offline</span>';
        return `<tr>
          <td><code>${u.id.slice(0, 16)}...</code></td>
          <td><strong>${u.name}</strong></td>
          <td>${statusBadge}</td>
          <td><code>${u.socketCount}</code></td>
          <td>${u.rollCount}</td>
          <td>${renderDateTimeCell(u.lastSeenAt)}</td>
          <td>${renderDateTimeCell(u.createdAt)}</td>
        </tr>`;
      }).join('');
    }

    // Rolls Table
    const rollsTbody = document.getElementById('rolls-tbody');
    if (data.recentRolls.length === 0) {
      rollsTbody.innerHTML = '<tr><td colspan="4" style="text-align: center; color: var(--text-dim);">No rolls recorded yet.</td></tr>';
    } else {
      rollsTbody.innerHTML = data.recentRolls.map(r => `<tr>
        <td><code>#${r.seq}</code></td>
        <td><strong>${r.userName}</strong></td>
        <td>${renderDice(r.dice)}</td>
        <td>${renderDateTimeCell(r.at)}</td>
      </tr>`).join('');
    }

    // Invites Table
    const invitesTbody = document.getElementById('invites-tbody');
    if (data.invites.length === 0) {
      invitesTbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--text-dim);">No invitations active.</td></tr>';
    } else {
      invitesTbody.innerHTML = data.invites.map(i => {
        const badgeClass = `badge-${i.status}`;
        return `<tr>
          <td><code>${i.id.slice(0, 16)}...</code></td>
          <td><strong>${i.from.name}</strong></td>
          <td><strong>${i.to.name}</strong></td>
          <td><span class="badge ${badgeClass}">${i.status}</span></td>
          <td>${renderDateTimeCell(i.createdAt)}</td>
          <td>${renderDateTimeCell(i.expiresAt)}</td>
        </tr>`;
      }).join('');
    }

    // Configuration
    const configGrid = document.getElementById('config-grid');
    configGrid.innerHTML = `
      <div class="config-row"><span class="config-key">Dice Per Player</span><span class="config-val">${data.config.diceCount} dice</span></div>
      <div class="config-row"><span class="config-key">Roll History Kept</span><span class="config-val">${data.config.rollHistory} rolls</span></div>
      <div class="config-row"><span class="config-key">Peeks Allowed Per Game</span><span class="config-val">${data.config.peeksPerGame} peeks</span></div>
      <div class="config-row"><span class="config-key">Peek Caught Probability</span><span class="config-val">${Math.round(data.config.peekCaughtChance * 100)}%</span></div>
      <div class="config-row"><span class="config-key">Invite TTL</span><span class="config-val">${data.config.inviteTtlSec}s</span></div>
      <div class="config-row"><span class="config-key">Disconnect Grace Period</span><span class="config-val">${data.config.disconnectGraceSec}s</span></div>
      <div class="config-row"><span class="config-key">Session Token Expiry</span><span class="config-val">${data.config.tokenTtlDays} days</span></div>
      <div class="config-row"><span class="config-key">Rematch Window</span><span class="config-val">${data.config.rematchWindowMin} mins</span></div>
      <div class="config-row"><span class="config-key">User Idle Sweep</span><span class="config-val">${data.config.userIdleTtlHours} hours</span></div>
      <div class="config-row"><span class="config-key">WebSocket Ping Interval</span><span class="config-val">${data.config.pingIntervalSec}s</span></div>
      <div class="config-row"><span class="config-key">Max Sockets Per User</span><span class="config-val">${data.config.maxSocketsPerUser}</span></div>
      <div class="config-row"><span class="config-key">JWT Secret Configured</span><span class="badge ${data.config.jwtSecretConfigured ? 'badge-online' : 'badge-pending'}">${data.config.jwtSecretConfigured ? 'Secure / Set' : 'Auto-generated'}</span></div>
    `;

  } catch (err) {
    errorBanner.classList.remove('hidden');
    errorMsg.textContent = `Connection lost or server unreachable: ${err.message}. Retrying automatically...`;
  }
}

// Initial fetch on mount & automatic polling every 3 seconds (No manual refresh button needed)
updateDashboard();
setInterval(updateDashboard, 3000);
