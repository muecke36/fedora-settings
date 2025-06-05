// sw.js - Service Worker

const CACHE_NAME = 'ms-appx-web-handler-cache-v1';
const urlsToCache = [
    '/',
    '/index.html',
    // Fügen Sie hier weitere statische Assets hinzu, falls vorhanden (z.B. CSS, Bilder)
    // Da Tailwind CSS über CDN geladen wird und Bilder Platzhalter sind,
    // ist für dieses Beispiel nicht viel mehr nötig.
];

// Installation des Service Workers und Caching der App Shell
self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => {
                console.log('Cache geöffnet');
                return cache.addAll(urlsToCache);
            })
            .catch(err => {
                console.error('Fehler beim Cachen der App Shell:', err);
            })
    );
});

// Aktivierung des Service Workers und Bereinigung alter Caches
self.addEventListener('activate', event => {
    const cacheWhitelist = [CACHE_NAME];
    event.waitUntil(
        caches.keys().then(cacheNames => {
            return Promise.all(
                cacheNames.map(cacheName => {
                    if (cacheWhitelist.indexOf(cacheName) === -1) {
                        return caches.delete(cacheName);
                    }
                })
            );
        })
    );
    return self.clients.claim(); // Sofortige Kontrolle über Clients
});

// Fetch-Ereignisbehandler (Cache-First-Strategie)
self.addEventListener('fetch', event => {
    // Nur GET-Anfragen bearbeiten
    if (event.request.method !== 'GET') {
        return;
    }

    event.respondWith(
        caches.match(event.request)
            .then(response => {
                // Cache hit - return response
                if (response) {
                    return response;
                }

                // Nicht im Cache, also Netzwerk-Request
                return fetch(event.request).then(
                    networkResponse => {
                        // Prüfen, ob wir eine valide Antwort vom Netzwerk erhalten haben
                        if (!networkResponse || networkResponse.status !== 200 || networkResponse.type !== 'basic') {
                            // Bestimmte Anfragen wie tailwindcss nicht cachen, wenn sie fehlschlagen oder opak sind
                            if (event.request.url.includes('tailwindcss')) {
                                return networkResponse;
                            }
                             // Versuchen, die Antwort zu klonen und zu cachen.
                            // Dies ist wichtig, da die Antwort ein Stream ist und nur einmal konsumiert werden kann.
                            let responseToCache = networkResponse.clone();
                            caches.open(CACHE_NAME)
                                .then(cache => {
                                    // Nur gültige Responses cachen (keine Fehler oder undurchsichtige Antworten, es sei denn, es ist CDN)
                                    cache.put(event.request, responseToCache);
                                })
                                .catch(err => {
                                    console.warn('Konnte Antwort nicht cachen:', event.request.url, err);
                                });
                        }
                        return networkResponse;
                    }
                ).catch(error => {
                    console.error('Fetch fehlgeschlagen; Rückgabe der Offline-Seite oder Fehlerbehandlung:', error);
                    // Hier könnten Sie eine Offline-Fallback-Seite zurückgeben
                    // return caches.match('/offline.html');
                });
            })
    );
});
