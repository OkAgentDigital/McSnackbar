const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

// Require electron with fallback for the npm package behavior
let app, BrowserWindow, Tray, Menu, nativeImage;
let ipcMain;
try {
  // In Electron runtime, require('electron') returns the module
  const electron = require('electron');
  app = electron.app;
  BrowserWindow = electron.BrowserWindow;
  Tray = electron.Tray;
  Menu = electron.Menu;
  nativeImage = electron.nativeImage;
  ipcMain = electron.ipcMain;
} catch (e1) {
  try {
    // Fallback: electron binary path from npm package
    const electronPath = require('electron');
    const electronModule = require(electronPath + '/../Resources/default_app/package.json');
    // This won't work either, try direct electron binary
    const { app: a, BrowserWindow: bw, Tray: t, Menu: m, nativeImage: ni, ipcMain: ipc } = require(electronPath.replace('/MacOS/Electron', '/Resources/app/node_modules/electron'));
    app = a; BrowserWindow = bw; Tray = t; Menu = m; nativeImage = ni; ipcMain = ipc;
  } catch(e2) {
    console.error('Failed to load Electron modules:', e1.message, e2.message);
    process.exit(1);
  }
}

let mainWindow = null;      // Output window
let tray = null;            // Menu bar icon

const APP_ICON_PATH = path.join(__dirname, "dist/icons/electron/icon-48.png");
const TRAY_ICON_PATH = path.join(__dirname, "tray-icon.png");
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
  try {
    console.log(`Loading app icon from: ${APP_ICON_PATH}`);
    const appIcon = nativeImage.createFromPath(APP_ICON_PATH);
    console.log('App icon loaded successfully');
  } catch (e) {
    console.error('Failed to load app icon:', e.message, 'Will use default icon');
  }

  mainWindow = new BrowserWindow({
    width: 900,
    height: 680,
    minWidth: 700,
    minHeight: 500,
    show: false,
    backgroundColor: '#f9fafb',
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

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  mainWindow.on('closed', () => { mainWindow = null; });
}

// ========== 2. CREATE MENU BAR ICON (white on transparent PNG) ==========
function createTray() {
  const iconPath = TRAY_ICON_PATH;
  let icon;
  try {
    console.log(`Loading tray icon from: ${iconPath}`);
    icon = nativeImage.createFromPath(iconPath);
    try {
      icon = icon.resize({ width: 18, height: 18 });
      console.log('Tray icon resized successfully');
    } catch (resizeError) {
      console.error('Failed to resize tray icon:', resizeError.message, 'Using original size');
    }
    console.log('Tray icon loaded successfully');
  } catch (e) {
    console.error('Failed to load tray icon:', e.message, 'Falling back to empty icon');
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
  // Dock icon uses the .icns bundle icon automatically (macOS applies rounded corners)
  if (app.dock) {
    // macOS automatically uses the app bundle's icon.icns for the dock
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
