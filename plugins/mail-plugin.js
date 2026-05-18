module.exports = {
  id: 'mail',
  name: 'Mail VIP Ingest',
  description: 'Processes VIP emails and notifications',
  version: '1.0.0',
  settings: {
    checkInterval: 60, // seconds
    maxEmails: 100
  }
};