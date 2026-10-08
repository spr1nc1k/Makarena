// testportal_bypass.js
// Czysty silnik stealth dla Testportal (brak jakichkolwiek śladów w window.webkit / window properties)

(function() {
    'use strict';

    // 1. Zapewnienie niewykrywalności prototypu Document
    try {
        Object.defineProperty(Document.prototype, 'visibilityState', {
            get: function() { return 'visible'; },
            configurable: true,
            enumerable: true
        });

        Object.defineProperty(Document.prototype, 'hidden', {
            get: function() { return false; },
            configurable: true,
            enumerable: true
        });

        Object.defineProperty(Document.prototype, 'hasFocus', {
            value: function() { return true; },
            writable: true,
            configurable: true,
            enumerable: true
        });
    } catch(e) {}

    // 2. Masquerade dla navigator (autentyczny iOS Safari)
    try {
        Object.defineProperty(Navigator.prototype, 'vendor', {
            get: function() { return 'Apple Computer, Inc.'; },
            configurable: true,
            enumerable: true
        });
        Object.defineProperty(Navigator.prototype, 'maxTouchPoints', {
            get: function() { return 5; },
            configurable: true,
            enumerable: true
        });
    } catch(e) {}

    // 3. Neutralizacja zdarzeń (blur, visibilitychange, focusout, pagehide, mouseleave)
    // Tłumimy wyłącznie PRAWDZIWY ZDARZENIA SYSTEMOWE (e.isTrusted === true)
    const BLOCKED_EVENTS = ['blur', 'focusout', 'visibilitychange', 'pagehide', 'mouseleave', 'mouseout', 'freeze'];

    const originalAddEventListener = EventTarget.prototype.addEventListener;

    EventTarget.prototype.addEventListener = function(type, listener, options) {
        const lowerType = String(type).toLowerCase();
        if (BLOCKED_EVENTS.includes(lowerType)) {
            const smartListener = function(event) {
                // Gdy zdarzenie pochodzi z systemu (zmiana karty / wyjście z aplikacji):
                if (event && event.isTrusted === true) {
                    try { event.stopImmediatePropagation(); } catch(e) {}
                    try { event.stopPropagation(); } catch(e) {}
                    try { if (event.preventDefault) event.preventDefault(); } catch(e) {}
                    return;
                }
                // Zdarzenia syntetyczne Testportalu (testy sprawdzające czy eventy działają):
                if (typeof listener === 'function') {
                    return listener.call(this, event);
                } else if (listener && typeof listener.handleEvent === 'function') {
                    return listener.handleEvent(event);
                }
            };

            return originalAddEventListener.call(this, type, smartListener, options);
        }
        return originalAddEventListener.call(this, type, listener, options);
    };

    BLOCKED_EVENTS.forEach(eventName => {
        originalAddEventListener.call(window, eventName, function(e) {
            if (e && e.isTrusted === true) {
                try { e.stopImmediatePropagation(); } catch(err) {}
                try { e.stopPropagation(); } catch(err) {}
                try { if (e.preventDefault) e.preventDefault(); } catch(err) {}
            }
        }, true);
    });

    console.log('[Makarena Engine] Zero-trace stealth bypass active.');
})();
