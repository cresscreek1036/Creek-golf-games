// Offline support for the website (the iPhone app carries everything itself
// and never loads this). The first visit with signal saves the page, its
// fonts and scripts on the phone; after that:
//  - the page itself comes from the internet when there's signal (so a new
//    version arrives), and from the saved copy when there isn't — including
//    weak signal, where it gives the network about 4 seconds first;
//  - fonts and scripts come from the saved copy.
// Calls to the leaderboard server (another site) are never touched.
// make-netlify.sh fills in VERSION and FILES each time it publishes.
const VERSION = '__VERSION__';
const FILES = __FILES__;
const CACHE = 'creek-' + VERSION;

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k.startsWith('creek-') && k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});
function withTimeout(promise, ms){
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('timeout')), ms);
    promise.then(r => { clearTimeout(timer); resolve(r); }, e => { clearTimeout(timer); reject(e); });
  });
}
self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;
  if (req.mode === 'navigate') {
    event.respondWith(
      withTimeout(fetch(req), 4000)
        .then(res => {
          if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put('./index.html', copy)); }
          return res;
        })
        .catch(() => caches.match('./index.html').then(hit => hit || fetch(req)))
    );
    return;
  }
  event.respondWith(caches.match(req, { ignoreSearch: true }).then(hit => hit || fetch(req)));
});
