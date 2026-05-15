const { app, BrowserWindow, Tray, Menu, nativeImage, ipcMain } = require('electron');


const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

let mainWindow = null;      // Output window
let tray = null;            // Menu bar icon

const APP_ICON_PATH = path.join(__dirname, "app-icon.png");
const TRAY_ICON_PATH = path.join(__dirname, "snack_tray-icon.png");
const SETTINGS_PATH = path.join(app.getPath('userData'), 'settings.json');


// ========== SETTINGS PERSISTENCE ==========
function loadSettings() {
  try {
    if (fs.existsSync(SETTINGS_PATH)) {
      const data = fs.readFileSync(SETTINGS_PATH, 'utf-8');
      return JSON.parse(data);
    }
  } catch (e) {
    console.error('Failed to load settings:', e);
  }
  return {};
}

function saveSettings(settings) {
  try {
    const dir = path.dirname(SETTINGS_PATH);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2), 'utf-8');
  } catch (e) {
    console.error('Failed to save settings:', e);
  }
}


// ========== SINGLE INSTANCE LOCK ==========
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.show();
      mainWindow.focus();
    }
  });
}

// ========== 1. CREATE OUTPUT WINDOW (on startup) ==========
function createOutputWindow() {
  mainWindow = new BrowserWindow({
    width: 900,
    height: 680,
    minWidth: 700,
    minHeight: 500,
    show: true,
    titleBarStyle: 'hiddenInset',
    frame: true,
    trafficLightPosition: { x: 12, y: 12 },

    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    },
    title: 'Snackbar',
    icon: APP_ICON_PATH
  });
  mainWindow.loadFile('output.html');

  mainWindow.on('closed', () => { mainWindow = null; });
}

// ========== 2. CREATE MENU BAR ICON (white on transparent PNG) ==========
function createTray() {
  const iconPath = TRAY_ICON_PATH;
  let icon;
  try {
    icon = nativeImage.createFromPath(iconPath);
    icon = icon.resize({ width: 16, height: 16 });
  } catch (e) {
    icon = nativeImage.createEmpty();
  }
  tray = new Tray(icon);
  tray.setToolTip('Snackbar');
  updateTrayMenu();
}

function updateTrayMenu() {
  const contextMenu = Menu.buildFromTemplate([
    { label: 'Reminders (3)', click: () => { if (mainWindow) { mainWindow.show(); mainWindow.focus(); } } },
    { label: 'Mail VIP (2)', click: () => { if (mainWindow) { mainWindow.show(); mainWindow.focus(); } } },
    { label: 'Contacts', click: () => exec('open -b com.apple.Contacts') },
    { label: 'Notes', click: () => exec('open -b com.apple.Notes') },
    { label: 'Calendar', click: () => exec('open -b com.apple.iCal') },
    { label: 'Permissions', click: () => exec('open x-apple.systempreferences:com.apple.preference.security?Privacy_Automation') },
    { type: 'separator' },
    { label: 'Settings...', click: () => { if (mainWindow) { mainWindow.show(); mainWindow.focus(); } else createOutputWindow(); } },
    { label: 'Quit', click: () => app.quit() }
  ]);
  tray.setContextMenu(contextMenu);
}


// ========== 3. IPC HANDLERS ==========
ipcMain.on('log-message', (event, msg) => {

  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('log', msg);
  }
});

ipcMain.on('window-close', () => {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.close();
  }
});

ipcMain.on('set-launch-on-startup', (event, enabled) => {
  app.setLoginItemSettings({
    openAtLogin: enabled,
    openAsHidden: true,
    path: app.getPath('exe')
  });
  // Persist the setting
  const settings = loadSettings();
  settings.launchOnStartup = enabled;
  saveSettings(settings);
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('log', `Launch on startup ${enabled ? 'enabled' : 'disabled'}`);
  }
});

ipcMain.on('save-settings', (event, settings) => {
  const current = loadSettings();
  Object.assign(current, settings);
  saveSettings(current);
});

ipcMain.handle('load-settings', () => {
  return loadSettings();
});

ipcMain.handle('update-from-git', async () => {
  return new Promise((resolve) => {
    const repoPath = __dirname;
    // Stash any local changes, pull, then pop stash
    exec('git stash push -m "snackbar-auto-stash" 2>/dev/null; git pull 2>&1; git stash pop 2>/dev/null', { cwd: repoPath, maxBuffer: 1024 * 1024 }, (error, stdout, stderr) => {
      if (error) {
        resolve({ success: false, message: `Git pull failed: ${stderr || error.message}` });
      } else {
        const msg = stdout.trim() || 'Already up to date.';
        resolve({ success: true, message: msg });
      }
    });
  });
});


// ========== 4. APP LIFECYCLE ==========
app.whenReady().then(() => {
  // Set dock icon from PNG (black shape on white background)
  if (app.dock) {
    const dockIcon = nativeImage.createFromPath(APP_ICON_PATH);
    app.dock.setIcon(dockIcon);
  }
  createOutputWindow();
  createTray();
});



app.on('activate', () => {
  if (mainWindow === null) createOutputWindow();
});

app.on('window-all-closed', () => {
  // Keep running in menu bar
});
