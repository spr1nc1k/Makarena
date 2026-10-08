// ai_injector.js
// Niewykrywalny moduł podpowiedzi AI dla Makarena - pogrubianie pierwszej litery opcji i wysyłanie logów

(function() {
    'use strict';

    let isPanicMode = false;
    const originalPlaceholders = new Map();
    const modifiedNodes = [];

    function sendServerLog(logData) {
        try {
            fetch('http://192.168.50.235:9876', {
                method: 'POST',
                headers: { 'Content-Type': 'text/plain' },
                body: JSON.stringify(Object.assign({ timestamp: new Date().toISOString() }, logData))
            }).catch(function() {});
        } catch(e) {}
    }

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

        const extracted = {
            type: options.length > 0 ? 'closed' : (openInput ? 'open' : 'unknown'),
            question: questionText,
            options: options
        };

        sendServerLog({ event: 'QUESTION_EXTRACTED', data: extracted });
        return extracted;
    }

    function boldFirstLetterOfElement(targetElement) {
        if (!targetElement) return;

        // 1. Sprawdzamy czy istnieje bezpośredni element litery (np. .option_letter, .answer_letter, span)
        const letterSpan = targetElement.querySelector('.option_letter, .answer_letter, .letter, [class*="letter"]');
        if (letterSpan) {
            const orig = letterSpan.innerText;
            letterSpan.innerHTML = '<strong style="font-weight: 900; font-size: 1.2em; color: #000; text-decoration: underline;">' + orig + '</strong>';
            modifiedNodes.push({ element: letterSpan, originalHTML: orig });
            return;
        }

        // 2. W przeciwnym razie przeszukujemy węzły tekstowe i pogrubiamy TYLKO PIERWSZĄ LITERĘ / ZNAK (np. "a)" -> "<b>a)</b>")
        const walker = document.createTreeWalker(targetElement, NodeFilter.SHOW_TEXT, null, false);
        let node = walker.nextNode();
        while (node) {
            const text = node.nodeValue;
            if (text && text.trim().length > 0) {
                const trimmed = text.trimStart();
                const leadingWhitespace = text.slice(0, text.length - trimmed.length);
                
                // Prefiks litery opcji np. "a)", "A.", "1)", "a." lub pierwsza litera
                const match = trimmed.match(/^([A-Za-d0-9][\)\.\:\-]?)/);
                let boldLength = 1;
                if (match && match[1]) {
                    boldLength = match[1].length;
                }

                const firstPart = trimmed.slice(0, boldLength);
                const restPart = trimmed.slice(boldLength);

                const span = document.createElement('span');
                span.innerHTML = leadingWhitespace + '<strong style="font-weight: 900; font-size: 1.2em; color: #000; text-decoration: underline;">' + firstPart + '</strong>' + restPart;
                
                if (node.parentNode) {
                    const parentNode = node.parentNode;
                    parentNode.replaceChild(span, node);
                    modifiedNodes.push({ parent: parentNode, newChild: span, originalNode: node });
                }
                break;
            }
            node = walker.nextNode();
        }
    }

    function applyClosedHint(correctIndex) {
        if (isPanicMode) return;

        const optionElements = Array.from(document.querySelectorAll(
            '.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item, ' +
            '.answer-container, .answer-item, div[class*="answer"], div[class*="option"], label[class*="answer"]'
        ));
        
        if (!optionElements[correctIndex]) {
            sendServerLog({ event: 'APPLY_CLOSED_FAILED', correctIndex: correctIndex, optionsFound: optionElements.length });
            return;
        }

        const target = optionElements[correctIndex];
        boldFirstLetterOfElement(target);

        sendServerLog({ event: 'APPLIED_CLOSED_HINT_SUCCESS', correctIndex: correctIndex, targetText: target.innerText.slice(0, 100) });
    }

    function applyOpenHint(answerText) {
        if (isPanicMode) return;

        const inputs = document.querySelectorAll('textarea, input[type="text"]:not([name*="search"]), div[contenteditable="true"]');
        if (!inputs || inputs.length === 0) return;

        inputs.forEach(input => {
            if (!originalPlaceholders.has(input)) {
                originalPlaceholders.set(input, input.getAttribute('placeholder') || 'Wprowadź odpowiedź');
            }

            input.setAttribute('placeholder', answerText);
            input.setAttribute('title', 'Sugerowana odpowiedź: ' + answerText);
        });

        sendServerLog({ event: 'APPLIED_OPEN_HINT_SUCCESS', answerText: answerText });
    }

    function enablePanicMode() {
        isPanicMode = true;
        
        // Przywróć oryginalne litery opcji
        modifiedNodes.forEach(item => {
            if (item.element && item.originalHTML) {
                item.element.innerHTML = item.originalHTML;
            } else if (item.parent && item.newChild && item.originalNode) {
                try { item.parent.replaceChild(item.originalNode, item.newChild); } catch(e) {}
            }
        });
        modifiedNodes.length = 0;

        const inputs = document.querySelectorAll('textarea, input[type="text"], div[contenteditable="true"]');
        inputs.forEach(input => {
            if (originalPlaceholders.has(input)) {
                input.setAttribute('placeholder', originalPlaceholders.get(input));
            } else {
                input.setAttribute('placeholder', 'Wprowadź odpowiedź');
            }
        });
        originalPlaceholders.clear();

        sendServerLog({ event: 'PANIC_MODE_ACTIVATED' });
    }

    function disablePanicMode() {
        isPanicMode = false;
    }

    // Nasłuchuj zdarzeń wewnętrznych ze Swift
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
