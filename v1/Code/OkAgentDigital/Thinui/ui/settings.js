// ═══════════════════════════════════════════════════════════════════════
// GiftWrapper Settings – persisted via localStorage
// Dogfooding: auto-update check, auto-launch, version tracking
// ═══════════════════════════════════════════════════════════════════════

const GiftWrapperSettings = {
    // ── Keys ──
    KEYS: {
        AUTO_LAUNCH: 'gw_autoLaunch',
        AUTO_UPDATE: 'gw_autoUpdate',
        UPDATE_INTERVAL: 'gw_updateInterval',
        LAST_UPDATE_CHECK: 'gw_lastUpdateCheck',
        CURRENT_VERSION: 'gw_currentVersion',
    },

    // ── Defaults ──
    DEFAULTS: {
        AUTO_LAUNCH: false,
        AUTO_UPDATE: true,
        UPDATE_INTERVAL: 86400, // 24 hours
        CURRENT_VERSION: '1.0.0',
    },

    // ── Getters ──
    get autoLaunch() {
        const val = localStorage.getItem(this.KEYS.AUTO_LAUNCH);
        return val !== null ? val === 'true' : this.DEFAULTS.AUTO_LAUNCH;
    },
    set autoLaunch(val) {
        localStorage.setItem(this.KEYS.AUTO_LAUNCH, String(val));
        // Notify Tauri backend to register/unregister login item
        this._notifyTauri('auto_launch', val);
    },

    get autoUpdate() {
        const val = localStorage.getItem(this.KEYS.AUTO_UPDATE);
        return val !== null ? val === 'true' : this.DEFAULTS.AUTO_UPDATE;
    },
    set autoUpdate(val) {
        localStorage.setItem(this.KEYS.AUTO_UPDATE, String(val));
        if (val) this._scheduleNextCheck();
    },

    get updateInterval() {
        const val = parseInt(localStorage.getItem(this.KEYS.UPDATE_INTERVAL));
        return !isNaN(val) ? val : this.DEFAULTS.UPDATE_INTERVAL;
    },
    set updateInterval(val) {
        localStorage.setItem(this.KEYS.UPDATE_INTERVAL, String(val));
        if (this.autoUpdate) this._scheduleNextCheck();
    },

    get lastUpdateCheck() {
        return localStorage.getItem(this.KEYS.LAST_UPDATE_CHECK);
    },
    set lastUpdateCheck(val) {
        localStorage.setItem(this.KEYS.LAST_UPDATE_CHECK, val);
    },

    get currentVersion() {
        return localStorage.getItem(this.KEYS.CURRENT_VERSION) || this.DEFAULTS.CURRENT_VERSION;
    },
    set currentVersion(val) {
        localStorage.setItem(this.KEYS.CURRENT_VERSION, val);
    },

    // ── Version ──
    async getLatestVersion() {
        try {
            const response = await fetch(
                'https://api.github.com/repos/OkAgentDigital/ThinUI/releases/latest',
                {
                    headers: {
                        'Accept': 'application/vnd.github+json',
                        'X-GitHub-Api-Version': '2022-11-28',
                    },
                }
            );
            if (!response.ok) return null;
            const release = await response.json();
            return {
                version: release.tag_name.replace(/^v/, ''),
                url: release.html_url,
                body: release.body || '',
                published: release.published_at,
            };
        } catch (err) {
            console.warn('⚠️ GiftWrapper update check failed:', err.message);
            return null;
        }
    },

    isNewerVersion(latest, current) {
        const l = latest.split('.').map(Number);
        const c = current.split('.').map(Number);
        for (let i = 0; i < Math.max(l.length, c.length); i++) {
            const lv = i < l.length ? l[i] : 0;
            const cv = i < c.length ? c[i] : 0;
            if (lv > cv) return true;
            if (lv < cv) return false;
        }
        return false;
    },

    async checkForUpdates(silent = false) {
        const release = await this.getLatestVersion();
        this.lastUpdateCheck = new Date().toISOString();

        if (!release) {
            if (!silent) console.log('⚠️ Could not check for updates');
            return;
        }

        const current = this.currentVersion;
        if (this.isNewerVersion(release.version, current)) {
            this._showUpdateNotification(release);
        } else if (!silent) {
            console.log(`✅ GiftWrapper is up to date (${current})`);
        }
    },

    // ── Notification ──
    _showUpdateNotification(release) {
        const current = this.currentVersion;
        const msg = `Version ${release.version} is now available. You are on ${current}.`;
        const body = release.body ? release.body.slice(0, 200) : '';

        // Try Tauri native dialog first
        if (window.__TAURI__ && window.__TAURI__.dialog) {
            window.__TAURI__.dialog
                .ask(`Version ${release.version} available!\n\n${msg}\n\n${body}`, {
                    title: 'GiftWrapper Update Available',
                    kind: 'info',
                    okLabel: 'Download',
                    cancelLabel: 'Later',
                })
                .then((download) => {
                    if (download) {
                        window.__TAURI__.shell.openExternal(release.url);
                    }
                })
                .catch(() => {
                    // Fallback to browser-style
                    this._fallbackNotification(release, msg);
                });
        } else {
            this._fallbackNotification(release, msg);
        }
    },

    _fallbackNotification(release, msg) {
        // Create a notification banner in the UI
        const banner = document.createElement('div');
        banner.className = 'update-banner';
        banner.innerHTML = `
            <div class="update-banner-content">
                <div class="update-banner-icon">📦</div>
                <div class="update-banner-text">
                    <strong>GiftWrapper ${release.version}</strong> available
                    <span class="update-banner-sub">${msg}</span>
                </div>
                <div class="update-banner-actions">
                    <button class="update-banner-btn primary" id="gw-update-download">Download</button>
                    <button class="update-banner-btn" id="gw-update-dismiss">Later</button>
                </div>
            </div>
        `;
        document.body.appendChild(banner);

        document.getElementById('gw-update-download')?.addEventListener('click', () => {
            window.open(release.url, '_blank');
            banner.remove();
        });
        document.getElementById('gw-update-dismiss')?.addEventListener('click', () => {
            banner.remove();
        });

        // Auto-dismiss after 30 seconds
        setTimeout(() => banner.remove(), 30000);
    },

    // ── Scheduling ──
    _scheduleNextCheck() {
        if (this._checkTimer) clearTimeout(this._checkTimer);
        const interval = this.updateInterval;
        this._checkTimer = setTimeout(() => {
            this.checkForUpdates(true);
            this._scheduleNextCheck();
        }, interval * 1000);
    },

    _checkTimer: null,

    startPeriodicChecks() {
        if (this.autoUpdate) {
            // Initial check on startup (silent)
            setTimeout(() => this.checkForUpdates(true), 5000);
            this._scheduleNextCheck();
        }
    },

    stopPeriodicChecks() {
        if (this._checkTimer) {
            clearTimeout(this._checkTimer);
            this._checkTimer = null;
        }
    },

    // ── Tauri IPC ──
    async _notifyTauri(command, value) {
        if (window.__TAURI__ && window.__TAURI__.invoke) {
            try {
                await window.__TAURI__.invoke('set_setting', { key: command, value });
            } catch (err) {
                console.warn('Tauri invoke failed:', err);
            }
        }
    },

    // ── Init ──
    init() {
        // Set version from meta tag or injected value
        const metaVersion = document.querySelector('meta[name="gw-version"]');
        if (metaVersion) {
            this.currentVersion = metaVersion.getAttribute('content');
        }

        // Read settings from Tauri on load
        if (window.__TAURI__) {
            this._loadFromTauri();
        }

        // Start periodic checks
        this.startPeriodicChecks();

        console.log(`🎁 GiftWrapper v${this.currentVersion} initialized`);
    },

    async _loadFromTauri() {
        try {
            // Tauri v2 reads from app config/data dir
            // For now, settings are localStorage-based
            console.log('GiftWrapper: settings from localStorage');
        } catch (err) {
            console.warn('Could not load from Tauri:', err);
        }
    },
};

// ── Init on DOM ready ──
document.addEventListener('DOMContentLoaded', () => {
    GiftWrapperSettings.init();
});
