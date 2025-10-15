// ====== CONFIG ======
const CACHE_VERSION = 'v3';
const APP_CACHE = `attendanceapp-cache-${CACHE_VERSION}`;
const MODEL_CACHE = `faceapi-model-cache-${CACHE_VERSION}`;

// Detect current base path (e.g., /attendanceapp/ or /)
const BASE_PATH = self.location.pathname
  .replace(/service_worker\.js$/, '')
  .replace(/\/$/, '');
console.log('[SW] Base path:', BASE_PATH);

// Core Flutter/Web app files
const CORE_ASSETS = [
  `${BASE_PATH}/`,
  `${BASE_PATH}/index.html`,
  `${BASE_PATH}/main.dart.js`,
  `${BASE_PATH}/flutter.js`,
  `${BASE_PATH}/manifest.json`,
  `${BASE_PATH}/favicon.png`,
  `${BASE_PATH}/icons/Icon-192.png`,
  `${BASE_PATH}/icons/Icon-512.png`,
  `${BASE_PATH}/js/face-api.min.js`,
];

// Face-api models
const MODEL_FILES = [
  `${BASE_PATH}/models/ssd_mobilenetv1_model-weights_manifest.json`,
  `${BASE_PATH}/models/face_landmark_68_model-weights_manifest.json`,
  `${BASE_PATH}/models/face_recognition_model-weights_manifest.json`,
  `${BASE_PATH}/models/tiny_face_detector_model-weights_manifest.json`,
  `${BASE_PATH}/models/ssd_mobilenetv1_model-shard1`,
  `${BASE_PATH}/models/face_landmark_68_model-shard1`,
  `${BASE_PATH}/models/face_recognition_model-shard1`,
  `${BASE_PATH}/models/tiny_face_detector_model-shard1`,
];

// ====== INSTALL ======
self.addEventListener('install', (event) => {
  console.log('[SW] Installing...');
  event.waitUntil(
    (async () => {
      const appCache = await caches.open(APP_CACHE);
      await appCache.addAll(CORE_ASSETS);
      const modelCache = await caches.open(MODEL_CACHE);
      await modelCache.addAll(MODEL_FILES);
    })()
  );
  self.skipWaiting();
});

// ====== ACTIVATE ======
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating...');
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k !== APP_CACHE && k !== MODEL_CACHE)
          .map((k) => {
            console.log('[SW] Deleting old cache:', k);
            return caches.delete(k);
          })
      )
    )
  );
  self.clients.claim();
});

// ====== FETCH ======
self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // Serve model files from model cache
  if (url.pathname.includes('/models/')) {
    event.respondWith(
      caches.open(MODEL_CACHE).then(async (cache) => {
        const cached = await cache.match(req);
        if (cached) return cached;

        try {
          const netRes = await fetch(req);
          cache.put(req, netRes.clone());
          return netRes;
        } catch (e) {
          console.warn('[SW] Model fetch failed:', e);
          return new Response('Offline: model not available', { status: 503 });
        }
      })
    );
    return;
  }

  // Otherwise: cache-first for core files, network fallback
  event.respondWith(
    caches.match(req).then((cached) => {
      return (
        cached ||
        fetch(req)
          .then((netRes) => netRes)
          .catch(() => {
            if (req.mode === 'navigate') {
              return caches.match(`${BASE_PATH}/index.html`);
            }
          })
      );
    })
  );
});
