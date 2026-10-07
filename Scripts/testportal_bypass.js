// testportal_bypass.js
// Niewykrywalny skrypt omijający detekcję Testportal oraz oszukiwania wtyczek/przeglądarki

(function() {
    'use strict';

    // 1. System maskowania funkcji JavaScript (Native toString Spoofing)
    // Testportal wywołuje .toString() na funkcjach zeby sprawdzić czy nie są nadpisane przez rozszerzenia.
    const nativeToString = Function.prototype.toString;
    const modifiedFunctions = new WeakSet();

    function markAsNative(fn, originalName) {
        modifiedFunctions.add(fn);
        try {
            Object.defineProperty(fn, 'name', { value: originalName || fn.name, writable: false, configurable: true });
        } catch(e) {}
        return fn;
    }

    Function.prototype.toString = function() {
        if (modifiedFunctions.has(this)) {
            return `function ${this.name || ''}() { [native code] }`;
        }
        return nativeToString.call(this);
    };
    markAsNative(Function.prototype.toString, 'toString');

    // 2. Oszukiwanie właściwości Navigator i Środowiska Przeglądarki
    try {
        Object.defineProperty(navigator, 'webdriver', { get: markAsNative(function() { return false; }, 'get webdriver'), configurable: true });
        Object.defineProperty(navigator, 'maxTouchPoints', { get: markAsNative(function() { return 5; }, 'get maxTouchPoints'), configurable: true });
        Object.defineProperty(navigator, 'plugins', { get: markAsNative(function() { return [1, 2, 3]; }, 'get plugins'), configurable: true });
        Object.defineProperty(navigator, 'languages', { get: markAsNative(function() { return ['pl-PL', 'pl', 'en-US', 'en']; }, 'get languages'), configurable: true });
    } catch(e) {}

    // 3. Oszukiwanie Visibility API (Zawsze widoczny)
    try {
        Object.defineProperty(document, 'visibilityState', {
            get: markAsNative(function() { return 'visible'; }, 'get visibilityState'),
            configurable: true
        });

        Object.defineProperty(document, 'hidden', {
            get: markAsNative(function() { return false; }, 'get hidden'),
            configurable: true
        });

        Object.defineProperty(document, 'hasFocus', {
            value: markAsNative(function() { return true; }, 'hasFocus'),
            writable: true,
            configurable: true
        });
    } catch(e) {}

    // 4. Przechwytywanie i bezpieczna neutralizacja eventów utraty ostrości
    const BLOCKED_EVENTS = ['blur', 'focusout', 'visibilitychange', 'pagehide', 'mouseleave', 'mouseout', 'freeze'];

    const originalWinAdd = window.addEventListener;
    const originalDocAdd = document.addEventListener;

    window.addEventListener = markAsNative(function(type, listener, options) {
        if (BLOCKED_EVENTS.includes(String(type).toLowerCase())) {
            // Rejestrujemy pustą bezpieczną funkcję, żeby Testportal nie wykrył braku rejestracji
            const dummyListener = markAsNative(function(e) {
                if (e) {
                    e.stopImmediatePropagation();
                    e.stopPropagation();
                }
            }, 'listener');
            return originalWinAdd.call(window, type, dummyListener, options);
        }
        return originalWinAdd.call(window, type, listener, options);
    }, 'addEventListener');

    document.addEventListener = markAsNative(function(type, listener, options) {
        if (BLOCKED_EVENTS.includes(String(type).toLowerCase())) {
            const dummyListener = markAsNative(function(e) {
                if (e) {
                    e.stopImmediatePropagation();
                    e.stopPropagation();
                }
            }, 'listener');
            return originalDocAdd.call(document, type, dummyListener, options);
        }
        return originalDocAdd.call(document, type, listener, options);
    }, 'addEventListener');

    // 5. Tłumienie eventów w fazie przechwytywania (Capture Phase)
    BLOCKED_EVENTS.forEach(eventName => {
        window.addEventListener(eventName, markAsNative(function(e) {
            if (e) {
                e.stopImmediatePropagation();
                e.stopPropagation();
                if (e.preventDefault) e.preventDefault();
            }
        }, 'eventSuppressor'), true);
    });

    // 6. Maskowanie zdarzeń window.onblur i document.onblur
    ['onblur', 'onfocusout', 'onvisibilitychange', 'onpagehide', 'onmouseleave'].forEach(prop => {
        try {
            Object.defineProperty(window, prop, {
                get: markAsNative(function() { return null; }, 'get ' + prop),
                set: markAsNative(function(val) {}, 'set ' + prop),
                configurable: true
            });
            Object.defineProperty(document, prop, {
                get: markAsNative(function() { return null; }, 'get ' + prop),
                set: markAsNative(function(val) {}, 'set ' + prop),
                configurable: true
            });
        } catch(e) {}
    });

    console.log('[WhiteSolution Stealth Engine] Przeglądarka z zamaskowanymi wtyczkami aktywne.');
})();
