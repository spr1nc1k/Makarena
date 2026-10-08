// testportal_bypass.js
// Niewykrywalny silnik stealth dla Testportal + automatyczne rejestrowanie logów na serwerze 192.168.50.235:9876

(function() {
    'use strict';

    // 1. Zapewnienie poprawnych wymiarów okna (WKWebView domyślnie ustawia outerWidth/outerHeight na 0, co zdradza WebView!)
    try {
        Object.defineProperty(Window.prototype, 'outerWidth', {
            get: function() { return window.innerWidth || 390; },
            configurable: true,
            enumerable: true
        });
        Object.defineProperty(Window.prototype, 'outerHeight', {
            get: function() { return window.innerHeight || 844; },
            configurable: true,
            enumerable: true
        });
    } catch(e) {}

    // 2. ApplePaySession & Navigator Emulacja (Mobile Safari posiada wsparcie dla ApplePaySession)
    if (!('ApplePaySession' in window)) {
        try {
            Object.defineProperty(window, 'ApplePaySession', {
                value: function() {},
                writable: false,
                configurable: true,
                enumerable: false
            });
        } catch(e) {}
    }

    try {
        Object.defineProperty(Navigator.prototype, 'standalone', {
            get: function() { return false; },
            configurable: true,
            enumerable: true
        });
        Object.defineProperty(Navigator.prototype, 'webdriver', {
            get: function() { return false; },
            configurable: true,
            enumerable: true
        });
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

    // 3. Emulacja Document.prototype (visibilityState, hidden, hasFocus)
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

    // 4. Neutralizacja zdarzeń blur / visibilitychange z filtrowaniem isTrusted
    const BLOCKED_EVENTS = ['blur', 'focusout', 'visibilitychange', 'pagehide', 'mouseleave', 'mouseout', 'freeze'];
    const originalAddEventListener = EventTarget.prototype.addEventListener;

    EventTarget.prototype.addEventListener = function(type, listener, options) {
        const lowerType = String(type).toLowerCase();
        if (BLOCKED_EVENTS.includes(lowerType)) {
            const smartListener = function(event) {
                if (event && event.isTrusted === true) {
                    try { event.stopImmediatePropagation(); } catch(e) {}
                    try { event.stopPropagation(); } catch(e) {}
                    try { if (event.preventDefault) event.preventDefault(); } catch(e) {}
                    return;
                }
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

    // 5. Zapisywanie logów diagnostycznych bezpośrednio na Twój serwer 192.168.50.235:9876
    try {
        const logData = {
            timestamp: new Date().toISOString(),
            url: window.location.href,
            outerWidth: window.outerWidth,
            outerHeight: window.outerHeight,
            innerWidth: window.innerWidth,
            innerHeight: window.innerHeight,
            userAgent: navigator.userAgent,
            status: 'STEALTH_ACTIVE'
        };
        fetch('http://192.168.50.235:9876', {
            method: 'POST',
            headers: { 'Content-Type': 'text/plain' },
            body: JSON.stringify(logData)
        }).catch(function() {});
    } catch(e) {}

    console.log('[Makarena Engine] Advanced stealth bypass & remote logger active.');
})();
