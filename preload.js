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
  updateFromGit: () => ipcRenderer.invoke('update-from-git'),
  
  // Plugin management
  getPlugins: () => ipcRenderer.invoke('get-plugins'),
  getPlugin: (pluginId) => ipcRenderer.invoke('get-plugin', pluginId),
  getPluginSettings: (pluginId) => ipcRenderer.invoke('get-plugin-settings', pluginId),
  savePluginSettings: (pluginId, settings) => ipcRenderer.invoke('save-plugin-settings', pluginId, settings),
  togglePlugin: (pluginId) => ipcRenderer.invoke('toggle-plugin', pluginId),
  
  // Snack file management
  getSnackFiles: () => ipcRenderer.invoke('get-snack-files'),
  getSnackFileContent: (filePath) => ipcRenderer.invoke('get-snack-file-content', filePath),
  saveSnackFile: (filePath, content) => ipcRenderer.invoke('save-snack-file', filePath, content)
});
