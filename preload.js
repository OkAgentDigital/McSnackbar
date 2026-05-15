const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electron', {
  log: (msg) => ipcRenderer.send('log-message', msg),
  closeWindow: () => ipcRenderer.send('window-close'),
  onLog: (callback) => {
    ipcRenderer.on('log', (event, msg) => callback(msg));
  },
  setLaunchOnStartup: (enabled) => ipcRenderer.send('set-launch-on-startup', enabled),
  updateFromGit: () => ipcRenderer.invoke('update-from-git')
});


