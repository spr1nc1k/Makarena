// testportal_bypass.js
// Niewykrywalny silnik stealth dla Testportal (iOS Mobile Safari Stealth)

(function() {
    'use strict';

    // 1. Zabezpieczenie i maskowanie native bridge (window.webkit)
    // Testportal sprawdza czy istnieje window.webkit.messageHandlers. Jeśli tak -> wykrywa niestandardową przeglądarkę/wtyczkę.
    let nativePostMessage = null;
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.MakarenaHandler) {
        nativePostMessage = window.webkit.messageHandlers.MakarenaHandler.postMessage.bind(window.webkit.messageHandlers.MakarenaHandler);
        try {
            delete window.webkit;
        } catch(e) {
            Object.defineProperty(window, 'webkit', {
                get: function() { return undefined; },
                configurable: true,
                enumerable: false
            });
        }
    }

    // Bezpieczne wysyłanie wiadomości do Swift bez wycieku obiektów w window
    window.__makarenaNativeSend = function(data) {
        if (nativePostMessage) {
            nativePostMessage(data);
        }
    };
    Object.defineProperty(window, '__makarenaNativeSend', {
        enumerable: false,
        writable: false,
        configurable: true
    });

    // 2. Poprawne ubieganie się o właściwości na poziomie Document.prototype (tak jak oryginalna przeglądarka)
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

    // 3. Masquerade dla navigator (autentyczny iOS Safari)
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

    // 4. Neutralizacja zdarzeń (blur, visibilitychange, focusout, etc.)
    // Testportal wykonuje testy e.isTrusted. Bloki dotyczą wyłącznie PRAWDZIWYCH zdarzeń systemowych (e.isTrusted === true).
    const BLOCKED_EVENTS = ['blur', 'focusout', 'visibilitychange', 'pagehide', 'mouseleave', 'mouseout', 'freeze'];

    const originalAddEventListener = EventTarget.prototype.addEventListener;

    EventTarget.prototype.addEventListener = function(type, listener, options) {
        const lowerType = String(type).toLowerCase();
        if (BLOCKED_EVENTS.includes(lowerType)) {
            const smartListener = function(event) {
                // Gdy zdarzenie jest wywołane przez system (użytkownik wyszedł z apki/karty):
                if (event && event.isTrusted === true) {
                    try { event.stopImmediatePropagation(); } catch(e) {}
                    try { event.stopPropagation(); } catch(e) {}
                    try { if (event.preventDefault) event.preventDefault(); } catch(e) {}
                    return;
                }
                // Test syntetyczny Testportalu (isTrusted === false) -> przepuść normalnie!
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

    console.log('[Makarena Engine] Stealth bypass initialized successfully.');
})();
