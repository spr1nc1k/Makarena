// ai_injector.js
// Niewykrywalny wstrzykiwacz podpowiedzi AI dla WhiteSolution WebSite

(function() {
    'use strict';

    const MakarenaAI = {
        isPanicMode: false,
        originalPlaceholders: new Map(),
        originalOptionStyles: new Map(),

        // Pobranie pytania
        extractQuestionData: function() {
            if (this.isPanicMode) return null;

            let questionTextEl = document.querySelector('.question_text_content, .question_content, .question-text, .question_text') 
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
        },

        // Aplikowanie podpowiedzi pytania zamkniętego
        applyClosedHint: function(correctIndex) {
            if (this.isPanicMode) return;

            const optionElements = document.querySelectorAll('.question_option_wrapper, .answer_container, .option_wrapper, label.answer, .answer_item');
            if (!optionElements[correctIndex]) return;

            const target = optionElements[correctIndex];
            target.style.fontWeight = '700';
            target.style.letterSpacing = '0.3px';
        },

        // Aplikowanie podpowiedzi pytania otwartego
        applyOpenHint: function(answerText) {
            if (this.isPanicMode) return;

            const input = document.querySelector('textarea, input[type="text"]:not([name*="search"])');
            if (!input) return;

            if (!this.originalPlaceholders.has(input)) {
                this.originalPlaceholders.set(input, input.getAttribute('placeholder') || 'Wprowadź odpowiedź');
            }

            input.setAttribute('placeholder', answerText);
        },

        // Panic Mode
        enablePanicMode: function() {
            this.isPanicMode = true;
            const optionElements = document.querySelectorAll('.question_option_wrapper, .answer_container, label.answer, .answer_item');
            optionElements.forEach(el => {
                el.style.fontWeight = '';
                el.style.letterSpacing = '';
            });

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

        disablePanicMode: function() {
            this.isPanicMode = false;
        }
    };

    // Przypisanie do obiektu window bez możliwości wykrycia przez pętlę Object.keys
    Object.defineProperty(window, 'MakarenaAI', {
        value: MakarenaAI,
        writable: false,
        configurable: true,
        enumerable: false
    });
})();
