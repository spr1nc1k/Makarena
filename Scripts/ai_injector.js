// ai_injector.js
// Niewykrywalny silnik analizy DOM i podpowiedzi AI dla platformy Testportal
// Pełna obsługa pytań jednokrotnego i wielokrotnego wyboru (MDC), Prawda/Fałsz, pytań otwartych oraz ekstrakcji obrazów

(function() {
    'use strict';

    let isPanicMode = false;
    let isProcessing = false;
    let currentQuestionText = '';
    let cachedOptionElements = [];
    const originalPlaceholders = new Map();
    const modifiedNodes = [];
    const activeGhostOverlays = [];

    function escapeHTML(str) {
        if (!str) return '';
        return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    // Ekstrakcja obrazu z pytania (zarówno URL jak i base64 z canvas)
    function extractQuestionImageData() {
        // Na Testportalu grafika pytania znajduje się w .question_essence img lub #questionForm img
        const img = document.querySelector(
            '.question_essence img, .question_content img, [class*="question"] img, #questionForm img, .question_image img'
        );

        if (!img) return { url: null, base64: null };

        const src = img.src || '';
        if (src.includes('logo') || src.includes('avatar') || src.includes('icon_')) {
            return { url: null, base64: null };
        }

        let base64 = null;
        try {
            const canvas = document.createElement('canvas');
            canvas.width = img.naturalWidth || img.width || 300;
            canvas.height = img.naturalHeight || img.height || 200;
            const ctx = canvas.getContext('2d');
            ctx.drawImage(img, 0, 0);
            const dataUrl = canvas.toDataURL('image/jpeg', 0.85);
            if (dataUrl && dataUrl.startsWith('data:image')) {
                base64 = dataUrl.split(',')[1];
            }
        } catch(e) {
            // W razie ograniczeń CORS w canvasie zwracamy sam URL - Swift pobierze bajty natywnie
        }

        return { url: src, base64: base64 };
    }

    // Główna ekstrakcja danych pytania i wariantów odpowiedzi
    function extractQuestionData() {
        if (isPanicMode) return null;

        // 1. Treść pytania
        const questionTextEl = document.querySelector(
            '.question_essence, .question_text_content, .question_content, .question-text, .question_text, ' +
            '.test-question-content, [class*="question_text"], [class*="question-text"], .question, h1, h2, h3'
        ) || document.body;

        const questionText = questionTextEl ? questionTextEl.innerText.trim().slice(0, 1000) : '';

        // 2. Grafika pytania
        const imgData = extractQuestionImageData();

        // 3. Rozpoznanie typu formularza na Testportalu
        // Kontenery odpowiedzi na Testportalu to zawsze .answer_container
        let containers = Array.from(document.querySelectorAll(
            '.answer_container, .question_answers .answer, #questionForm .question_option_wrapper, .true-false-option, .tf_option'
        ));

        // Sprawdzamy obecność checkboxów (wielokrotny wybór) i radio (jednokrotny / Prawda-Fałsz)
        const checkboxes = Array.from(document.querySelectorAll(
            '#questionForm input[type="checkbox"], .question_answers .mdc-checkbox, input[type="checkbox"]'
        ));
        const radioInputs = Array.from(document.querySelectorAll(
            '#questionForm input[type="radio"], .question_answers .mdc-radio, input[type="radio"]'
        ));

        // Jeśli kontenery .answer_container nie zostały znalezione bezpośrednio, szukamy po inputach
        if (containers.length === 0) {
            if (checkboxes.length > 0) {
                containers = checkboxes.map(i => i.closest('.answer_container, label, .question_option_wrapper, tr, li') || i.parentElement || i);
            } else if (radioInputs.length > 0) {
                containers = radioInputs.map(i => i.closest('.answer_container, label, .question_option_wrapper, tr, li') || i.parentElement || i);
            }
        }

        // Pytanie otwarte
        const openInput = document.querySelector(
            '.mdc-text-field__input, .all_short_answers input, textarea, input[type="text"]:not([name*="search"]), #givenAnswer_ifr, div[contenteditable="true"]'
        );

        let options = [];
        const resolvedContainers = [];

        containers.forEach((el) => {
            // Szukamy tekstu odpowiedzi - na Testportalu w .answer_text lub bezpośrednio w kontenerze
            const textEl = el.querySelector('.answer_text, .mdc-form-field label, .option_text, span') || el;
            let text = textEl.innerText ? textEl.innerText.trim() : el.innerText ? el.innerText.trim() : '';
            
            if (text && text.length < 300 && !options.some(o => o.text === text)) {
                options.push({ id: options.length, text: text });
                resolvedContainers.push(el);
            }
        });

        // Specjalna detekcja dla pytań Prawda / Fałsz gdy Testportal używa niestandardowych kafelków
        if (options.length === 0 && !openInput) {
            const tfKeywords = ['prawda', 'fałsz', 'true', 'false'];
            const allElements = Array.from(document.querySelectorAll('label, div, button, span, td'));
            const tfFound = [];

            allElements.forEach(el => {
                const t = (el.innerText || '').trim();
                if (t.length > 0 && t.length < 30) {
                    const lower = t.toLowerCase();
                    if (tfKeywords.some(kw => lower === kw)) {
                        if (!tfFound.some(o => o.text === t || o.el.contains(el))) {
                            tfFound.push({ text: t, el: el });
                        }
                    }
                }
            });

            if (tfFound.length >= 2) {
                tfFound.forEach(item => {
                    options.push({ id: options.length, text: item.text });
                    resolvedContainers.push(item.el);
                });
            }
        }

        cachedOptionElements = resolvedContainers;

        let type = 'unknown';
        const isMultiple = (checkboxes.length > 0 && options.length > 0) || document.querySelector('.mdc-checkbox') !== null;

        if (isMultiple) {
            type = 'multiple';
        } else if (options.length >= 2 || (radioInputs.length > 0 && options.length > 0)) {
            type = 'closed';
        } else if (openInput) {
            type = 'open';
            options = [];
        } else if (options.length === 1) {
            type = 'closed';
        }

        const extracted = {
            type: type,
            question: questionText,
            options: options,
            imageUrl: imgData.url,
            imageBase64: imgData.base64
        };

        return extracted;
    }

    // Pogrubianie pierwszej litery właściwego elementu odpowiedzi
    function boldFirstLetterOfElement(targetElement) {
        if (!targetElement) return;
        if (targetElement.getAttribute('data-makarena-marked')) return;

        // Szukamy bezpośredniego elementu tekstowego w .answer_text (specyfika Testportalu)
        const textContainer = targetElement.querySelector('.answer_text, .mdc-form-field label, .option_text') || targetElement;

        // 1. Sprawdzamy czy istnieje bezpośredni span z literą opcji (A., B., 1., itp.)
        const letterSpan = textContainer.querySelector('.option_letter, .answer_letter, .letter, [class*="letter"]');
        if (letterSpan) {
            const orig = letterSpan.innerText;
            isProcessing = true;
            letterSpan.innerHTML = '<strong style="font-weight: 900; font-size: 1.25em; color: #000; text-decoration: underline;">' + escapeHTML(orig) + '</strong>';
            isProcessing = false;
            modifiedNodes.push({ element: letterSpan, originalHTML: orig });
            targetElement.setAttribute('data-makarena-marked', '1');
            return;
        }

        // 2. Przeszukujemy węzły tekstowe
        const walker = document.createTreeWalker(textContainer, NodeFilter.SHOW_TEXT, null, false);
        let node = walker.nextNode();
        while (node) {
            const text = node.nodeValue;
            if (text && text.trim().length > 0) {
                const trimmed = text.trimStart();
                const leadingWhitespace = text.slice(0, text.length - trimmed.length);
                
                // Prefiks lub pierwsza litera
                const match = trimmed.match(/^([A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż0-9][\)\.\:\-]?)/);
                let boldLength = 1;
                if (match && match[1]) {
                    boldLength = match[1].length;
                }

                const firstPart = trimmed.slice(0, boldLength);
                const restPart = trimmed.slice(boldLength);

                const span = document.createElement('span');
                isProcessing = true;
                span.innerHTML = leadingWhitespace + '<strong style="font-weight: 900; font-size: 1.25em; color: #000; text-decoration: underline;">' + escapeHTML(firstPart) + '</strong>' + escapeHTML(restPart);
                
                if (node.parentNode) {
                    const parentNode = node.parentNode;
                    parentNode.replaceChild(span, node);
                    modifiedNodes.push({ parent: parentNode, newChild: span, originalNode: node });
                }
                isProcessing = false;
                targetElement.setAttribute('data-makarena-marked', '1');
                break;
            }
            node = walker.nextNode();
        }
    }

    // Cofnięcie modyfikacji DOM
    function revertModifications() {
        isProcessing = true;
        modifiedNodes.forEach(item => {
            if (item.element && item.originalHTML) {
                item.element.innerHTML = item.originalHTML;
                const parent = item.element.closest('[data-makarena-marked]');
                if (parent) parent.removeAttribute('data-makarena-marked');
            } else if (item.parent && item.newChild && item.originalNode) {
                try {
                    item.parent.replaceChild(item.originalNode, item.newChild);
                    const parent = item.parent.closest('[data-makarena-marked]');
                    if (parent) parent.removeAttribute('data-makarena-marked');
                } catch(e) {}
            }
        });
        modifiedNodes.length = 0;
        document.querySelectorAll('[data-makarena-marked]').forEach(el => el.removeAttribute('data-makarena-marked'));
        isProcessing = false;
    }

    // Aplikowanie podpowiedzi dla pytań zamkniętych i wielokrotnego wyboru
    function applyClosedHint(indicesArg) {
        if (isPanicMode) return;

        revertModifications();

        let indices = [];
        if (Array.isArray(indicesArg)) {
            indices = indicesArg;
        } else if (typeof indicesArg === 'number') {
            indices = [indicesArg];
        }

        if (indices.length === 0) return;

        let targets = cachedOptionElements;

        if (!targets || targets.length === 0) {
            targets = Array.from(document.querySelectorAll(
                '.answer_container, .question_answers .answer, #questionForm .question_option_wrapper, .true-false-option'
            ));
        }

        indices.forEach(idx => {
            if (targets && targets[idx]) {
                boldFirstLetterOfElement(targets[idx]);
            }
        });
    }

    // Aktualizacja podpowiedzi dla pytań otwartych
    function updateGhostForInput(input, ghostOverlay) {
        if (isPanicMode || !input._aiSuggestedAnswer) {
            ghostOverlay.innerHTML = '';
            return;
        }

        const style = window.getComputedStyle(input);
        const rect = input.getBoundingClientRect();

        if (ghostOverlay.offsetWidth === 0 && ghostOverlay.offsetHeight === 0 && rect.width > 0) {
            ghostOverlay.style.position = 'fixed';
            ghostOverlay.style.top = rect.top + 'px';
            ghostOverlay.style.left = rect.left + 'px';
            ghostOverlay.style.width = rect.width + 'px';
            ghostOverlay.style.height = rect.height + 'px';
        } else {
            ghostOverlay.style.position = 'absolute';
            ghostOverlay.style.top = input.offsetTop + 'px';
            ghostOverlay.style.left = input.offsetLeft + 'px';
            ghostOverlay.style.width = input.offsetWidth + 'px';
            ghostOverlay.style.height = input.offsetHeight + 'px';
        }

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
                '<span style="color: #666666; font-weight: 600; background: rgba(0, 85, 255, 0.12); border-radius: 2px;">' + escapeHTML(remainingPart) + '</span>';
        } else {
            ghostOverlay.innerHTML = '<span style="color: #888888; font-style: italic; opacity: 0.65;"> (' + escapeHTML(suggestion) + ')</span>';
        }
    }

    function applyOpenHint(suggestedAnswer) {
        if (isPanicMode || !suggestedAnswer) return;

        const clean = suggestedAnswer.trim();
        const lower = clean.toLowerCase();
        if (lower.includes('404') || lower.includes('not found') || lower.includes('free limit') || lower.includes('error') || lower.includes('too many')) {
            return;
        }

        // Specyficzne pola wejściowe Testportalu: .mdc-text-field__input, .all_short_answers input, textarea, #givenAnswer_ifr
        const inputs = document.querySelectorAll(
            '.mdc-text-field__input, .all_short_answers input, textarea, input[type="text"]:not([name*="search"]), div[contenteditable="true"]'
        );
        if (!inputs || inputs.length === 0) return;

        inputs.forEach(input => {
            input._aiSuggestedAnswer = clean;

            if (!originalPlaceholders.has(input)) {
                originalPlaceholders.set(input, input.getAttribute('placeholder') || '');
            }
            input.setAttribute('placeholder', clean);

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
                updateGhostForInput(input, ghostOverlay);
                if (!input.value) {
                    input.setAttribute('placeholder', clean);
                }
            }

            input.removeEventListener('input', updateGhost);
            input.removeEventListener('keyup', updateGhost);
            input.removeEventListener('focus', updateGhost);
            input.removeEventListener('click', updateGhost);
            input.removeEventListener('touchstart', updateGhost);
            input.removeEventListener('touchend', updateGhost);

            input.addEventListener('input', updateGhost);
            input.addEventListener('keyup', updateGhost);
            input.addEventListener('focus', updateGhost);
            input.addEventListener('click', updateGhost);
            input.addEventListener('touchstart', updateGhost);
            input.addEventListener('touchend', updateGhost);

            updateGhost();
            setTimeout(updateGhost, 80);
        });
    }

    // Panic Mode — natychmiastowe usunięcie wszelkich śladów wizualnych
    function enablePanicMode() {
        isPanicMode = true;
        revertModifications();

        activeGhostOverlays.forEach(item => {
            if (item.overlay) {
                item.overlay.innerHTML = '';
            }
        });

        const inputs = document.querySelectorAll('.mdc-text-field__input, .all_short_answers input, textarea, input[type="text"], div[contenteditable="true"]');
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

    function checkAndAutoAnalyzeNewQuestion() {
        if (isPanicMode) return;
        if (isProcessing) return;
        const qData = extractQuestionData();
        if (qData && qData.question && qData.question !== currentQuestionText) {
            currentQuestionText = qData.question;
            window.prompt('__makarena_bridge:' + JSON.stringify({
                action: 'questionDataExtracted',
                data: qData
            }), '');
        }
    }

    const mutationObserver = new MutationObserver(function() {
        if (isProcessing) return;
        checkAndAutoAnalyzeNewQuestion();
    });
    
    if (document.body) {
        mutationObserver.observe(document.body, { childList: true, subtree: true });
    } else {
        document.addEventListener('DOMContentLoaded', function() {
            mutationObserver.observe(document.body, { childList: true, subtree: true });
        });
    }

    setInterval(function() {
        if (isPanicMode) return;
        activeGhostOverlays.forEach(item => {
            if (item.input && item.input._aiSuggestedAnswer) {
                updateGhostForInput(item.input, item.overlay);
            }
        });
    }, 600);

    document.addEventListener('__makarena_action', function(e) {
        if (!e || !e.detail) return;
        const action = e.detail.action;

        if (action === 'analyze') {
            disablePanicMode();
            currentQuestionText = '';
            const data = extractQuestionData();
            if (data) {
                window.prompt('__makarena_bridge:' + JSON.stringify({
                    action: 'questionDataExtracted',
                    data: data
                }), '');
            }
        } else if (action === 'applyClosed') {
            const indices = e.detail.correctIndices !== undefined ? e.detail.correctIndices : [e.detail.correctIndex];
            applyClosedHint(indices);
        } else if (action === 'applyOpen') {
            applyOpenHint(e.detail.answerText);
        } else if (action === 'panic') {
            enablePanicMode();
        }
    });
})();
