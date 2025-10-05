const CACHE_NAME = 'attendanceapp-cache-v1';
const MODEL_CACHE = 'faceapi-model-cache-v1';

// Files to always cache (your Flutter app shell)
const CORE_ASSETS = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter.js',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/js/face-api.min.js'
];

// Face-api models (adjust if filenames differ)
const MODEL_FILES = [
  '/models/ssd_mobilenetv1_model-weights_manifest.json',
  '/models/face_landmark_68_model-weights_manifest.json',
  '/models/face_recognition_model-weights_manifest.json',
  '/models/tiny_face_detector_model-weights_manifest.json',
  '/models/ssd_mobilenetv1_model-shard1',  // example shards, optional
  '/models/face_landmark_68_model-shard1',
  '/models/face_recognition_model-shard1',
  '/models/tiny_face_detector_model-shard1'
];

// Install event → pre-cache models + core app files
self.addEventListener('install', (event) => {
  console.log('[ServiceWorker] Install');
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      await cache.addAll(CORE_ASSETS);

      const modelCache = await caches.open(MODEL_CACHE);
      await modelCache.addAll(MODEL_FILES);
    })()
  );
  self.skipWaiting();
});

// Activate event → clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[ServiceWorker] Activate');
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME && key !== MODEL_CACHE)
          .map((key) => caches.delete(key))
      );
    })
  );
  self.clients.claim();
});

// Fetch handler → serve from cache first
self.addEventListener('fetch', (event) => {
  const request = event.request;

  // Prefer model cache for /models/
  if (request.url.includes('/models/')) {
    event.respondWith(
      caches.open(MODEL_CACHE).then((cache) => {
        return cache.match(request).then((response) => {
          return (
            response ||
            fetch(request).then((netRes) => {
              cache.put(request, netRes.clone());
              return netRes;
            })
          );
        });
      })
    );
    return;
  }

  // Otherwise, use app cache
  event.respondWith(
    caches.match(request).then((response) => {
      return (
        response ||
        fetch(request).then((netRes) => {
          return netRes;
        })
      );
    })
  );
});
