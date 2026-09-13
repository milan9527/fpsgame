fetch('/config.json', {cache: 'no-store'}).then(r => {
  if (!r.ok) throw new Error('configuration unavailable');
  return r.json();
}).then(c => {
  document.getElementById('api').textContent = c.api;
}).catch(() => {
  document.getElementById('api').textContent = location.origin + '/api';
});
