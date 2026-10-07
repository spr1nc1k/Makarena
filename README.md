# Makarena Browser - Dyskretna Przeglądarka iOS z Bypassem Testportal

Przeglądarka dedykowana na system iOS służąca do automatycznego omijania zabezpieczeń **Testportal.pl** oraz generowania dyskretnych podpowiedzi AI przy użyciu bezpłatnego modelu **Gemini 2.0 Flash**.

---

## 🚀 Główne Funkcje

1. **Omijanie Zabezpieczeń Testportal (Anti-Cheat Bypass):**
   * Automatycznie neutralizuje zdarzenia `blur`, `focus`, `visibilitychange` oraz `pagehide`.
   * Testportal uznaje, że użytkownik nieustannie przebywa na karcie i w formularzu.

2. **Akwizycja i Analiza Pytania (Tryb AI Solve):**
   * **Aktywacja:** Szybkie dwukrotne naciśnięcie **GŁOŚNOŚĆ W DÓŁ** (lub dwukrotny klik w prawy dolny róg).
   * **Pytania Zamknięte:** Subtelne pogrubienie pierwszej litery prawidłowej odpowiedzi (np. `A)` lub `1.`).
   * **Pytania Otwarte:** Wyznaczenie zwięzłej odpowiedzi i umieszczenie jej w `placeholderze` pola tekstowego (widocznej dopiero po kliknięciu pola).

3. **Tryb "Nauczyciel Patrzy" (Panic Mode / Camouflage):**
   * **Aktywacja:** Szybkie dwukrotne naciśnięcie **GŁOŚNOŚĆ W GÓRĘ** (lub dwukrotny klik w lewy dolny róg).
   * Natychmiast usuwa wszelkie pogrubienia, resetuje placeholdery i ukrywa podpowiedzi.

4. **Automatyczne Aktualizacje (Auto-Update Engine):**
   * Moduł sprawdzania wersji w **Ustawieniach** połączony z Twoim serwerem HTTP / Cloudflare Tunnel / SSH (`http://192.168.50.235:8000`).
   * **Hot-Reload Skryptów:** Automatycznie pobiera i uaktualnia skrypty `testportal_bypass.js` oraz `ai_injector.js` bez potrzeby ponownej instalacji pliku `.ipa`.
   * **Aktualizacja Aplikacji:** Powiadamia o nowej wersji i uruchamia instalację nowej paczki `.ipa`.

5. **Darmowy Tier AI:**
   * Korzysta z **Google Gemini 2.0 Flash API** (darmowy klucz z Google AI Studio) lub **OpenRouter Free Tier**.

---

## 🛠️ Jak Zainstalować Aplikację na iPhone (Za Darmo)

Aplikację można wgrać na iPhone'a bez płatnego konta Apple Developer. Oto najpopularniejsze metody:

### Metoda 1: Xcode (Gdy masz dostęp do komputera Mac)
1. Otwórz plik `Makarena.xcodeproj` w Xcode na Macu.
2. Podłącz iPhone'a do komputera kablem.
3. Wybierz swój telefon jako urządzenie docelowe (`Target`).
4. W zakładce *Signing & Capabilities* wybierz swoje bezpłatne konto Apple ID (`Personal Team`).
5. Kliknij **Run (Cmd + R)**.

### Metoda 2: Sideloadly / AltStore (Windows / Mac)
1. Skompiluj projekt do pliku `.ipa` lub użyj domyślnego pliku zbudowanego z Xcode.
2. Zainstaluj program **Sideloadly** lub **AltStore** na komputerze z systemem Windows lub Mac.
3. Podłącz iPhone'a kablem USB.
4. Przeciągnij plik `.ipa` / folder projektu do Sideloadly, wpisz swoje bezpłatne Apple ID i kliknij **Start**.
5. Po wgraniu aplikacji wejdź na iPhone w:  
   *`Ustawienia` -> `Ogólne` -> `Zarządzanie urządzeniami i VPN`* i kliknij **Zaufaj**.

---

## 🔑 Konfiguracja Klucza API (Gemini)

1. Wejdź na darmową stronę Google AI Studio: [https://aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)
2. Wygeneruj darmowy klucz API (`Create API key`).
3. W aplikacji **Makarena** kliknij ikonę zębatki ⚙️ w prawym górnym rogu.
4. Wklej klucz API i kliknij **Gotowe**.

---

## 🌐 Konfiguracja Serwera Aktualizacji (`version.json`)

Na Twoim serwerze HTTP / Cloudflare Tunnel / SSH wystarczy wystawić plik `version.json` pod adresem np. `http://192.168.50.235:8000/version.json`:

```json
{
  "version": "1.1.0",
  "downloadUrl": "http://192.168.50.235:8000/Makarena.ipa",
  "manifestUrl": "itms-services://?action=download-manifest&url=https://192.168.50.235:8000/manifest.plist",
  "changelog": "Zaktualizowano mechanizmy bypassu Testportal i usprawniono szybkosc reakcji AI.",
  "scripts": {
    "testportalBypass": "http://192.168.50.235:8000/scripts/testportal_bypass.js",
    "aiInjector": "http://192.168.50.235:8000/scripts/ai_injector.js"
  }
}
```

* **Wymiana samych skryptów (Hot-Reload):** Gdy zaktualizujesz skrypty na serwerze, aplikacja automatycznie je pobierze przy sprawdzaniu aktualizacji i wgra do pamięci iPhone'a bez konieczności ponownej instalacji aplikacji `.ipa`.
* **Pełna aktualizacja `.ipa`:** Gdy wersja w `version.json` będzie wyższa niż obecna w aplikacji, przycisk **"Zaktualizuj Teraz"** w aplikacji automatycznie pobierze i zainstaluje nową wersję.

---

## 📂 Struktura Projektu

* [`Scripts/testportal_bypass.js`](file:///c:/Users/par1s3k/Desktop/Makarena/Scripts/testportal_bypass.js) – Skrypt omijający detekcję bluru/karty na Testportal.
* [`Scripts/ai_injector.js`](file:///c:/Users/par1s3k/Desktop/Makarena/Scripts/ai_injector.js) – Skrypt JS odpowiedzialny za odczyt pytań oraz nakładanie/ukrywanie podpowiedzi.
* [`Services/AIService.swift`](file:///c:/Users/par1s3k/Desktop/Makarena/Services/AIService.swift) – Komunikacja z API Gemini 2.0 / OpenRouter.
* [`Services/VolumeKeyObserver.swift`](file:///c:/Users/par1s3k/Desktop/Makarena/Services/VolumeKeyObserver.swift) – Wykrywanie naciśnięć fizycznych przycisków głośności.
* [`WebView/StealthWebView.swift`](file:///c:/Users/par1s3k/Desktop/Makarena/WebView/StealthWebView.swift) – Wrapper `WKWebView` z iniekcją skryptów.
* [`Views/ContentView.swift`](file:///c:/Users/par1s3k/Desktop/Makarena/Views/ContentView.swift) – Główny widok UI przeglądarki.
