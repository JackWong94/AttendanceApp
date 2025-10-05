// 📦 Custom Face API + Flutter service worker
const APP_VERSION = 'v1.0.0'; // ← bump this when you update models
const CACHE_NAME = `attendanceapp-${APP_VERSION}`;

// ✅ face-api.js model files to cache
const MODEL_URLS = [
  '/models/ssdMobilenetv1_model-weights_manifest.json',
  '/models/ssdMobilenetv1_model-shard1',
  '/models/faceLandmark68Net_model-weights_manifest.json',
  '/models/faceLandmark68Net_model-shard1',
  '/models/faceRecognitionNet_model-weights_manifest.json',
  '/models/faceRecognitionNet_model-shard1',
  '/models/tinyFaceDetector_model-weights_manifest.json',
  '/models/tinyFaceDetector_model-shard1',
];

// ✅ Flutter core files (precache on install)
const CORE_FILES = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter_bootstrap.js',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
];

// ✅ Precache on installation
self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker...');
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Precaching app shell + models...');
      return cache.addAll([...CORE_FILES, ...MODEL_URLS]);
    })
  );
  self.skipWaiting();
});

// ✅ Clean old caches on activate
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating new version...');
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            console.log('[SW] Removing old cache:', key);
            return caches.delete(key);
          }
        })
      )
    )
  );
  self.clients.claim();
});

// ✅ Cache-first strategy for models, network-first for others
self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);

  // Handle face-api model files: cache first
  if (url.pathname.startsWith('/models/')) {
    event.respondWith(
      caches.match(request).then((response) => {
        if (response) {
          console.log('[SW] Serving model from cache:', url.pathname);
          return response;
        }
        console.log('[SW] Fetching model from network:', url.pathname);
        return fetch(request).then((networkResponse) => {
          caches.open(CACHE_NAME).then((cache) =>
            cache.put(request, networkResponse.clone())
          );
          return networkResponse;
        });
      })
    );
    return;
  }

  // Default: try cache, then network
  event.respondWith(
    caches.match(request).then((response) => {
      return (
        response ||
        fetch(request).catch(() => {
          console.warn('[SW] Offline & not cached:', url.pathname);
          return response;
        })
      );
    })
  );
});
