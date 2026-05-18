module.exports = {
  id: 'reminders',
  name: 'Reminder Sync',
  description: 'Syncs reminders from various sources',
  version: '1.0.0',
  settings: {
    syncInterval: 300, // seconds
    sources: ['calendar', 'todo']
  }
};