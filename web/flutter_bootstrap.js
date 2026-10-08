{{flutter_js}}
{{flutter_build_config}}

// Flutter's own service worker is deprecated; the app files are kept by web/sw.js instead.
_flutter.loader.load();

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch((error) => {
      console.warn('Menu cache not available:', error);
    });
  });
  // Files loaded before the worker took over are handed to it, so the next visit downloads nothing.
  window.addEventListener('flutter-first-frame', () => {
    navigator.serviceWorker.ready.then((registration) => {
      const here = location.origin;
      const urls = performance
        .getEntriesByType('resource')
        .map((entry) => entry.name)
        .filter((name) => name.startsWith(here));
      if (registration.active) registration.active.postMessage({ type: 'keep', urls });
    });
  });
}
