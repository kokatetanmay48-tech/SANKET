// SANKET C2 Defense System - Service Worker
const CACHE_NAME = 'sanket-pwa-v1.1';

const STATIC_ASSETS = [
    './',
    './index.html',
    './manifest.json',
    './icon.svg',
    './icon-192.png',
    './icon-512.png',
    './styles.css',
    './script.js',
    'https://cdn.tailwindcss.com',
    'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
    'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
    'https://unpkg.com/react@18/umd/react.production.min.js',
    'https://unpkg.com/react-dom@18/umd/react-dom.production.min.js',
    'https://unpkg.com/@babel/standalone/babel.min.js'
];

// Install Event: pre-cache application shell assets
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => {
            console.log('[SANKET SW] Pre-caching offline application shell');
            return cache.addAll(STATIC_ASSETS).catch((err) => {
                console.warn('[SANKET SW] Some non-critical assets failed to pre-cache:', err);
            });
        }).then(() => self.skipWaiting())
    );
});

// Activate Event: clear obsolete caches and take immediate control of clients
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((name) => {
                    if (name !== CACHE_NAME) {
                        console.log('[SANKET SW] Deleting obsolete cache:', name);
                        return caches.delete(name);
                    }
                })
            );
        }).then(() => self.clients.claim())
    );
});

// Fetch Event: Stale-While-Revalidate for cached resources, Network-First for dynamic data
self.addEventListener('fetch', (event) => {
    const request = event.request;

    // Only handle GET requests and http/https schemes
    if (request.method !== 'GET' || !request.url.startsWith('http')) {
        return;
    }

    // Bypass Firebase firestore realtime and websocket sync
    if (request.url.includes('firestore.googleapis.com') || request.url.includes('firebaseapp.com') || request.url.includes('google.com')) {
        return;
    }

    // HTML Navigation requests: Network-first with cache fallback
    if (request.mode === 'navigate') {
        event.respondWith(
            fetch(request)
                .then((networkResponse) => {
                    if (networkResponse && networkResponse.status === 200) {
                        const copy = networkResponse.clone();
                        caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
                    }
                    return networkResponse;
                })
                .catch(() => {
                    return caches.match('./index.html') || caches.match(request);
                })
        );
        return;
    }

    // Static Assets & CDN libraries: Cache-First / Stale-While-Revalidate
    event.respondWith(
        caches.match(request).then((cachedResponse) => {
            const fetchPromise = fetch(request)
                .then((networkResponse) => {
                    if (networkResponse && networkResponse.status === 200) {
                        const copy = networkResponse.clone();
                        caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
                    }
                    return networkResponse;
                })
                .catch(() => cachedResponse);

            return cachedResponse || fetchPromise;
        })
    );
});
