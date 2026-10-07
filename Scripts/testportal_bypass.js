// testportal_bypass.js
// Niewykrywalny silnik stealth dla Testportal (bypasowanie detekcji window.webkit, prototype i wtyczek)

(function() {
    'use strict';

    // 1. Zapisanie oryginalnego komunikatora WKWebView do zmiennej lokalnej (closure) i ukrycie webkit
    let nativePostMessage = null;
    try {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.MakarenaHandler) {
            const handler = window.webkit.messageHandlers.MakarenaHandler;
            nativePostMessage = handler.postMessage.bind(handler);
        }
    } catch(e) {}

    // Udostępniamy bezpieczną metodę wysyłania komunikatów bez śladu na obiekcie window
    window.__makarenaSend = function(data) {
        if (nativePostMessage) {
            nativePostMessage(data);
        }
    };
    try {
        Object.defineProperty(window, '__makarenaSend', { enumerable: false, writable: false });
    } catch(e) {}

    // Usunięcie lub ukrycie obietnicy window.webkit przed skanerem Testportal
    try {
        delete window.webkit;
    } catch(e) {
        try { window.webkit = undefined; } catch(err) {}
    }

    // 2. Dodanie fabrycznego obiektu window.safari (wymagany przez Testportal na iOS)
    if (!window.safari) {
        try {
            Object.defineProperty(window, 'safari', {
                value: { pushNotification: {} },
                writable: false,
                configurable: true,
                enumerable: true
            });
        } catch(e) {}
    }

    // 3. System maskowania funkcji JavaScript (Native toString Spoofing)
    const nativeToString = Function.prototype.toString;
    const modifiedFunctions = new WeakSet();

    function markAsNative(fn, originalName) {
        modifiedFunctions.add(fn);
        try {
            Object.defineProperty(fn, 'name', { value: originalName || fn.name, writable: false, configurable: true });
        } catch(e) {}
        return fn;
    }

    Function.prototype.toString = markAsNative(function() {
        if (modifiedFunctions.has(this)) {
            return `function ${this.name || ''}() { [native code] }`;
        }
        return nativeToString.call(this);
    }, 'toString');

    // 4. Modyfikacja na poziomie PROTOTYPU (nie na obiekcie instance!), zapobiega wykryciu getOwnPropertyDescriptor
    try {
        Object.defineProperty(Document.prototype, 'visibilityState', {
            get: markAsNative(function() { return 'visible'; }, 'get visibilityState'),
            configurable: true,
            enumerable: true
        });

        Object.defineProperty(Document.prototype, 'hidden', {
            get: markAsNative(function() { return false; }, 'get hidden'),
            configurable: true,
            enumerable: true
        });

        Object.defineProperty(Document.prototype, 'hasFocus', {
            value: markAsNative(function() { return true; }, 'hasFocus'),
            writable: true,
            configurable: true,
            enumerable: true
        });
    } catch(e) {}

    // 5. Maskowanie właściwości Navigator
    try {
        Object.defineProperty(Navigator.prototype, 'webdriver', {
            get: markAsNative(function() { return false; }, 'get webdriver'),
            configurable: true,
            enumerable: true
        });
        Object.defineProperty(Navigator.prototype, 'maxTouchPoints', {
            get: markAsNative(function() { return 5; }, 'get maxTouchPoints'),
            configurable: true,
            enumerable: true
        });
    } catch(e) {}

    // 6. Bezpieczne przechwytywanie i neutralizacja eventów utraty ostrości na EventTarget.prototype
    const BLOCKED_EVENTS = ['blur', 'focusout', 'visibilitychange', 'pagehide', 'mouseleave', 'mouseout', 'freeze'];

    const originalAddEventListener = EventTarget.prototype.addEventListener;

    EventTarget.prototype.addEventListener = markAsNative(function(type, listener, options) {
        const lowerType = String(type).toLowerCase();
        if (BLOCKED_EVENTS.includes(lowerType)) {
            // Przepuszczamy rejestrację atapera, który natychmiast zatrzymuje zdarzenie bez rzucania błędów
            const safeListener = markAsNative(function(event) {
                if (event) {
                    try { event.stopImmediatePropagation(); } catch(e) {}
                    try { event.stopPropagation(); } catch(e) {}
                    try { if (event.preventDefault) event.preventDefault(); } catch(e) {}
                }
            }, listener ? (listener.name || 'listener') : 'listener');
            
            return originalAddEventListener.call(this, type, safeListener, options);
        }
        return originalAddEventListener.call(this, type, listener, options);
    }, 'addEventListener');

    // 7. Przechwytywanie w fazie capture
    BLOCKED_EVENTS.forEach(eventName => {
        originalAddEventListener.call(window, eventName, markAsNative(function(e) {
            if (e) {
                try { e.stopImmediatePropagation(); } catch(err) {}
                try { e.stopPropagation(); } catch(err) {}
                try { if (e.preventDefault) e.preventDefault(); } catch(err) {}
            }
        }, 'suppressEvent'), true);
    });

    console.log('[WhiteSolution Stealth] Silnik anty-detekcji aktywny.');
})();
