/*
    LyxGuard v4.0 - Anticheat Panel JavaScript
    Handles all UI interactions, NUI callbacks, and real-time events
*/

// -------------------------------------------------------------------------------
// STATE
// -------------------------------------------------------------------------------

let currentPage = 'dashboard';
let realtimeEvents = [];
let panelConfig = {};
let refreshInterval = null;
let isOpen = false;

// -------------------------------------------------------------------------------
// NUI COMMUNICATION
// -------------------------------------------------------------------------------

function post(action, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(r => r.json()).catch(() => ({}));
}

// Escape HTML
function esc(str) {
    if (!str) return '';
    return String(str).replace(/[&<>"']/g, m => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;'
    }[m]));
}

// Escape para atributos onclick (evita romper las comillas simples)
function escapeAttr(str) {
    return String(str || '').replace(/'/g, "\\'").replace(/"/g, '&quot;');
}

// Format date
function formatDate(dateStr) {
    if (!dateStr) return '-';
    const d = new Date(dateStr);
    return d.toLocaleString('es-ES', {
        day: '2-digit', month: '2-digit', year: 'numeric',
        hour: '2-digit', minute: '2-digit'
    });
}

// Time ago
function timeAgo(dateStr) {
    if (!dateStr) return '-';
    const now = Date.now();
    const then = new Date(dateStr).getTime();
    const diff = Math.floor((now - then) / 1000);

    if (diff < 60) return 'Hace ' + diff + 's';
    if (diff < 3600) return 'Hace ' + Math.floor(diff / 60) + 'm';
    if (diff < 86400) return 'Hace ' + Math.floor(diff / 3600) + 'h';
    return 'Hace ' + Math.floor(diff / 86400) + 'd';
}

// -------------------------------------------------------------------------------
// NUI MESSAGE HANDLER
// -------------------------------------------------------------------------------

window.addEventListener('message', function (e) {
    const data = e.data;

    switch (data.action) {
        case 'open':
            openPanel(data);
            break;
        case 'close':
            closePanel();
            break;
        case 'updateStats':
            updateDashboardStats(data);
            break;
        case 'newEvent':
            handleNewEvent(data.event);
            break;
        case 'detection':
            handleNewEvent({
                type: 'detection',
                player: data.player,
                detectionType: data.detectionType,
                details: data.details,
                time: new Date().toISOString()
            });
            break;
        case 'ban':
            handleNewEvent({
                type: 'ban',
                player: data.player,
                reason: data.reason,
                duration: data.duration,
                time: new Date().toISOString()
            });
            break;
        case 'warning':
            handleNewEvent({
                type: 'warning',
                player: data.player,
                reason: data.reason,
                time: new Date().toISOString()
            });
            break;
        case 'unban':
            handleNewEvent({
                type: 'unban',
                player: data.player,
                unbanBy: data.unbanBy,
                time: new Date().toISOString()
            });
            break;
    }
});

// -------------------------------------------------------------------------------
// PANEL CONTROL
// -------------------------------------------------------------------------------

function openPanel(data) {
    document.getElementById('app').classList.remove('hidden');
    isOpen = true;
    panelConfig = data.config || {};

    // Load initial data
    refreshData();

    // Start auto-refresh
    startAutoRefresh();
}

function closePanel() {
    document.getElementById('app').classList.add('hidden');
    isOpen = false;
    stopAutoRefresh();
    post('close');
}

// ESC key to close
document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && isOpen) {
        closePanel();
    }
});

// -------------------------------------------------------------------------------
// NAVIGATION
// -------------------------------------------------------------------------------

document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', function () {
        const page = this.dataset.page;
        navigateTo(page);
    });
});

function navigateTo(page) {
    currentPage = page;

    // Update nav
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    document.querySelector(`[data-page="${page}"]`).classList.add('active');

    // Update pages
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.getElementById('page-' + page).classList.add('active');

    // Load page data
    switch (page) {
        case 'dashboard': refreshData(); break;
        case 'detections': loadDetections(); break;
        case 'bans': loadBans(); break;
        case 'warnings': loadWarnings(); break;
        case 'suspicious': loadSuspicious(); break;
        case 'realtime': scrollRealtimeToBottom(); break;
    }
}

// -------------------------------------------------------------------------------
// DATA LOADING
// -------------------------------------------------------------------------------

function refreshData() {
    post('getStats').then(data => {
        if (data) updateDashboardStats(data);
    });

    post('getRecentActivity').then(data => {
        if (data && data.events) {
            renderRecentActivity(data.events);
        }
    });
}

function updateDashboardStats(data) {
    if (data.players !== undefined) {
        document.getElementById('statPlayers').textContent = data.players + '/' + (data.maxPlayers || 32);
    }
    if (data.detectionsToday !== undefined) {
        document.getElementById('statDetectionsToday').textContent = data.detectionsToday;
    }
    if (data.bansActive !== undefined) {
        document.getElementById('statBansActive').textContent = data.bansActive;
    }
    if (data.warnings !== undefined) {
        document.getElementById('statWarnings').textContent = data.warnings;
    }
    if (data.suspicious !== undefined) {
        document.getElementById('statSuspicious').textContent = data.suspicious;
    }
    if (data.highRiskPlayers !== undefined) {
        document.getElementById('statHighRisk').textContent = data.highRiskPlayers;
    }
}

function renderRecentActivity(events) {
    const container = document.getElementById('recentActivity');
    if (!events || events.length === 0) {
        container.innerHTML = `
            <div class="activity-item">
                <span class="activity-icon info"><i class="fas fa-info-circle"></i></span>
                <span class="activity-text">Sin actividad reciente</span>
                <span class="activity-time">-</span>
            </div>
        `;
        return;
    }

    container.innerHTML = events.slice(0, 10).map(e => `
        <div class="activity-item">
            <span class="activity-icon ${e.type}"><i class="fas ${getEventIcon(e.type)}"></i></span>
            <span class="activity-text">${esc(formatEventText(e))}</span>
            <span class="activity-time">${timeAgo(e.time || e.detection_date)}</span>
        </div>
    `).join('');
}

function getEventIcon(type) {
    const icons = {
        detection: 'fa-exclamation-triangle',
        ban: 'fa-ban',
        warning: 'fa-exclamation-circle',
        unban: 'fa-unlock',
        suspicious: 'fa-user-secret',
        info: 'fa-info-circle'
    };
    return icons[type] || icons.info;
}

function formatEventText(e) {
    switch (e.type) {
        case 'detection':
            return `${e.player_name || e.player} - ${e.detection_type || e.detectionType}`;
        case 'ban':
            return `Baneado: ${e.player_name || e.player} - ${e.reason}`;
        case 'warning':
            return `Warning: ${e.player_name || e.player} - ${e.reason}`;
        case 'unban':
            return `Desbaneado: ${e.player_name || e.player}`;
        case 'suspicious':
            return `${e.player_name || e.player} - score ${e.score || 0} (${e.level || 'low'}) ${e.lastSignal ? '- ' + e.lastSignal : ''}`;
        default:
            return e.message || e.player_name || 'Evento';
    }
}

function getRiskBadgeClass(level) {
    const safeLevel = String(level || 'low').toLowerCase();
    if (safeLevel === 'critical' || safeLevel === 'severe') return 'badge-danger';
    if (safeLevel === 'high' || safeLevel === 'elevated') return 'badge-warning';
    if (safeLevel === 'observed') return 'badge-info';
    return 'badge-success';
}

// -------------------------------------------------------------------------------
// DETECTIONS
// -------------------------------------------------------------------------------

function loadDetections() {
    const filter = document.getElementById('detectionFilter').value;
    post('getDetections', { filter: filter }).then(data => {
        renderDetectionsTable(data.detections || []);
    });
}

function filterDetections() {
    loadDetections();
}

function renderDetectionsTable(detections) {
    const tbody = document.getElementById('detectionsTableBody');

    if (!detections || detections.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;color:var(--text-muted)">Sin detecciones</td></tr>';
        return;
    }

    tbody.innerHTML = detections.map(d => `
        <tr>
            <td>${formatDate(d.detection_date)}</td>
            <td><strong>${esc(d.player_name)}</strong></td>
            <td><span class="badge badge-danger">${esc(d.detection_type)}</span></td>
            <td>${esc(d.details ? (typeof d.details === 'string' ? d.details : JSON.stringify(d.details).substring(0, 50)) : '-')}</td>
            <td><span class="badge badge-${getPunishmentBadge(d.punishment)}">${esc(d.punishment)}</span></td>
            <td>
                <button class="btn btn-sm btn-danger" data-action="banFromDetection" data-identifier="${escapeAttr(d.identifier)}" data-player-name="${escapeAttr(d.player_name)}">
                    <i class="fas fa-ban"></i>
                </button>
                <button class="btn btn-sm btn-primary" data-action="viewPlayerDetails" data-identifier="${escapeAttr(d.identifier)}">
                    <i class="fas fa-eye"></i>
                </button>
                <button class="btn btn-sm btn-warning" data-action="deleteDetection" data-detection-id="${Number(d.id) || 0}" title="Borrar detección">
                    <i class="fas fa-trash"></i>
                </button>
            </td>
        </tr>
    `).join('');
}

function deleteDetection(detectionId) {
    showConfirm('Borrar Detección', '¿Estás seguro de borrar esta detección?', () => {
        post('clearDetection', { id: detectionId }).then(() => {
            showToast('success', 'Detección #' + detectionId + ' eliminada');
            loadDetections();
        });
    }, { icon: 'trash-alt', buttonText: 'Borrar', buttonIcon: 'trash-alt', buttonType: 'warning' });
}

function getPunishmentBadge(punishment) {
    const badges = {
        'ban': 'danger',
        'kick': 'warning',
        'warn': 'warning',
        'notify': 'info',
        'teleport': 'info'
    };
    return badges[punishment] || 'info';
}

// -------------------------------------------------------------------------------
// BANS
// -------------------------------------------------------------------------------

function loadBans() {
    const filter = document.getElementById('banFilter').value;
    post('getBans', { filter: filter }).then(data => {
        renderBansTable(data.bans || []);
    });
}

function renderBansTable(bans) {
    const tbody = document.getElementById('bansTableBody');

    if (!bans || bans.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--text-muted)">Sin bans</td></tr>';
        return;
    }

    tbody.innerHTML = bans.map(b => {
        const isActive = b.active === 1;
        const isPermanent = b.permanent === 1;
        return `
            <tr>
                <td>${formatDate(b.ban_date)}</td>
                <td><strong>${esc(b.player_name)}</strong></td>
                <td>${esc(b.reason)}</td>
                <td>${isPermanent ? '<span class="badge badge-danger">Permanente</span>' : formatDate(b.unban_date)}</td>
                <td><span class="badge badge-${isActive ? 'danger' : 'success'}">${isActive ? 'Activo' : 'Expirado'}</span></td>
                <td>
                    ${isActive ? `<button class="btn btn-sm btn-success" data-action="unbanPlayer" data-ban-id="${Number(b.id) || 0}"><i class="fas fa-unlock"></i></button>` : ''}
                    <button class="btn btn-sm btn-primary" data-action="viewPlayerDetails" data-identifier="${escapeAttr(b.identifier)}"><i class="fas fa-eye"></i></button>
                </td>
            </tr>
        `;
    }).join('');
}

// -------------------------------------------------------------------------------
// WARNINGS
// -------------------------------------------------------------------------------

function loadWarnings() {
    post('getWarnings').then(data => {
        renderWarningsTable(data.warnings || []);
    });
}

function renderWarningsTable(warnings) {
    const tbody = document.getElementById('warningsTableBody');

    if (!warnings || warnings.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--text-muted)">Sin warnings</td></tr>';
        return;
    }

    tbody.innerHTML = warnings.map(w => `
        <tr>
            <td>${formatDate(w.warn_date)}</td>
            <td><strong>${esc(w.player_name)}</strong></td>
            <td>${esc(w.reason)}</td>
            <td>${esc(w.warned_by || 'Sistema')}</td>
            <td>${w.expires_at ? formatDate(w.expires_at) : '<span class="badge badge-info">Sin expiración</span>'}</td>
            <td>
                <button class="btn btn-sm btn-danger" data-action="removeWarning" data-warning-id="${Number(w.id) || 0}"><i class="fas fa-trash"></i></button>
            </td>
        </tr>
    `).join('');
}

function removeWarning(warningId) {
    showConfirm('Eliminar Warning', '¿Estás seguro de eliminar este warning?', () => {
        post('removeWarning', { warningId: warningId }).then(() => {
            showToast('success', 'Warning eliminado');
            loadWarnings();
        });
    }, { icon: 'trash-alt', buttonText: 'Eliminar', buttonIcon: 'trash-alt', buttonType: 'danger' });
}

// -------------------------------------------------------------------------------
// SUSPICIOUS PLAYERS
// -------------------------------------------------------------------------------

function loadSuspicious() {
    post('getSuspicious').then(data => {
        renderSuspiciousGrid(data.players || []);
    });
}

function renderSuspiciousGrid(players) {
    const grid = document.getElementById('suspiciousGrid');

    if (!players || players.length === 0) {
        grid.innerHTML = '<div style="text-align:center;color:var(--text-muted);padding:50px;">Sin jugadores sospechosos</div>';
        return;
    }

    grid.innerHTML = players.map(p => `
        <div class="suspicious-card">
            <div class="player-name">${esc(p.player_name)}</div>
            <div class="player-stats">
                <span class="stat"><i class="fas fa-exclamation-triangle"></i> ${p.detection_count || 0} detecciones</span>
                <span class="stat"><i class="fas fa-exclamation-circle"></i> ${p.warning_count || 0} warnings</span>
                <span class="stat"><i class="fas fa-chart-line"></i> score ${p.risk_score || 0}</span>
                <span class="badge ${getRiskBadgeClass(p.risk_level)}">${esc(p.risk_level || 'low')}</span>
            </div>
            ${p.last_signal ? `<div class="player-stats"><span class="stat"><i class="fas fa-wave-square"></i> ${esc(p.last_signal)}</span></div>` : ''}
            <div style="display:flex;gap:10px;">
                <button class="btn btn-sm btn-danger" data-action="banFromSuspicious" data-identifier="${escapeAttr(p.identifier)}" data-player-name="${escapeAttr(p.player_name)}">
                    <i class="fas fa-ban"></i> Banear
                </button>
                <button class="btn btn-sm btn-primary" data-action="viewPlayerDetails" data-identifier="${escapeAttr(p.identifier)}">
                    <i class="fas fa-eye"></i> Detalles
                </button>
            </div>
        </div>
    `).join('');
}

// -------------------------------------------------------------------------------
// REAL-TIME EVENTS
// -------------------------------------------------------------------------------

function handleNewEvent(event) {
    // Add to realtime events
    realtimeEvents.unshift(event);
    if (realtimeEvents.length > 100) realtimeEvents.pop();

    // Update realtime feed if on that page
    if (currentPage === 'realtime') {
        addRealtimeEventToFeed(event);
    }

    // Show toast notification
    showEventToast(event);

    // Update dashboard if on dashboard
    if (currentPage === 'dashboard') {
        refreshData();
    }

    // Play sound if enabled
    if (panelConfig.soundEnabled) {
        playNotificationSound(event.type);
    }
}

function addRealtimeEventToFeed(event) {
    const feed = document.getElementById('realtimeFeed');
    const firstItem = feed.querySelector('.realtime-item');

    // Remove "waiting" message
    if (firstItem && firstItem.textContent.includes('Esperando')) {
        firstItem.remove();
    }

    const eventHtml = `
        <div class="realtime-item ${event.type}">
            <span class="realtime-icon"><i class="fas ${getEventIcon(event.type)}"></i></span>
            <span class="realtime-text">${esc(formatEventText(event))}</span>
            <span class="realtime-time">${timeAgo(event.time)}</span>
        </div>
    `;

    feed.insertAdjacentHTML('afterbegin', eventHtml);

    // Limit items
    const items = feed.querySelectorAll('.realtime-item');
    if (items.length > 50) {
        items[items.length - 1].remove();
    }
}

function scrollRealtimeToBottom() {
    const feed = document.getElementById('realtimeFeed');
    feed.scrollTop = 0; // Newest at top
}

// -------------------------------------------------------------------------------
// TOASTS & NOTIFICATIONS
// -------------------------------------------------------------------------------

function showToast(type, message, title = '') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <span class="toast-icon"><i class="fas ${getEventIcon(type)}"></i></span>
        <div class="toast-content">
            ${title ? `<div class="toast-title">${esc(title)}</div>` : ''}
            <div class="toast-message">${esc(message)}</div>
        </div>
    `;
    container.appendChild(toast);

    setTimeout(() => toast.remove(), 5000);
}

function showEventToast(event) {
    const titles = {
        detection: 'Deteccion',
        ban: 'Ban',
        warning: 'Warning',
        unban: 'Unban',
        suspicious: 'Sospechoso'
    };

    showToast(event.type, formatEventText(event), titles[event.type] || 'Evento');
}

function playNotificationSound(type) {
    // Sound would be played here if audio file is available
    console.log('Sound:', type);
}

// -------------------------------------------------------------------------------
// PLAYER ACTIONS
// -------------------------------------------------------------------------------

function viewPlayerDetails(identifier) {
    post('getPlayerDetails', { identifier: identifier }).then(data => {
        if (data) {
            showPlayerModal(data);
        }
    });
}

function showPlayerModal(player) {
    const modal = document.getElementById('playerModal');
    const title = document.getElementById('playerModalTitle');
    const body = document.getElementById('playerModalBody');

    title.textContent = player.name || 'Detalles del Jugador';

    body.innerHTML = `
        <div class="player-detail-grid">
            <div class="detail-item"><label>Nombre:</label><span>${esc(player.name)}</span></div>
            <div class="detail-item"><label>Identifier:</label><span>${esc(player.identifier)}</span></div>
            <div class="detail-item"><label>Steam:</label><span>${esc(player.steam || 'N/A')}</span></div>
            <div class="detail-item"><label>Discord:</label><span>${esc(player.discord || 'N/A')}</span></div>
            <div class="detail-item"><label>License:</label><span>${esc(player.license || 'N/A')}</span></div>
            <div class="detail-item"><label>Risk Score:</label><span>${player.riskScore || 0}</span></div>
            <div class="detail-item"><label>Nivel:</label><span class="badge ${getRiskBadgeClass(player.riskLevel)}">${esc(player.riskLevel || 'low')}</span></div>
        </div>
        <hr style="margin:20px 0;border-color:var(--border-color);">
        <h4>Estadísticas</h4>
        <div class="player-stats-grid" style="display:flex;gap:15px;margin-top:15px;">
            <div class="stat" style="background:var(--bg-tertiary);padding:15px;border-radius:10px;flex:1;">
                <div style="font-size:1.5rem;font-weight:700;">${player.detections || 0}</div>
                <div style="color:var(--text-muted);font-size:0.85rem;">Detecciones</div>
            </div>
            <div class="stat" style="background:var(--bg-tertiary);padding:15px;border-radius:10px;flex:1;">
                <div style="font-size:1.5rem;font-weight:700;">${player.warnings || 0}</div>
                <div style="color:var(--text-muted);font-size:0.85rem;">Warnings</div>
            </div>
            <div class="stat" style="background:var(--bg-tertiary);padding:15px;border-radius:10px;flex:1;">
                <div style="font-size:1.5rem;font-weight:700;">${player.bans || 0}</div>
                <div style="color:var(--text-muted);font-size:0.85rem;">Bans</div>
            </div>
        </div>
        ${player.lastRiskSignal ? `<div style="margin-top:15px;color:var(--text-muted);">Última señal: ${esc(player.lastRiskSignal)}</div>` : ''}
        <div style="margin-top:20px;display:flex;gap:10px;">
            <button class="btn btn-danger" data-action="banFromModal" data-identifier="${escapeAttr(player.identifier)}" data-player-name="${escapeAttr(player.name)}">
                <i class="fas fa-ban"></i> Banear
            </button>
            <button class="btn btn-primary" data-action="closePlayerModal">Cerrar</button>
        </div>
    `;

    modal.classList.remove('hidden');
}

function closePlayerModal() {
    document.getElementById('playerModal').classList.add('hidden');
}

function banFromDetection(identifier, playerName) {
    const reason = prompt('Razón del ban:', 'Detección de Anticheat');
    if (reason) {
        post('banPlayer', { identifier: identifier, reason: reason, playerName: playerName }).then(() => {
            showToast('ban', 'Jugador baneado: ' + playerName);
            loadDetections();
        });
    }
}

function banFromSuspicious(identifier, playerName) {
    banFromDetection(identifier, playerName);
}

function banFromModal(identifier, playerName) {
    banFromDetection(identifier, playerName);
    closePlayerModal();
}

// -------------------------------------------------------------------------------
// SETTINGS
// -------------------------------------------------------------------------------

function saveWebhooks() {
    const webhooks = {
        detections: document.getElementById('webhookDetections').value,
        bans: document.getElementById('webhookBans').value,
        warnings: document.getElementById('webhookWarnings').value,
        alerts: document.getElementById('webhookAlerts').value
    };

    post('saveWebhooks', webhooks).then(() => {
        showToast('success', 'Webhooks guardados');
    });
}

// -------------------------------------------------------------------------------
// AUTO-REFRESH
// -------------------------------------------------------------------------------

function startAutoRefresh() {
    const interval = parseInt(document.getElementById('optRefreshInterval')?.value) || 30;
    stopAutoRefresh();

    refreshInterval = setInterval(() => {
        if (isOpen && document.getElementById('optAutoRefresh')?.checked !== false) {
            refreshData();
        }
    }, interval * 1000);
}

function stopAutoRefresh() {
    if (refreshInterval) {
        clearInterval(refreshInterval);
        refreshInterval = null;
    }
}

// -------------------------------------------------------------------------------
// CUSTOM MODAL SYSTEM
// -------------------------------------------------------------------------------

let confirmCallback = null;
let inputCallback = null;

// Show confirm modal (replaces browser confirm)
function showConfirm(title, message, onConfirm, options = {}) {
    const modal = document.getElementById('confirmModal');
    const titleEl = document.getElementById('confirmModalTitle');
    const messageEl = document.getElementById('confirmModalMessage');
    const inputContainer = document.getElementById('confirmModalInput');
    const inputField = document.getElementById('confirmModalInputField');
    const inputLabel = document.getElementById('confirmModalInputLabel');
    const confirmBtn = document.getElementById('confirmModalBtn');

    titleEl.innerHTML = `<i class="fas fa-${options.icon || 'exclamation-triangle'}"></i> ${title}`;
    messageEl.textContent = message;

    // Handle required input
    if (options.requireInput) {
        inputContainer.classList.remove('hidden');
        inputLabel.textContent = options.inputLabel || 'Escribe el valor:';
        inputField.placeholder = options.inputPlaceholder || '';
        inputField.value = '';
    } else {
        inputContainer.classList.add('hidden');
    }

    // Button style
    confirmBtn.className = `btn btn-${options.buttonType || 'danger'}`;
    confirmBtn.innerHTML = `<i class="fas fa-${options.buttonIcon || 'check'}"></i> ${options.buttonText || 'Confirmar'}`;

    confirmCallback = onConfirm;
    modal.classList.remove('hidden');
}

function closeConfirmModal() {
    document.getElementById('confirmModal').classList.add('hidden');
    confirmCallback = null;
}

function executeConfirmAction() {
    const inputField = document.getElementById('confirmModalInputField');
    const inputContainer = document.getElementById('confirmModalInput');

    if (!inputContainer.classList.contains('hidden')) {
        const value = inputField.value.trim();
        if (confirmCallback) confirmCallback(value);
    } else {
        if (confirmCallback) confirmCallback(true);
    }
    closeConfirmModal();
}

// Show input modal (replaces browser prompt)
function showInput(title, message, onSubmit, options = {}) {
    const modal = document.getElementById('inputModal');
    const titleEl = document.getElementById('inputModalTitle');
    const messageEl = document.getElementById('inputModalMessage');
    const inputField = document.getElementById('inputModalField');

    titleEl.innerHTML = `<i class="fas fa-${options.icon || 'edit'}"></i> ${title}`;
    messageEl.textContent = message;
    inputField.placeholder = options.placeholder || '';
    inputField.value = options.defaultValue || '';

    inputCallback = onSubmit;
    modal.classList.remove('hidden');
    inputField.focus();
}

function closeInputModal() {
    document.getElementById('inputModal').classList.add('hidden');
    inputCallback = null;
}

function executeInputAction() {
    const value = document.getElementById('inputModalField').value.trim();
    if (inputCallback && value) {
        inputCallback(value);
    }
    closeInputModal();
}

// Updated functions to use custom modals
function clearPlayerLogs() {
    const identifier = document.getElementById('clearPlayerIdentifier').value.trim();
    if (!identifier) {
        showToast('error', 'Ingresa un identifier válido');
        return;
    }

    showConfirm('Limpiar Logs', `¿Estás seguro de limpiar todos los logs de:\n${identifier}?`, () => {
        post('clearPlayerLogs', { identifier }).then(() => {
            showToast('success', `Logs limpiados para ${identifier}`);
            document.getElementById('clearPlayerIdentifier').value = '';
            refreshData();
        });
    }, { icon: 'trash-alt', buttonText: 'Limpiar', buttonIcon: 'trash-alt' });
}

function clearOldLogs() {
    const days = parseInt(document.getElementById('clearOldDays').value) || 30;

    showConfirm('Limpiar Logs Antiguos', `¿Limpiar todos los logs de más de ${days} días?`, () => {
        post('clearOldLogs', { days }).then(() => {
            showToast('success', `Logs de más de ${days} días limpiados`);
            refreshData();
        });
    }, { icon: 'calendar-times', buttonText: 'Limpiar', buttonIcon: 'trash-alt' });
}

function clearAllLogsConfirm() {
    showConfirm('ELIMINAR TODOS LOS LOGS', 'Esta accion eliminara TODOS los logs del anticheat.\n\nEscribe "CONFIRMAR" para proceder:', (value) => {
        if (value === 'CONFIRMAR') {
            post('clearAllLogs', {}).then(() => {
                showToast('success', 'Todos los logs han sido eliminados');
                refreshData();
            });
        } else {
            showToast('error', 'Confirmación incorrecta');
        }
    }, {
        icon: 'skull-crossbones',
        requireInput: true,
        inputLabel: 'Escribe CONFIRMAR:',
        inputPlaceholder: 'CONFIRMAR',
        buttonText: 'Eliminar Todo',
        buttonIcon: 'skull-crossbones'
    });
}

function clearPlayerWarnings() {
    const identifier = document.getElementById('clearWarningsIdentifier')?.value.trim();
    if (!identifier) {
        showToast('error', 'Ingresa un identifier válido');
        return;
    }

    showConfirm('Limpiar Advertencias', `¿Limpiar advertencias de ${identifier}?`, () => {
        post('clearPlayerWarnings', { identifier }).then(() => {
            showToast('success', 'Advertencias limpiadas');
            refreshData();
        });
    }, { icon: 'user-times', buttonText: 'Limpiar', buttonIcon: 'trash-alt' });
}

function unbanPlayer(banId) {
    showConfirm('Desbanear Jugador', '¿Estás seguro de desbanear a este jugador?', () => {
        post('unban', { banId: banId }).then(() => {
            showToast('success', 'Jugador desbaneado');
            loadBans();
        });
    }, { icon: 'unlock', buttonType: 'success', buttonText: 'Desbanear', buttonIcon: 'unlock' });
}

// -------------------------------------------------------------------------------
// INIT
// -------------------------------------------------------------------------------

console.log('LyxGuard Anticheat Panel v4.0 loaded');

function playAlertSound() {
    const audio = new Audio('sounds/alert.mp3');
    audio.volume = 0.5;
    audio.play().catch(e => console.log('Audio error (falta archivo sounds/alert.mp3):', e));
}

// -------------------------------------------------------------------------------
// ADMIN CONFIG PAGE FUNCTIONS
// -------------------------------------------------------------------------------

// Tab switching
function switchConfigTab(tabName, buttonEl) {
    // Update tab buttons
    document.querySelectorAll('.config-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    const activeButton = buttonEl || document.querySelector(`.config-tab[data-tab="${tabName}"]`);
    if (activeButton) {
        activeButton.classList.add('active');
    }

    // Update content
    document.querySelectorAll('.config-tab-content').forEach(content => {
        content.classList.remove('active');
    });
    document.getElementById('config-' + tabName).classList.add('active');
}

// Load admin config data
function loadAdminConfig() {
    loadWhitelist();
    loadImmuneGroups();
    loadDetectionSettings();
}

// -------------------------------------------------------------------------------
// WHITELIST MANAGEMENT
// -------------------------------------------------------------------------------

function loadWhitelist() {
    post('getWhitelist').then(data => {
        renderWhitelistList(data.whitelist || []);
    });
}

function renderWhitelistList(whitelist) {
    const container = document.getElementById('whitelistList');

    if (!whitelist || whitelist.length === 0) {
        container.innerHTML = '<div class="loading-placeholder">No hay jugadores en la whitelist</div>';
        return;
    }

    container.innerHTML = whitelist.map(w => `
        <div class="whitelist-item">
            <div class="whitelist-info">
                <span class="whitelist-name">${esc(w.player_name || 'Sin nombre')}</span>
                <span class="whitelist-identifier">${esc(w.identifier)}</span>
            </div>
            <span class="whitelist-level ${w.level || 'full'}">${getLevelLabel(w.level)}</span>
            <button class="btn btn-sm btn-danger" data-action="removeFromWhitelist" data-identifier="${escapeAttr(w.identifier)}" title="Eliminar">
                <i class="fas fa-trash"></i>
            </button>
        </div>
    `).join('');
}

function getLevelLabel(level) {
    const labels = {
        'full': 'Inmune Total',
        'vip': 'VIP',
        'none': 'Normal'
    };
    return labels[level] || labels.full;
}

function addToWhitelist() {
    const identifier = document.getElementById('whitelistIdentifier').value.trim();
    const name = document.getElementById('whitelistName').value.trim();
    const level = document.getElementById('whitelistLevel').value;
    const notes = document.getElementById('whitelistNotes').value.trim();

    if (!identifier) {
        showToast('error', 'Ingresa un identifier válido');
        return;
    }

    post('addToWhitelist', {
        identifier: identifier,
        playerName: name,
        level: level,
        notes: notes
    }).then(response => {
        if (response.success) {
            showToast('success', 'Jugador añadido a whitelist');
            // Clear form
            document.getElementById('whitelistIdentifier').value = '';
            document.getElementById('whitelistName').value = '';
            document.getElementById('whitelistNotes').value = '';
            loadWhitelist();
        } else {
            showToast('error', response.message || 'Error al añadir');
        }
    });
}

function removeFromWhitelist(identifier) {
    showConfirm('Eliminar de Whitelist', `¿Eliminar ${identifier} de la whitelist?`, () => {
        post('removeFromWhitelist', { identifier: identifier }).then(response => {
            if (response.success) {
                showToast('success', 'Eliminado de whitelist');
                loadWhitelist();
            } else {
                showToast('error', response.message || 'Error al eliminar');
            }
        });
    }, { icon: 'user-times', buttonType: 'danger', buttonText: 'Eliminar', buttonIcon: 'trash-alt' });
}

// -------------------------------------------------------------------------------
// IMMUNE GROUPS
// -------------------------------------------------------------------------------

function loadImmuneGroups() {
    post('getImmuneGroups').then(data => {
        const groups = data.groups || [];
        ['superadmin', 'admin', 'mod', 'owner', 'helper'].forEach(group => {
            const checkbox = document.getElementById('group_' + group);
            if (checkbox) {
                checkbox.checked = groups.includes(group);
            }
        });
    });
}

function updateImmuneGroups() {
    // Just for visual feedback, actual save happens on button click
}

function saveImmuneGroups() {
    const groups = [];
    ['superadmin', 'admin', 'mod', 'owner', 'helper'].forEach(group => {
        const checkbox = document.getElementById('group_' + group);
        if (checkbox && checkbox.checked) {
            groups.push(group);
        }
    });

    post('saveImmuneGroups', { groups: groups }).then(response => {
        if (response.success) {
            showToast('success', 'Grupos inmunes guardados');
        } else {
            showToast('error', response.message || 'Error al guardar');
        }
    });
}

// -------------------------------------------------------------------------------
// VIP SETTINGS
// -------------------------------------------------------------------------------

function saveVipSettings() {
    const vipEnabled = document.getElementById('vipEnabled').checked;
    const vipTolerance = parseFloat(document.getElementById('vipTolerance').value) || 2.0;

    const ignoredDetections = [];
    document.querySelectorAll('#vipIgnoredDetections input[type="checkbox"]:checked').forEach(cb => {
        const label = cb.parentElement.textContent.trim();
        ignoredDetections.push(label);
    });

    post('saveVipSettings', {
        enabled: vipEnabled,
        toleranceMultiplier: vipTolerance,
        ignoredDetections: ignoredDetections
    }).then(response => {
        if (response.success) {
            showToast('success', 'Configuración VIP guardada');
        } else {
            showToast('error', response.message || 'Error al guardar');
        }
    });
}

// -------------------------------------------------------------------------------
// DETECTION SETTINGS (UI dinamica v4.4 - cubre TODAS las detecciones)
// -------------------------------------------------------------------------------

// Opciones de castigo que se ofrecen en cada select.
const PUNISHMENT_OPTIONS = [
    { value: 'none', label: 'Ninguno' },
    { value: 'notify', label: 'Notificar' },
    { value: 'screenshot', label: 'Captura' },
    { value: 'warn', label: 'Warn' },
    { value: 'kick', label: 'Kick' },
    { value: 'ban_temp', label: 'Ban Temp' },
    { value: 'ban_perm', label: 'Ban Perm' },
    { value: 'teleport', label: 'Teleport' },
    { value: 'freeze', label: 'Freeze' },
    { value: 'kill', label: 'Matar' }
];

// Etiqueta legible para cada grupo devuelto por el server.
const GROUP_LABELS = {
    Movement: 'Movimiento',
    Combat: 'Combate',
    Ultra: 'Exploits / Ultra',
    Entities: 'Entidades',
    Advanced: 'Avanzado / Inyección',
    Blacklists: 'Listas negras'
};

const GROUP_ICONS = {
    Movement: 'fa-running',
    Combat: 'fa-crosshairs',
    Ultra: 'fa-bolt',
    Entities: 'fa-car',
    Advanced: 'fa-syringe',
    Blacklists: 'fa-ban'
};

// Estado en memoria de las detecciones cargadas (lista plana).
let DetectionState = [];

function _punishmentSelectHTML(name, selected) {
    const opts = PUNISHMENT_OPTIONS.map(o =>
        `<option value="${o.value}"${o.value === selected ? ' selected' : ''}>${o.label}</option>`
    ).join('');
    return `<select class="punishment-select" id="pun_${esc(name)}" title="Castigo">${opts}</select>`;
}

function renderDetections() {
    const container = document.getElementById('detectionsContainer');
    if (!container) return;

    if (!DetectionState.length) {
        container.innerHTML = '<div class="detection-loading">No hay detecciones para mostrar.</div>';
        return;
    }

    // Agrupar por grupo respetando el orden de GROUP_LABELS.
    const groups = {};
    DetectionState.forEach(det => {
        (groups[det.group] = groups[det.group] || []).push(det);
    });

    const order = Object.keys(GROUP_LABELS).filter(g => groups[g]);
    // Cualquier grupo no listado va al final.
    Object.keys(groups).forEach(g => { if (!order.includes(g)) order.push(g); });

    let html = '';
    order.forEach(group => {
        const items = groups[group].slice().sort((a, b) => a.label.localeCompare(b.label));
        const icon = GROUP_ICONS[group] || 'fa-shield-alt';
        const title = GROUP_LABELS[group] || group;
        html += `<div class="settings-card detection-category" data-group="${esc(group)}">
            <h3><i class="fas ${icon}"></i> ${esc(title)} <span class="cat-count">${items.length}</span></h3>
            <div class="detection-list">`;
        items.forEach(det => {
            html += `<div class="detection-item" data-detection="${esc(det.name)}" data-search="${esc((det.label + ' ' + det.name).toLowerCase())}">
                <div class="detection-header">
                    <label class="toggle-switch">
                        <input type="checkbox" id="det_${esc(det.name)}"${det.enabled ? ' checked' : ''}>
                        <span class="slider"></span>
                    </label>
                    <span class="detection-name">${esc(det.label)}</span>
                </div>
                ${_punishmentSelectHTML(det.name, det.punishment)}
            </div>`;
        });
        html += `</div></div>`;
    });

    container.innerHTML = html;
    updateDetectionCount();
}

function updateDetectionCount() {
    const el = document.getElementById('detectionCount');
    if (!el) return;
    let enabled = 0;
    DetectionState.forEach(d => {
        const cb = document.getElementById('det_' + d.name);
        if (cb && cb.checked) enabled++;
    });
    el.textContent = `${enabled}/${DetectionState.length} activas`;
}

function loadDetectionSettings() {
    post('getAllDetections').then(data => {
        DetectionState = Array.isArray(data.detections) ? data.detections : [];
        // Reflejar el preset activo en el selector, si viene.
        if (data.preset) {
            const sel = document.getElementById('presetSelect');
            if (sel) sel.value = data.preset;
        }
        renderDetections();
    });
}

function saveDetectionSettings() {
    const detections = {};
    DetectionState.forEach(det => {
        const cb = document.getElementById('det_' + det.name);
        const pun = document.getElementById('pun_' + det.name);
        if (cb) {
            detections[det.name] = {
                enabled: cb.checked,
                punishment: pun ? pun.value : (det.punishment || 'notify')
            };
        }
    });

    const presetSel = document.getElementById('presetSelect');
    post('saveDetectionSettings', {
        detections: detections,
        preset: presetSel ? presetSel.value : undefined
    }).then(response => {
        if (response.success) {
            showToast('success', 'Configuración de detecciones guardada');
            // Sincronizar estado local con lo guardado.
            DetectionState.forEach(det => {
                if (detections[det.name]) {
                    det.enabled = detections[det.name].enabled;
                    det.punishment = detections[det.name].punishment;
                }
            });
            updateDetectionCount();
        } else {
            showToast('error', response.message || 'Error al guardar');
        }
    });
}

// Aplica un preset del servidor a todos los selects visibles (sin guardar aún).
function applyPreset() {
    const presetSel = document.getElementById('presetSelect');
    if (!presetSel) return;
    const preset = presetSel.value;

    if (preset === 'custom') {
        showToast('info', 'Modo personalizado: ajustá cada castigo a mano y guardá.');
        return;
    }

    post('getPresetPunishments', { preset: preset }).then(data => {
        if (!data || !data.punishments) {
            showToast('error', 'No se pudo obtener el preset');
            return;
        }
        DetectionState.forEach(det => {
            const p = data.punishments[det.name];
            if (p && p.punishment) {
                const punSel = document.getElementById('pun_' + det.name);
                if (punSel) punSel.value = p.punishment;
            }
        });
        showToast('success', `Preset "${preset}" aplicado. Revisá y guardá para confirmar.`);
    });
}

function filterDetectionList() {
    const input = document.getElementById('detectionSearch');
    if (!input) return;
    const q = input.value.trim().toLowerCase();
    document.querySelectorAll('#detectionsContainer .detection-item').forEach(item => {
        const hay = item.dataset.search || '';
        item.style.display = (!q || hay.includes(q)) ? '' : 'none';
    });
    // Ocultar categorías que quedaron vacías.
    document.querySelectorAll('#detectionsContainer .detection-category').forEach(cat => {
        const anyVisible = Array.from(cat.querySelectorAll('.detection-item'))
            .some(i => i.style.display !== 'none');
        cat.style.display = anyVisible ? '' : 'none';
    });
}

function resetDetectionDefaults() {
    showConfirm('Restaurar Valores', '¿Restaurar todas las detecciones a los valores del preset por defecto?', () => {
        post('resetDetectionDefaults').then(response => {
            if (response.success) {
                showToast('success', 'Valores restaurados');
                loadDetectionSettings();
            } else {
                showToast('error', response.message || 'Error al restaurar');
            }
        });
    }, { icon: 'undo', buttonType: 'warning', buttonText: 'Restaurar', buttonIcon: 'undo' });
}

// Extend navigateTo function for adminconfig
const originalNavigateTo = navigateTo;
navigateTo = function(page) {
    currentPage = page;

    // Update nav
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    const navItem = document.querySelector(`[data-page="${page}"]`);
    if (navItem) navItem.classList.add('active');

    // Update pages
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    const pageEl = document.getElementById('page-' + page);
    if (pageEl) pageEl.classList.add('active');

    // Load page data
    switch (page) {
        case 'dashboard': refreshData(); break;
        case 'detections': loadDetections(); break;
        case 'bans': loadBans(); break;
        case 'warnings': loadWarnings(); break;
        case 'suspicious': loadSuspicious(); break;
        case 'realtime': scrollRealtimeToBottom(); break;
        case 'adminconfig': loadAdminConfig(); break;
    }
};

const UiActionHandlers = {
    closePanel: () => closePanel(),
    refreshData: () => refreshData(),
    loadDetections: () => loadDetections(),
    loadBans: () => loadBans(),
    loadWarnings: () => loadWarnings(),
    loadSuspicious: () => loadSuspicious(),
    loadAdminConfig: () => loadAdminConfig(),
    switchConfigTab: (el) => switchConfigTab(el.dataset.tab, el),
    addToWhitelist: () => addToWhitelist(),
    saveImmuneGroups: () => saveImmuneGroups(),
    saveVipSettings: () => saveVipSettings(),
    saveDetectionSettings: () => saveDetectionSettings(),
    resetDetectionDefaults: () => resetDetectionDefaults(),
    applyPreset: () => applyPreset(),
    saveWebhooks: () => saveWebhooks(),
    clearPlayerLogs: () => clearPlayerLogs(),
    clearOldLogs: () => clearOldLogs(),
    clearAllLogsConfirm: () => clearAllLogsConfirm(),
    closePlayerModal: () => closePlayerModal(),
    closeConfirmModal: () => closeConfirmModal(),
    executeConfirmAction: () => executeConfirmAction(),
    closeInputModal: () => closeInputModal(),
    executeInputAction: () => executeInputAction(),
    banFromDetection: (el) => banFromDetection(el.dataset.identifier || '', el.dataset.playerName || ''),
    viewPlayerDetails: (el) => viewPlayerDetails(el.dataset.identifier || ''),
    deleteDetection: (el) => deleteDetection(Number(el.dataset.detectionId) || 0),
    unbanPlayer: (el) => unbanPlayer(Number(el.dataset.banId) || 0),
    removeWarning: (el) => removeWarning(Number(el.dataset.warningId) || 0),
    banFromSuspicious: (el) => banFromSuspicious(el.dataset.identifier || '', el.dataset.playerName || ''),
    banFromModal: (el) => banFromModal(el.dataset.identifier || '', el.dataset.playerName || ''),
    removeFromWhitelist: (el) => removeFromWhitelist(el.dataset.identifier || '')
};

const UiChangeHandlers = {
    filterDetections: () => filterDetections(),
    updateImmuneGroups: () => updateImmuneGroups()
};

document.addEventListener('click', function(e) {
    const actionEl = e.target.closest('[data-action]');
    if (!actionEl) return;

    const action = actionEl.dataset.action;
    const handler = UiActionHandlers[action];
    if (typeof handler !== 'function') return;

    e.preventDefault();
    handler(actionEl, e);
});

document.addEventListener('change', function(e) {
    const changeEl = e.target.closest('[data-change]');
    if (!changeEl) return;

    const action = changeEl.dataset.change;
    const handler = UiChangeHandlers[action];
    if (typeof handler !== 'function') return;

    handler(changeEl, e);
});

// Buscador en vivo de detecciones (UI dinamica v4.4).
document.addEventListener('input', function(e) {
    if (e.target && e.target.id === 'detectionSearch') {
        filterDetectionList();
    }
});

// Mantener el contador "activas" al togglear una detección.
document.addEventListener('change', function(e) {
    if (e.target && e.target.id && e.target.id.indexOf('det_') === 0) {
        if (typeof updateDetectionCount === 'function') updateDetectionCount();
    }
});
