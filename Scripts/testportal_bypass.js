// testportal_bypass.js
// Najnowocześniejszy silnik stealth z obsługą zdarzeń e.isTrusted (przechodzi testy syntetyczne Testportal)

(function() {
    'use strict';

    // 1. Bezpieczna obsługa Native toString Spoofing
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

    // 2. Dodanie fabrycznego obiektu window.safari
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

    // 3. Modyfikacja na poziomie PROTOTYPU (Document.prototype)
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

    // 4. Inteligenta neutralizacja eventów z weryfikacją e.isTrusted
    // Testportal wykonuje syntetyczny test (dispatchEvent z e.isTrusted === false).
    // Jeśli zablokujemy zdarzenia syntetyczne, Testportal zgłasza błąd "Wtyczki modyfikujące zachowanie"!
    // Dlatego przepuszczamy zdarzenia z e.isTrusted === false, a blokujemy TYLKO prawdziwe zdarzenia systemowe (e.isTrusted === true).

    const BLOCKED_EVENTS = ['blur', 'focusout', 'visibilitychange', 'pagehide', 'mouseleave', 'mouseout', 'freeze'];

    const originalAddEventListener = EventTarget.prototype.addEventListener;

    EventTarget.prototype.addEventListener = markAsNative(function(type, listener, options) {
        const lowerType = String(type).toLowerCase();
        if (BLOCKED_EVENTS.includes(lowerType)) {
            const smartListener = markAsNative(function(event) {
                // Jeśli zdarzenie jest PRAWDZIWYM zdarzeniem systemowym (użytkownik zmienił kartę / wyszedł z apki):
                if (event && event.isTrusted === true) {
                    try { event.stopImmediatePropagation(); } catch(e) {}
                    try { event.stopPropagation(); } catch(e) {}
                    try { if (event.preventDefault) event.preventDefault(); } catch(e) {}
                    return;
                }
                // Zdarzenie syntetyczne Testportalu (test sprawdzający czy zdarzenia działają) - wykonaj normalnie!
                if (typeof listener === 'function') {
                    return listener.call(this, event);
                } else if (listener && typeof listener.handleEvent === 'function') {
                    return listener.handleEvent(event);
                }
            }, listener ? (listener.name || 'listener') : 'listener');

            return originalAddEventListener.call(this, type, smartListener, options);
        }
        return originalAddEventListener.call(this, type, listener, options);
    }, 'addEventListener');

    // 5. Tłumienie w fazie przechwytywania (Capture Phase) wyłącznie dla prawdziwych zdarzeń systemowych
    BLOCKED_EVENTS.forEach(eventName => {
        originalAddEventListener.call(window, eventName, markAsNative(function(e) {
            if (e && e.isTrusted === true) {
                try { e.stopImmediatePropagation(); } catch(err) {}
                try { e.stopPropagation(); } catch(err) {}
                try { if (e.preventDefault) e.preventDefault(); } catch(err) {}
            }
        }, 'smartSuppressor'), true);
    });

    console.log('[WhiteSolution Stealth Engine] Inteligentny silnik anty-detekcji z filtrem e.isTrusted aktywny.');
})();
