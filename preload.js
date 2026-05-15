const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electron', {
  log: (msg) => ipcRenderer.send('log-message', msg),
  closeWindow: () => ipcRenderer.send('window-close'),
  onLog: (callback) => {
    ipcRenderer.on('log', (event, msg) => callback(msg));
  },
  setLaunchOnStartup: (enabled) => ipcRenderer.send('set-launch-on-startup', enabled),
  saveSettings: (settings) => ipcRenderer.send('save-settings', settings),
  loadSettings: () => ipcRenderer.invoke('load-settings'),
  updateFromGit: () => ipcRenderer.invoke('update-from-git')
});
