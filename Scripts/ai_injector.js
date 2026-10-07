// ai_injector.js
// Skrypt odpowiedzialny za ekstrakcję treści pytania z Testportal,
// aplikowanie subtelnych podpowiedzi oraz natychmiastowe ukrywanie w trybie Panic.

(function() {
    window.MakarenaAI = {
        isPanicMode: false,
        originalPlaceholders: new Map(),
        originalOptionHTML: new Map(),

        // Pobranie aktualnego pytania i opcji ze strony Testportal
        extractQuestionData: function() {
            if (this.isPanicMode) return null;

            // Szukanie pytania w strukturze Testportal
            let questionTextEl = document.querySelector('.question_text_content, .question_content, .question-text, .question_text') 
                || document.querySelector('h1, h2, h3, .question');

            if (!questionTextEl) {
                // Alternatywne szukanie bloku pytania
                let mainContent = document.querySelector('form') || document.body;
                questionTextEl = mainContent;
            }

            const questionText = questionTextEl ? questionTextEl.innerText.trim() : '';

            // Szukanie opcji (pytanie zamknięte)
            const optionElements = Array.from(document.querySelectorAll('.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item, input[type="radio"], input[type="checkbox"]'));
            
            let options = [];
            let optionNodes = [];

            if (optionElements.length > 0) {
                optionElements.forEach((el, index) => {
                    // Znajdź kontener pojedynczej opcji
                    let parent = el.closest('.answer_container, .question_option_wrapper, label, li') || el;
                    let text = parent.innerText ? parent.innerText.trim() : el.nextSibling ? el.nextSibling.textContent.trim() : '';
                    if (text) {
                        options.push({ id: index, text: text });
                        optionNodes.push(parent);
                    }
                });
            }

            // Szukanie pól otwartych
            const openInput = document.querySelector('textarea, input[type="text"]:not([name*="search"])');

            const result = {
                type: options.length > 0 ? 'closed' : (openInput ? 'open' : 'unknown'),
                question: questionText,
                options: options
            };

            return result;
        },

        // Aplikowanie podpowiedzi dla pytania zamkniętego
        applyClosedHint: function(correctIndex) {
            if (this.isPanicMode) return;

            const optionElements = document.querySelectorAll('.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item');
            if (!optionElements[correctIndex]) return;

            const target = optionElements[correctIndex];
            
            // Zachowaj oryginalny HTML przed modyfikacją
            if (!this.originalOptionHTML.has(target)) {
                this.originalOptionHTML.set(target, target.innerHTML);
            }

            // Subtelne pogrubienie pierwszej litery / przedrostka opcji lub dodanie pogrubienia
            let html = target.innerHTML;
            // Szukamy litery np. A), a), 1. na początku i pogrubiamy jej pierwszą literę
            target.style.fontWeight = '700';
            target.style.letterSpacing = '0.3px';
            
            console.log('[Makarena Stealth] Wyznaczono odpowiedź zamkniętą index:', correctIndex);
        },

        // Aplikowanie podpowiedzi dla pytania otwartego
        applyOpenHint: function(answerText) {
            if (this.isPanicMode) return;

            const input = document.querySelector('textarea, input[type="text"]:not([name*="search"])');
            if (!input) return;

            if (!this.originalPlaceholders.has(input)) {
                this.originalPlaceholders.set(input, input.getAttribute('placeholder') || 'Wprowadź odpowiedź');
            }

            // Ustawiamy placeholder na wygenerowaną odpowiedź
            input.setAttribute('placeholder', answerText);

            // Reakcja na kliknięcie/focus - zachowanie podpowiedzi w tle
            const updatePlaceholder = () => {
                if (!this.isPanicMode && !input.value) {
                    input.setAttribute('placeholder', answerText);
                }
            };

            input.addEventListener('focus', updatePlaceholder);
            input.addEventListener('click', updatePlaceholder);

            console.log('[Makarena Stealth] Wyznaczono odpowiedź otwartą.');
        },

        // TRYB "NAUCZYCIEL PATRZY" (PANIC MODE)
        enablePanicMode: function() {
            this.isPanicMode = true;
            console.log('[Makarena Stealth] PANIC MODE AKTYWOWANY - Przywracanie oryginalnego stanu.');

            // Przywróć oryginalne HTML opcji
            this.originalOptionHTML.forEach((originalHTML, node) => {
                if (node) {
                    node.style.fontWeight = '';
                    node.style.letterSpacing = '';
                }
            });
            this.originalOptionHTML.clear();

            // Przywróć oryginalne style dla wszystkich opcji
            const optionElements = document.querySelectorAll('.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item');
            optionElements.forEach(el => {
                el.style.fontWeight = '';
                el.style.letterSpacing = '';
            });

            // Przywróć oryginalne placeholdery
            const inputs = document.querySelectorAll('textarea, input[type="text"]');
            inputs.forEach(input => {
                if (this.originalPlaceholders.has(input)) {
                    input.setAttribute('placeholder', this.originalPlaceholders.get(input));
                } else {
                    input.setAttribute('placeholder', 'Wprowadź odpowiedź');
                }
            });
            this.originalPlaceholders.clear();
        },

        // Wyłączenie trybu Panic Mode
        disablePanicMode: function() {
            this.isPanicMode = false;
            console.log('[Makarena Stealth] Panic Mode wyłączony.');
        }
    };
})();
