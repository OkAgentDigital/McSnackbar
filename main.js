const { app, BrowserWindow, Tray, Menu, nativeImage, ipcMain } = require('electron');


const { exec } = require('child_process');
const path = require('path');

let mainWindow = null;      // Output window
let tray = null;            // Menu bar icon


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
    icon: path.join(__dirname, 'icon.png')
  });
  mainWindow.loadFile('output.html');

  mainWindow.on('closed', () => { mainWindow = null; });
}

// ========== 2. CREATE MENU BAR ICON (from SVG) ==========
function createTray() {
  const fs = require('fs');
  const svgPath = path.join(__dirname, 'icon.svg');
  let icon;
  try {
    // Read SVG and set fill to black for template image compatibility
    // macOS template images use black as the mask color and render it
    // as white in dark menu bar, black in light menu bar automatically
    let svgContent = fs.readFileSync(svgPath, 'utf-8');
    // Set fill to black for proper template image rendering
    svgContent = svgContent.replace(/ fill="[^"]*"/g, ' fill="#000000"');
    const dataUrl = 'data:image/svg+xml;base64,' + Buffer.from(svgContent).toString('base64');
    icon = nativeImage.createFromDataURL(dataUrl);
    icon = icon.resize({ width: 16, height: 16 });
    // Set as template image so macOS renders it appropriately in light/dark menu bar
    icon.setTemplateImage(true);
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
    path: app.getPath('exe')
  });
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('log', `Launch on startup ${enabled ? 'enabled' : 'disabled'}`);
  }
});

ipcMain.handle('update-from-git', async () => {
  return new Promise((resolve) => {
    const repoPath = __dirname;
    exec('git pull', { cwd: repoPath }, (error, stdout, stderr) => {
      if (error) {
        resolve({ success: false, message: `Git pull failed: ${stderr || error.message}` });
      } else {
        resolve({ success: true, message: stdout.trim() || 'Already up to date.' });
      }
    });
  });
});


// ========== 4. APP LIFECYCLE ==========
app.whenReady().then(() => {
  // Set dock icon from SVG (white fill on transparent)
  if (app.dock) {
    const fs = require('fs');
    const svgPath = path.join(__dirname, 'icon.svg');
    try {
      let svgContent = fs.readFileSync(svgPath, 'utf-8');
      // Keep the white fill for the dock icon
      const dataUrl = 'data:image/svg+xml;base64,' + Buffer.from(svgContent).toString('base64');
      const dockIcon = nativeImage.createFromDataURL(dataUrl);
      app.dock.setIcon(dockIcon);
    } catch (e) {
      // Fallback to PNG
      const dockIcon = nativeImage.createFromPath(path.join(__dirname, 'icon.png'));
      app.dock.setIcon(dockIcon);
    }
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
