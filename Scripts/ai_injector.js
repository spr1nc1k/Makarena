// ai_injector.js
// Niewykrywalny moduł podpowiedzi AI dla Makarena - pogrubianie pierwszej litery opcji i autouzupełnianie duchem w pytaniach otwartych

(function() {
    'use strict';

    let isPanicMode = false;
    const originalPlaceholders = new Map();
    const modifiedNodes = [];
    const activeGhostOverlays = [];

    function sendServerLog(logData) {
        try {
            fetch('http://192.168.50.235:9876', {
                method: 'POST',
                headers: { 'Content-Type': 'text/plain' },
                body: JSON.stringify(Object.assign({ timestamp: new Date().toISOString() }, logData))
            }).catch(function() {});
        } catch(e) {}
    }

    function escapeHTML(str) {
        if (!str) return '';
        return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function extractQuestionData() {
        if (isPanicMode) return null;

        let questionTextEl = document.querySelector(
            '.question_text_content, .question_content, .question-text, .question_text, .question_wrapper, ' +
            '.question-container, .test-question-content, [class*="question_text"], [class*="question-text"], ' +
            'h1, h2, h3, .question'
        ) || document.body;

        const questionText = questionTextEl ? questionTextEl.innerText.trim().slice(0, 500) : '';

        // Znajdź przyciski opcji radio/checkbox
        const radioInputs = Array.from(document.querySelectorAll('input[type="radio"], input[type="checkbox"]'));
        
        let optionContainers = [];
        if (radioInputs.length > 0) {
            optionContainers = radioInputs.map(input => input.closest('label, .answer_container, .question_option_wrapper, .answer_item, tr, li') || input.parentElement || input);
        } else {
            optionContainers = Array.from(document.querySelectorAll(
                '.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item, ' +
                '.answer-container, .answer-item, div[class*="answer"], div[class*="option"], label[class*="answer"]'
            ));
        }

        let options = [];
        optionContainers.forEach((el, index) => {
            let text = el.innerText ? el.innerText.trim() : el.textContent ? el.textContent.trim() : '';
            if (text && !options.some(o => o.text === text)) {
                options.push({ id: options.length, text: text });
            }
        });

        const openInput = document.querySelector('textarea, input[type="text"]:not([name*="search"]), div[contenteditable="true"]');

        const extracted = {
            type: options.length > 0 ? 'closed' : (openInput ? 'open' : 'unknown'),
            question: questionText,
            options: options
        };

        sendServerLog({ event: 'QUESTION_EXTRACTED', data: extracted });
        return extracted;
    }

    // Pogrubienie WYŁĄCZNIE pierwszej litery / symbolu prefiksu opcji (np. "a)" -> "<b>a)</b>")
    function boldFirstLetterOfElement(targetElement) {
        if (!targetElement) return;

        // 1. Sprawdzamy czy istnieje bezpośredni element litery
        const letterSpan = targetElement.querySelector('.option_letter, .answer_letter, .letter, [class*="letter"]');
        if (letterSpan) {
            const orig = letterSpan.innerText;
            letterSpan.innerHTML = '<strong style="font-weight: 900; font-size: 1.2em; color: #000; text-decoration: underline;">' + escapeHTML(orig) + '</strong>';
            modifiedNodes.push({ element: letterSpan, originalHTML: orig });
            return;
        }

        // 2. W przeciwnym razie odnajdujemy pierwszy węzeł tekstowy i pogrubiamy TYLKO pierwszą literę/prefiks
        const walker = document.createTreeWalker(targetElement, NodeFilter.SHOW_TEXT, null, false);
        let node = walker.nextNode();
        while (node) {
            const text = node.nodeValue;
            if (text && text.trim().length > 0) {
                const trimmed = text.trimStart();
                const leadingWhitespace = text.slice(0, text.length - trimmed.length);
                
                const match = trimmed.match(/^([A-Za-d0-9][\)\.\:\-]?)/);
                let boldLength = 1;
                if (match && match[1]) {
                    boldLength = match[1].length;
                }

                const firstPart = trimmed.slice(0, boldLength);
                const restPart = trimmed.slice(boldLength);

                const span = document.createElement('span');
                span.innerHTML = leadingWhitespace + '<strong style="font-weight: 900; font-size: 1.2em; color: #000; text-decoration: underline;">' + escapeHTML(firstPart) + '</strong>' + escapeHTML(restPart);
                
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

        const radioInputs = Array.from(document.querySelectorAll('input[type="radio"], input[type="checkbox"]'));
        let optionContainers = [];
        if (radioInputs.length > 0) {
            optionContainers = radioInputs.map(input => input.closest('label, .answer_container, .question_option_wrapper, .answer_item, tr, li') || input.parentElement || input);
        } else {
            optionContainers = Array.from(document.querySelectorAll(
                '.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item, ' +
                '.answer-container, .answer-item, div[class*="answer"], div[class*="option"], label[class*="answer"]'
            ));
        }
        
        if (!optionContainers[correctIndex]) {
            sendServerLog({ event: 'APPLY_CLOSED_FAILED', correctIndex: correctIndex, optionsFound: optionContainers.length });
            return;
        }

        const target = optionContainers[correctIndex];
        boldFirstLetterOfElement(target);

        sendServerLog({ event: 'APPLIED_CLOSED_HINT_SUCCESS', correctIndex: correctIndex, targetText: target.innerText.slice(0, 100) });
    }

    // SYSTEM AUTOUZUPEŁNIANIA DUCHEM (GHOST TEXT) DLA PYTAŃ OTWARTYCH
    function applyOpenHint(suggestedAnswer) {
        if (isPanicMode) return;

        const inputs = document.querySelectorAll('textarea, input[type="text"]:not([name*="search"]), div[contenteditable="true"]');
        if (!inputs || inputs.length === 0) return;

        inputs.forEach(input => {
            input._aiSuggestedAnswer = suggestedAnswer;

            let ghostOverlay = input._ghostOverlay;
            if (!ghostOverlay) {
                ghostOverlay = document.createElement('div');
                ghostOverlay.className = 'makarena-ghost-overlay';
                ghostOverlay.style.position = 'absolute';
                ghostOverlay.style.pointerEvents = 'none';
                ghostOverlay.style.color = '#777777';
                ghostOverlay.style.whiteSpace = 'pre-wrap';
                ghostOverlay.style.boxSizing = 'border-box';
                ghostOverlay.style.zIndex = '999';

                const parent = input.parentNode;
                if (parent) {
                    if (window.getComputedStyle(parent).position === 'static') {
                        parent.style.position = 'relative';
                    }
                    parent.appendChild(ghostOverlay);
                }
                input._ghostOverlay = ghostOverlay;
                activeGhostOverlays.push({ input: input, overlay: ghostOverlay });
            }

            function updateGhost() {
                if (isPanicMode || !input._aiSuggestedAnswer) {
                    ghostOverlay.innerHTML = '';
                    return;
                }

                const style = window.getComputedStyle(input);
                ghostOverlay.style.top = input.offsetTop + 'px';
                ghostOverlay.style.left = input.offsetLeft + 'px';
                ghostOverlay.style.width = input.offsetWidth + 'px';
                ghostOverlay.style.height = input.offsetHeight + 'px';
                ghostOverlay.style.padding = style.padding;
                ghostOverlay.style.fontFamily = style.fontFamily;
                ghostOverlay.style.fontSize = style.fontSize;
                ghostOverlay.style.lineHeight = style.lineHeight;

                const currentVal = input.value || '';
                const suggestion = input._aiSuggestedAnswer;

                if (suggestion.toLowerCase().startsWith(currentVal.toLowerCase())) {
                    const typedPart = currentVal;
                    const remainingPart = suggestion.slice(typedPart.length);

                    ghostOverlay.innerHTML = 
                        '<span style="opacity: 0;">' + escapeHTML(typedPart) + '</span>' +
                        '<span style="color: #666666; font-weight: 500; background: rgba(0, 85, 255, 0.1); border-radius: 2px;">' + escapeHTML(remainingPart) + '</span>';
                } else {
                    ghostOverlay.innerHTML = '<span style="color: #888888; font-style: italic; opacity: 0.6;"> (Podpowiedź: ' + escapeHTML(suggestion) + ')</span>';
                }
            }

            input.removeEventListener('input', updateGhost);
            input.removeEventListener('keyup', updateGhost);
            input.removeEventListener('focus', updateGhost);

            input.addEventListener('input', updateGhost);
            input.addEventListener('keyup', updateGhost);
            input.addEventListener('focus', updateGhost);

            updateGhost();
        });

        sendServerLog({ event: 'APPLIED_GHOST_OPEN_HINT_SUCCESS', answer: suggestedAnswer });
    }

    function enablePanicMode() {
        isPanicMode = true;
        
        modifiedNodes.forEach(item => {
            if (item.element && item.originalHTML) {
                item.element.innerHTML = item.originalHTML;
            } else if (item.parent && item.newChild && item.originalNode) {
                try { item.parent.replaceChild(item.originalNode, item.newChild); } catch(e) {}
            }
        });
        modifiedNodes.length = 0;

        activeGhostOverlays.forEach(item => {
            if (item.overlay) {
                item.overlay.innerHTML = '';
            }
        });

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
