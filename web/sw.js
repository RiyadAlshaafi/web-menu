// Keeps the app's own files on the phone after the first visit, so the menu opens without
// downloading the app again. Only files from this site are kept; menu data, carts and orders
// always go to Supabase (another origin), so they are never served from here.
//
// tool/vercel_build.sh replaces the two stamps below on every build: a new build gets a new app
// cache (the old one is deleted), and the engine cache lives until Flutter itself is upgraded.
const BUILD = '__BUILD_ID__';
const ENGINE = '__ENGINE_ID__';
const APP_CACHE = `menu-app-${BUILD}`;
const ENGINE_CACHE = `menu-engine-${ENGINE}`;
const PAGE = '/';
const PAGE_TIMEOUT_MS = 3000;

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        if (key.startsWith('menu-') && key !== APP_CACHE && key !== ENGINE_CACHE) {
          await caches.delete(key);
        }
      }
      await self.clients.claim();
    })(),
  );
});

function cacheFor(url) {
  return url.pathname.startsWith('/canvaskit/') ? ENGINE_CACHE : APP_CACHE;
}

function keepable(url) {
  return url.origin === self.location.origin && url.pathname !== '/sw.js';
}

async function store(cacheName, request, response) {
  if (response && response.ok && response.type === 'basic') {
    const cache = await caches.open(cacheName);
    await cache.put(request, response.clone());
  }
  return response;
}

// The page itself: newest when the network answers quickly, the kept copy otherwise.
async function page(request) {
  const network = fetch(request).then((response) => store(APP_CACHE, PAGE, response));
  network.catch(() => {}); // answered from the kept copy below when this fails
  const timeout = new Promise((resolve) => setTimeout(resolve, PAGE_TIMEOUT_MS));
  try {
    const fast = await Promise.race([network, timeout]);
    if (fast) return fast;
  } catch (_) {
    // offline: fall through to the kept copy
  }
  const kept = await caches.match(PAGE, { cacheName: APP_CACHE });
  return kept || network;
}

// App and engine files: the kept copy first, the network only the first time.
async function file(request, url) {
  const name = cacheFor(url);
  const kept = await caches.match(request, { cacheName: name });
  if (kept) return kept;
  return store(name, request, await fetch(request));
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (!keepable(url)) return;
  if (request.mode === 'navigate') {
    event.respondWith(page(request));
    return;
  }
  event.respondWith(file(request, url));
});

// After the first frame the page lists the files it loaded before this worker was in charge;
// keep those too (usually straight from the browser's own cache), so the next visit needs none.
self.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || data.type !== 'keep' || !Array.isArray(data.urls)) return;
  event.waitUntil(
    (async () => {
      for (const raw of data.urls) {
        try {
          const url = new URL(raw);
          if (!keepable(url)) continue;
          const name = cacheFor(url);
          if (await caches.match(url.href, { cacheName: name })) continue;
          await store(name, url.href, await fetch(url.href, { cache: 'force-cache' }));
        } catch (_) {
          // a file that can't be kept now is fetched again next time
        }
      }
    })(),
  );
});
