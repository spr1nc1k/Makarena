// ai_injector.js
// Niewykrywalny moduł podpowiedzi AI dla Makarena (zerowy ślad w window)

(function() {
    'use strict';

    let isPanicMode = false;
    const originalPlaceholders = new Map();

    function extractQuestionData() {
        if (isPanicMode) return null;

        let questionTextEl = document.querySelector(
            '.question_text_content, .question_content, .question-text, .question_text, .question_wrapper, ' +
            '.question-container, .test-question-content, [class*="question_text"], [class*="question-text"], ' +
            'h1, h2, h3, .question'
        ) || document.body;

        const questionText = questionTextEl ? questionTextEl.innerText.trim().slice(0, 500) : '';

        const optionElements = Array.from(document.querySelectorAll(
            '.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item, ' +
            '.answer-container, .answer-item, div[class*="answer"], div[class*="option"], label[class*="answer"], ' +
            'input[type="radio"], input[type="checkbox"]'
        ));
        
        let options = [];
        if (optionElements.length > 0) {
            optionElements.forEach((el) => {
                let parent = el.closest('.answer_container, .question_option_wrapper, label, li, tr') || el;
                let text = parent.innerText ? parent.innerText.trim() : el.nextSibling ? el.nextSibling.textContent.trim() : '';
                if (text && !options.some(o => o.text === text)) {
                    options.push({ id: options.length, text: text });
                }
            });
        }

        const openInput = document.querySelector('textarea, input[type="text"]:not([name*="search"]), div[contenteditable="true"]');

        return {
            type: options.length > 0 ? 'closed' : (openInput ? 'open' : 'unknown'),
            question: questionText,
            options: options
        };
    }

    function applyClosedHint(correctIndex) {
        if (isPanicMode) return;

        const optionElements = Array.from(document.querySelectorAll(
            '.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item, ' +
            '.answer-container, .answer-item, div[class*="answer"], div[class*="option"], label[class*="answer"]'
        ));
        
        if (!optionElements[correctIndex]) return;

        const target = optionElements[correctIndex];
        
        // Pogrubienie całej opcji
        target.style.fontWeight = '900';
        target.style.color = '#0055ff';
        target.style.letterSpacing = '0.4px';

        // Pogrubienie litery (np. A, B, C, D)
        let labelSpan = target.querySelector('.option_letter, .answer_letter, .letter, [class*="letter"], b, strong, span');
        if (labelSpan) {
            labelSpan.style.fontWeight = '900';
            labelSpan.style.fontSize = '1.15em';
            labelSpan.style.textDecoration = 'underline';
            labelSpan.style.color = '#0055ff';
        }
    }

    function applyOpenHint(answerText) {
        if (isPanicMode) return;

        const inputs = document.querySelectorAll('textarea, input[type="text"]:not([name*="search"]), div[contenteditable="true"]');
        if (!inputs || inputs.length === 0) return;

        inputs.forEach(input => {
            if (!originalPlaceholders.has(input)) {
                originalPlaceholders.set(input, input.getAttribute('placeholder') || 'Wprowadź odpowiedź');
            }

            input.setAttribute('placeholder', '💡 Podpowiedź AI: ' + answerText);
            input.setAttribute('title', 'Sugerowana odpowiedź: ' + answerText);
            input.style.borderColor = '#0055ff';
        });
    }

    function enablePanicMode() {
        isPanicMode = true;
        const optionElements = document.querySelectorAll(
            '.question_option_wrapper, .answer_container, label.answer, .answer_item, ' +
            '.answer-container, .answer-item, div[class*="answer"], div[class*="option"], span'
        );
        optionElements.forEach(el => {
            el.style.fontWeight = '';
            el.style.textDecoration = '';
            el.style.color = '';
            el.style.letterSpacing = '';
        });

        const inputs = document.querySelectorAll('textarea, input[type="text"], div[contenteditable="true"]');
        inputs.forEach(input => {
            if (originalPlaceholders.has(input)) {
                input.setAttribute('placeholder', originalPlaceholders.get(input));
            } else {
                input.setAttribute('placeholder', 'Wprowadź odpowiedź');
            }
            input.style.borderColor = '';
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
