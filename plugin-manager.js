const fs = require('fs');
const path = require('path');
const { ipcMain } = require('electron');

const PLUGIN_DIR = path.join(__dirname, 'plugins');
const SNACK_DIR = path.join(__dirname, 'snacks');

// Load all available plugins
let plugins = [];

function loadPlugins() {
  try {
    const pluginFiles = fs.readdirSync(PLUGIN_DIR).filter(f => f.endsWith('.js'));
    plugins = pluginFiles.map(file => {
      const pluginPath = path.join(PLUGIN_DIR, file);
      const plugin = require(pluginPath);
      return {
        id: plugin.id,
        name: plugin.name,
        description: plugin.description,
        version: plugin.version,
        enabled: true,
        path: pluginPath
      };
    });
  } catch (err) {
    console.error('Failed to load plugins:', err);
    plugins = [];
  }
  return plugins;
}

function getPluginSettings(pluginId) {
  try {
    const settingsPath = path.join(__dirname, 'settings.json');
    if (fs.existsSync(settingsPath)) {
      const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
      return settings.plugins?.[pluginId] || {};
    }
  } catch (err) {
    console.error('Failed to load plugin settings:', err);
  }
  return {};
}

function savePluginSettings(pluginId, settings) {
  try {
    const settingsPath = path.join(__dirname, 'settings.json');
    let settingsData = {};
    if (fs.existsSync(settingsPath)) {
      settingsData = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
    }
    if (!settingsData.plugins) settingsData.plugins = {};
    settingsData.plugins[pluginId] = settings;
    fs.writeFileSync(settingsPath, JSON.stringify(settingsData, null, 2), 'utf-8');
  } catch (err) {
    console.error('Failed to save plugin settings:', err);
  }
}

function enablePlugin(pluginId, enabled) {
  const plugin = plugins.find(p => p.id === pluginId);
  if (plugin) {
    plugin.enabled = enabled;
    savePluginSettings(pluginId, { enabled });
  }
}

function getAllPlugins() {
  return plugins;
}

function getEnabledPlugins() {
  return plugins.filter(p => p.enabled);
}

function installPlugin(pluginId) {
  // In a real implementation, this would download and install a plugin
  // For now, we'll just enable it if it exists
  const plugin = plugins.find(p => p.id === pluginId);
  if (plugin) {
    plugin.enabled = true;
    savePluginSettings(pluginId, { enabled: true });
    return true;
  }
  return false;
}

function uninstallPlugin(pluginId) {  
  // In a real implementation, this would remove the plugin files
  // For now, we'll just disable it
  const plugin = plugins.find(p => p.id === pluginId);
  if (plugin) {
    plugin.enabled = false;
    savePluginSettings(pluginId, { enabled: false });
    return true;
  }
  return false;
}

// Initialize IPC handlers
ipcMain.handle('get-plugins', () => getAllPlugins());
ipcMain.handle('get-enabled-plugins', () => getEnabledPlugins());
ipcMain.handle('enable-plugin', async (event, pluginId) => {
  enablePlugin(pluginId, true);
  return getEnabledPlugins();
});
ipcMain.handle('disable-plugin', async (event, pluginId) => {
  enablePlugin(pluginId, false);
  return getEnabledPlugins();
});
ipcMain.handle('install-plugin', async (event, pluginId) => {
  const success = installPlugin(pluginId);
  return { success, plugins: getAllPlugins() };
});
ipcMain.handle('uninstall-plugin', async (event, pluginId) => {
  const success = uninstallPlugin(pluginId);
  return { success, plugins: getAllPlugins() };
});

// New IPC handlers for plugin management
ipcMain.handle('get-plugin', async (event, pluginId) => {
  const plugin = plugins.find(p => p.id === pluginId);
  if (plugin) {
    return plugin;
  } else {
    throw new Error('Plugin not found');
  }
});

ipcMain.handle('get-plugin-settings', async (event, pluginId) => {
  return getPluginSettings(pluginId);
});

ipcMain.handle('save-plugin-settings', async (event, pluginId, settings) => {
  savePluginSettings(pluginId, settings);
  return { success: true };
});

ipcMain.handle('toggle-plugin', async (event, pluginId) => {
  const plugin = plugins.find(p => p.id === pluginId);
  if (plugin) {
    plugin.enabled = !plugin.enabled;
    savePluginSettings(pluginId, { enabled: plugin.enabled });
    return { success: true, enabled: plugin.enabled };
  } else {
    throw new Error('Plugin not found');
  }
});

// Snack file management
ipcMain.handle('get-snack-files', async () => {
  try {
    const files = fs.readdirSync(SNACK_DIR).filter(f => f.endsWith('.js') || f.endsWith('.json'));
    return files.map(file => {
      return {
        name: file,
        path: path.join(SNACK_DIR, file)
      };
    });
  } catch (err) {
    console.error('Failed to list snack files:', err);
    throw new Error('Failed to list snack files');
  }
});

ipcMain.handle('get-snack-file-content', async (event, filePath) => {
  try {
    return fs.readFileSync(filePath, 'utf-8');
  } catch (err) {
    console.error('Failed to read snack file:', err);
    throw new Error('Failed to read snack file');
  }
});

ipcMain.handle('save-snack-file', async (event, filePath, content) => {
  try {
    fs.writeFileSync(filePath, content, 'utf-8');
    return { success: true };
  } catch (err) {
    console.error('Failed to save snack file:', err);
    throw new Error('Failed to save snack file');
  }
});

// Load plugins on startup
loadPlugins();

module.exports = {
  getAllPlugins,
  getEnabledPlugins,
  enablePlugin,
  disablePlugin,
  installPlugin,
  uninstallPlugin,
  getPluginSettings,
  savePluginSettings
};