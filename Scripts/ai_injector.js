// ai_injector.js
// Niewykrywalny moduł podpowiedzi AI dla Makarena (zerowy ślad w window)

(function() {
    'use strict';

    let isPanicMode = false;
    const originalPlaceholders = new Map();

    function extractQuestionData() {
        if (isPanicMode) return null;

        let questionTextEl = document.querySelector('.question_text_content, .question_content, .question-text, .question_text, .question_wrapper') 
            || document.querySelector('h1, h2, h3, .question');

        const questionText = questionTextEl ? questionTextEl.innerText.trim() : '';

        const optionElements = Array.from(document.querySelectorAll('.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item, input[type="radio"], input[type="checkbox"]'));
        
        let options = [];
        if (optionElements.length > 0) {
            optionElements.forEach((el, index) => {
                let parent = el.closest('.answer_container, .question_option_wrapper, label, li') || el;
                let text = parent.innerText ? parent.innerText.trim() : el.nextSibling ? el.nextSibling.textContent.trim() : '';
                if (text) {
                    options.push({ id: index, text: text });
                }
            });
        }

        const openInput = document.querySelector('textarea, input[type="text"]:not([name*="search"])');

        return {
            type: options.length > 0 ? 'closed' : (openInput ? 'open' : 'unknown'),
            question: questionText,
            options: options
        };
    }

    function applyClosedHint(correctIndex) {
        if (isPanicMode) return;

        const optionElements = document.querySelectorAll('.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item');
        if (!optionElements[correctIndex]) return;

        const target = optionElements[correctIndex];
        
        // Pogrubienie pierwszej litery / etykiety opcji
        let labelSpan = target.querySelector('.option_letter, .answer_letter, span');
        if (labelSpan) {
            labelSpan.style.fontWeight = '800';
            labelSpan.style.textDecoration = 'underline';
        } else {
            target.style.fontWeight = '700';
        }
    }

    function applyOpenHint(answerText) {
        if (isPanicMode) return;

        const input = document.querySelector('textarea, input[type="text"]:not([name*="search"])');
        if (!input) return;

        if (!originalPlaceholders.has(input)) {
            originalPlaceholders.set(input, input.getAttribute('placeholder') || 'Wprowadź odpowiedź');
        }

        input.setAttribute('placeholder', answerText);
    }

    function enablePanicMode() {
        isPanicMode = true;
        const optionElements = document.querySelectorAll('.question_option_wrapper, .answer_container, label.answer, .answer_item, span');
        optionElements.forEach(el => {
            el.style.fontWeight = '';
            el.style.textDecoration = '';
        });

        const inputs = document.querySelectorAll('textarea, input[type="text"]');
        inputs.forEach(input => {
            if (originalPlaceholders.has(input)) {
                input.setAttribute('placeholder', originalPlaceholders.get(input));
            } else {
                input.setAttribute('placeholder', 'Wprowadź odpowiedź');
            }
        });
        originalPlaceholders.clear();
    }

    function disablePanicMode() {
        isPanicMode = false;
    }

    // Nasłuchuj zdarzeń wewnętrznych z poziomu Swift
    document.addEventListener('__makarena_action', function(e) {
        if (!e || !e.detail) return;
        const action = e.detail.action;

        if (action === 'analyze') {
            disablePanicMode();
            const data = extractQuestionData();
            if (data) {
                // Zamiast window.webkit.messageHandlers (które zdradzają WKWebView) używamy window.prompt z cichym przechwyceniem w WKUIDelegate!
                window.prompt('__makarena_bridge:' + JSON.stringify({
                    action: 'questionDataExtracted',
                    data: data
                }), '');
            }
        } else if (action === 'applyClosed') {
            applyClosedHint(e.detail.correctIndex);
        } else if (action === 'applyOpen') {
            applyOpenHint(e.detail.answerText);
        } else if (action === 'panic') {
            enablePanicMode();
        }
    });
})();
