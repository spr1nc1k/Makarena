// testportal_bypass.js
// Ten skrypt jest automatycznie wstrzykiwany przed załadowaniem strony (atDocumentStart)
// Całkowicie neutralizuje systemy detekcji opuszczenia karty / utraty ostrości w Testportal

(function() {
    'use me strict';
    console.log('[Makarena Stealth] Inicjalizacja omijania zabezpieczeń Testportal...');

    // 1. Nadpisanie właściwości widoczności dokumentu (Visibility API)
    Object.defineProperty(document, 'visibilityState', {
        get: function() { return 'visible'; },
        configurable: true
    });

    Object.defineProperty(document, 'hidden', {
        get: function() { return false; },
        configurable: true
    });

    Object.defineProperty(document, 'hasFocus', {
        value: function() { return true; },
        writable: true,
        configurable: true
    });

    // 2. Blokowanie zdarzeń utraty ostrości i zmiany widoczności
    const BLOCKED_EVENTS = [
        'blur',
        'focusout',
        'visibilitychange',
        'pagehide',
        'mouseleave',
        'mouseout',
        'freeze',
        'pointerleave'
    ];

    // Przechwytywanie addEventListener na window oraz document
    const originalWindowAddEventListener = window.addEventListener;
    const originalDocumentAddEventListener = document.addEventListener;

    function filterEventListener(target, originalFn, type, listener, options) {
        if (BLOCKED_EVENTS.includes(type.toLowerCase())) {
            console.log('[Makarena Stealth] Zablokowano rejestrację eventu:', type);
            // Ignorujemy rejestrację zdarzenia lub przekazujemy pustą funkcję
            return;
        }
        return originalFn.call(target, type, listener, options);
    }

    window.addEventListener = function(type, listener, options) {
        filterEventListener(this, originalWindowAddEventListener, type, listener, options);
    };

    document.addEventListener = function(type, listener, options) {
        filterEventListener(this, originalDocumentAddEventListener, type, listener, options);
    };

    // 3. Czyszczenie bezpośrednich właściwości onblur, onvisibilitychange itp.
    const propertiesToNullify = ['onblur', 'onfocusout', 'onvisibilitychange', 'onpagehide', 'onmouseleave'];
    propertiesToNullify.forEach(prop => {
        try {
            Object.defineProperty(window, prop, {
                get: function() { return null; },
                set: function(val) { console.log('[Makarena Stealth] Zablokowano ' + prop); },
                configurable: true
            });
            Object.defineProperty(document, prop, {
                get: function() { return null; },
                set: function(val) { console.log('[Makarena Stealth] Zablokowano ' + prop); },
                configurable: true
            });
        } catch(e) {}
    });

    // 4. Zatrzaskiwanie zdarzeń zatrzymujących propagację wywołań w fazie capture
    BLOCKED_EVENTS.forEach(eventName => {
        window.addEventListener(eventName, function(e) {
            e.stopImmediatePropagation();
            e.stopPropagation();
            e.preventDefault();
        }, true);
    });

    console.log('[Makarena Stealth] Omijanie zabezpieczeń aktywne.');
})();
