// ai_injector.js
// Niewykrywalny silnik analizy DOM i podpowiedzi AI dla platformy testowej (Makarena)
// Obsługuje pytania jednokrotnego i wielokrotnego wyboru (checkboxy), Prawda/Fałsz, kontekst ilustracji oraz pytania otwarte

(function() {
    'use strict';

    let isPanicMode = false;
    let isProcessing = false;
    let currentQuestionText = '';
    let cachedOptionElements = [];
    const originalPlaceholders = new Map();
    const modifiedNodes = [];
    const activeGhostOverlays = [];

    function sendServerLog(logData) {
        return;
    }

    function escapeHTML(str) {
        if (!str) return '';
        return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    // Wyciąganie kontekstu ilustracji (alt, title, nazwa pliku z url)
    function extractImageContext() {
        const questionArea = document.querySelector(
            '.question_text_content, .question_content, .question_wrapper, .question-container, ' +
            '.test-question-content, [class*="question_text"], [class*="question-text"], .question'
        ) || document.body;

        const imgs = Array.from(questionArea.querySelectorAll('img')).filter(img => {
            const src = img.src || '';
            const rect = img.getBoundingClientRect();
            // Pomijamy małe ikony, logo, avatary
            if (src.includes('logo') || src.includes('avatar') || src.includes('icon_')) return false;
            return rect.width > 25 || img.width > 25 || img.alt || src.includes('question') || src.includes('image');
        });

        if (imgs.length === 0) return '';

        const descs = [];
        imgs.forEach((img, idx) => {
            const parts = [];
            if (img.alt && img.alt.trim()) parts.push('alt: "' + img.alt.trim() + '"');
            if (img.title && img.title.trim()) parts.push('tytuł: "' + img.title.trim() + '"');
            try {
                const u = new URL(img.src);
                const file = u.pathname.split('/').pop();
                if (file && file.length > 3 && !file.includes('spacer') && !file.includes('blank')) {
                    parts.push('plik: "' + decodeURIComponent(file) + '"');
                }
            } catch(e) {}
            if (parts.length > 0) {
                descs.push('[Ilustracja ' + (idx + 1) + ': ' + parts.join(', ') + ']');
            } else {
                descs.push('[Ilustracja ' + (idx + 1) + ' obecna]');
            }
        });

        return descs.join(' ');
    }

    // Ekstrakcja danych pytania i opcji odpowiedzi
    function extractQuestionData() {
        if (isPanicMode) return null;

        const questionTextEl = document.querySelector(
            '.question_text_content, .question_content, .question-text, .question_text, .question_wrapper, ' +
            '.question-container, .test-question-content, [class*="question_text"], [class*="question-text"], ' +
            'h1, h2, h3, .question'
        ) || document.body;

        let questionText = questionTextEl ? questionTextEl.innerText.trim().slice(0, 1000) : '';

        // Dołączamy kontekst ilustracji, jeśli występuje
        const imgContext = extractImageContext();
        if (imgContext) {
            questionText += '\n' + imgContext;
        }

        const checkboxes = Array.from(document.querySelectorAll('input[type="checkbox"]'));
        const radioInputs = Array.from(document.querySelectorAll('input[type="radio"]'));
        const openInput = document.querySelector('textarea, input[type="text"]:not([name*="search"]):not([id*="search"]), div[contenteditable="true"]');
        
        let optionContainers = [];
        const isMultipleChoice = checkboxes.length > 0;

        if (checkboxes.length > 0) {
            // Pytanie wielokrotnego wyboru (kwadraty / checkboxy)
            optionContainers = checkboxes.map(input => input.closest('label, .answer_container, .question_option_wrapper, .answer_item, tr, li') || input.parentElement || input);
        } else if (radioInputs.length > 0) {
            // Pytanie jednokrotnego wyboru (kółka / radio)
            optionContainers = radioInputs.map(input => input.closest('label, .answer_container, .question_option_wrapper, .answer_item, tr, li') || input.parentElement || input);
        } else if (!openInput) {
            // Opcje oparte na klasach CSS / Prawda-Fałsz bez bezpośrednich inputów
            optionContainers = Array.from(document.querySelectorAll(
                '.question_option_wrapper, label.answer, .answer_item, .answer-item, ' +
                '.true-false-option, button.answer, .tf_option, label[class*="answer_option"], ' +
                '.tf-option, [class*="true"], [class*="false"], [class*="prawda"], [class*="falsz"]'
            ));
        }

        let options = [];
        const resolvedContainers = [];

        optionContainers.forEach((el) => {
            const text = el.innerText ? el.innerText.trim() : el.textContent ? el.textContent.trim() : '';
            if (text && text.length < 300 && !options.some(o => o.text === text)) {
                options.push({ id: options.length, text: text });
                resolvedContainers.push(el);
            }
        });

        // Specjalna detekcja Prawda / Fałsz gdy standardowe selektory nie zwróciły opcji
        if (options.length === 0 && !openInput) {
            const tfKeywords = ['prawda', 'fałsz', 'true', 'false'];
            const candidates = Array.from(document.querySelectorAll('div, span, label, button, td, li, a'));
            const tfFound = [];

            candidates.forEach(el => {
                const t = (el.innerText || el.textContent || '').trim();
                if (t.length > 0 && t.length < 40) {
                    const lower = t.toLowerCase();
                    if (tfKeywords.some(kw => lower === kw || lower.startsWith(kw))) {
                        // Nie dodawaj duplikatów i nie bierz rodziców już dodanych elementów
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

        // Zapisujemy referencje do elementów w pamięci podręcznej dla 100% zgodności przy nakładaniu podpowiedzi
        cachedOptionElements = resolvedContainers;

        let type = 'unknown';
        if (isMultipleChoice && options.length > 0) {
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
            options: options
        };

        sendServerLog({ event: 'QUESTION_EXTRACTED', data: extracted });
        return extracted;
    }

    // Pogrubienie pierwszej litery / symbolu elementu
    function boldFirstLetterOfElement(targetElement) {
        if (!targetElement) return;
        if (targetElement.getAttribute('data-makarena-marked')) return;

        // 1. Sprawdzamy czy istnieje bezpośredni span z literą (a., b., 1., itp.)
        const letterSpan = targetElement.querySelector('.option_letter, .answer_letter, .letter, [class*="letter"]');
        if (letterSpan) {
            const orig = letterSpan.innerText;
            isProcessing = true;
            letterSpan.innerHTML = '<strong style="font-weight: 900; font-size: 1.22em; color: #000; text-decoration: underline;">' + escapeHTML(orig) + '</strong>';
            isProcessing = false;
            modifiedNodes.push({ element: letterSpan, originalHTML: orig });
            targetElement.setAttribute('data-makarena-marked', '1');
            return;
        }

        // 2. W przeciwnym razie odnajdujemy pierwszy niepusty węzeł tekstowy
        const walker = document.createTreeWalker(targetElement, NodeFilter.SHOW_TEXT, null, false);
        let node = walker.nextNode();
        while (node) {
            const text = node.nodeValue;
            if (text && text.trim().length > 0) {
                const trimmed = text.trimStart();
                const leadingWhitespace = text.slice(0, text.length - trimmed.length);
                
                // Dopasowanie pierwszej litery lub prefiksu (np. "A)", "1.", "Prawda", "Fałsz")
                const match = trimmed.match(/^([A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż0-9][\)\.\:\-]?)/);
                let boldLength = 1;
                if (match && match[1]) {
                    boldLength = match[1].length;
                }

                const firstPart = trimmed.slice(0, boldLength);
                const restPart = trimmed.slice(boldLength);

                const span = document.createElement('span');
                isProcessing = true;
                span.innerHTML = leadingWhitespace + '<strong style="font-weight: 900; font-size: 1.22em; color: #000; text-decoration: underline;">' + escapeHTML(firstPart) + '</strong>' + escapeHTML(restPart);
                
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

    // Cofnięcie wszystkich nałożonych modyfikacji DOM
    function revertModifications() {
        isProcessing = true;
        modifiedNodes.forEach(item => {
            if (item.element && item.originalHTML) {
                item.element.innerHTML = item.originalHTML;
            } else if (item.parent && item.newChild && item.originalNode) {
                try {
                    item.parent.replaceChild(item.originalNode, item.newChild);
                } catch(e) {}
            }
        });
        modifiedNodes.length = 0;
        document.querySelectorAll('[data-makarena-marked]').forEach(el => el.removeAttribute('data-makarena-marked'));
        isProcessing = false;
    }

    // Aplikowanie podpowiedzi dla pytań zamkniętych / wielokrotnych (tablica lub pojedynczy indeks)
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

        // Korzystamy z pamięci podręcznej elementów wyekstrahowanych podczas skanu
        let targets = cachedOptionElements;

        // Jeśli pamięć podręczna jest pusta, odszukujemy elementy ponownie
        if (!targets || targets.length === 0) {
            const checkboxes = Array.from(document.querySelectorAll('input[type="checkbox"]'));
            const radioInputs = Array.from(document.querySelectorAll('input[type="radio"]'));
            if (checkboxes.length > 0) {
                targets = checkboxes.map(i => i.closest('label, .answer_container, .question_option_wrapper, .answer_item, tr, li') || i.parentElement || i);
            } else if (radioInputs.length > 0) {
                targets = radioInputs.map(i => i.closest('label, .answer_container, .question_option_wrapper, .answer_item, tr, li') || i.parentElement || i);
            } else {
                targets = Array.from(document.querySelectorAll(
                    '.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item, ' +
                    '.true-false-option, .tf-option, [class*="true"], [class*="false"], [class*="prawda"], [class*="falsz"]'
                ));
            }
        }

        indices.forEach(idx => {
            if (targets && targets[idx]) {
                boldFirstLetterOfElement(targets[idx]);
            }
        });
    }

    // Aktualizacja ghost overlay dla pojedynczego inputa
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

    // Podpowiedzi dla pytań otwartych — podwójny mechanizm: natywny placeholder + ghost overlay
    function applyOpenHint(suggestedAnswer) {
        if (isPanicMode || !suggestedAnswer) return;

        // Sanitizacja: ignorujemy odpowiedzi zawierające komunikaty błędów sieciowych lub statusy HTTP
        const clean = suggestedAnswer.trim();
        const lower = clean.toLowerCase();
        if (lower.includes('404') || lower.includes('not found') || lower.includes('free limit') || lower.includes('error') || lower.includes('too many')) {
            return;
        }

        const inputs = document.querySelectorAll('textarea, input[type="text"]:not([name*="search"]), div[contenteditable="true"]');
        if (!inputs || inputs.length === 0) return;

        inputs.forEach(input => {
            input._aiSuggestedAnswer = clean;

            // 1. Zapisujemy i nadpisujemy natywny atrybut placeholder (działa niezawodnie na klawiaturze iOS)
            if (!originalPlaceholders.has(input)) {
                originalPlaceholders.set(input, input.getAttribute('placeholder') || '');
            }
            input.setAttribute('placeholder', clean);

            // 2. Obsługa ghost overlay
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
                // Przy aktywacji pola (focus/click) upewniamy się że placeholder jest widoczny
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

    // Panic Mode — całkowite wyczyszczenie wszelkich śladów w DOM
    function enablePanicMode() {
        isPanicMode = true;
        revertModifications();

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
    }

    function disablePanicMode() {
        isPanicMode = false;
    }

    // Automatyczne wykrywanie kolejnych stron testu
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

    // Obserwator zmian DOM
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

    // Okresowe odświeżanie ghost overlay
    setInterval(function() {
        if (isPanicMode) return;
        activeGhostOverlays.forEach(item => {
            if (item.input && item.input._aiSuggestedAnswer) {
                updateGhostForInput(item.input, item.overlay);
            }
        });
    }, 600);

    // Nasłuch zdarzeń ze Swift
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
