const CACHE_NAME = 'attendanceapp-cache-v1';
const MODEL_CACHE = 'faceapi-model-cache-v1';

// Detect current base path (e.g., /AttendanceApp/ckhardware/)
const BASE_PATH = self.location.pathname.replace(/service_worker\.js$/, '').replace(/\/$/, '');
console.log('[ServiceWorker] Base path detected:', BASE_PATH);

// Files to always cache (your Flutter app shell)
const CORE_ASSETS = [
  `${BASE_PATH}/`,
  `${BASE_PATH}/index.html`,
  `${BASE_PATH}/main.dart.js`,
  `${BASE_PATH}/flutter.js`,
  `${BASE_PATH}/manifest.json`,
  `${BASE_PATH}/favicon.png`,
  `${BASE_PATH}/icons/Icon-192.png`,
  `${BASE_PATH}/icons/Icon-512.png`,
  `${BASE_PATH}/js/face-api.min.js`
];

// Face-api models (relative to each base path)
const MODEL_FILES = [
  `${BASE_PATH}/models/ssd_mobilenetv1_model-weights_manifest.json`,
  `${BASE_PATH}/models/face_landmark_68_model-weights_manifest.json`,
  `${BASE_PATH}/models/face_recognition_model-weights_manifest.json`,
  `${BASE_PATH}/models/tiny_face_detector_model-weights_manifest.json`,
  `${BASE_PATH}/models/ssd_mobilenetv1_model-shard1`,
  `${BASE_PATH}/models/face_landmark_68_model-shard1`,
  `${BASE_PATH}/models/face_recognition_model-shard1`,
  `${BASE_PATH}/models/tiny_face_detector_model-shard1`
];

// Install event → pre-cache models + core app files
self.addEventListener('install', (event) => {
  console.log('[ServiceWorker] Install for base:', BASE_PATH);
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
  const url = new URL(request.url);

  // Prefer model cache for /models/
  if (url.pathname.includes('/models/')) {
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
