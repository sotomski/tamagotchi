# 📋 Raport analizy MVP — AI-Tamagotchi

**Typ projektu:** aplikacja webowa (gra) — backend **Serverpod** (Dart) + klient **Flutter Web**.
**Domena:** wirtualny pupil sterowany AI; rdzeniem danych jest **Creature** (stworek) wraz z jego dziennikiem (journal), osobowością i statystykami.

> Uwaga metodologiczna: zgodnie z regułami `mvp-check.md` oceniam wyłącznie 5 kryteriów technicznych na podstawie kodu i dokumentacji. Pomijam wygląd, styl, UI/UX, dostępność oraz kwestię wdrożenia/hostingu (oceniane osobno). Plik `mvp-check.md` nie istnieje w repozytorium — użyłem reguł przekazanych w zadaniu.

---

## 1. Checklist kryteriów

### ✅ Kryterium 1 — Operacje CRUD

Rdzenną encją jest **Creature** (`tamagotchi_server/lib/src/creature/`). Wszystkie cztery operacje działają na **danych utrwalonych w Postgresie**, nie na stanie tymczasowym UI:

| Operacja | Dowód |
|----------|-------|
| **Create** | `CreatureEndpoint.hatch()` — `creature_endpoint.dart:31`; wstawia w jednej transakcji `Creature`, `CreaturePersonality` i wpis `JournalEntry` (`insertRow`, linie 149–189). |
| **Read** | `CreatureEndpoint.myCreature()` — `creature_endpoint.dart:304` (odczyt stworka + pochodny nastrój); `readJournal()` — `creature_endpoint.dart:745` (odczyt dziennika). |
| **Update** | `feed()` (`:388`), `play()` (`:525`), `cure()` (`:650`) — każda wywołuje `Creature.db.updateRow(...)` utrwalając zmiany statystyk; dodatkowo `myCreature` zapisuje zdekawowane statystyki pod blokadą `forUpdate`. |
| **Delete** | `reset()` — `creature_endpoint.dart:234`; `Creature.db.deleteWhere(...)` z kaskadą `onDelete=Cascade` na osobowość i dziennik. |

Wszystkie cztery operacje istnieją dla tej samej encji i operują na danych trwałych. **Spełnione.**

---

### ✅ Kryterium 2 — Logika biznesowa (poza CRUD)

Projekt jest wręcz **zbudowany wokół** nietrywialnej logiki domenowej — czystej, deterministycznej i testowalnej w izolacji:

- **Dekawowanie statystyk w czasie rzeczywistym** — `decayCreature()` w `decay_service.dart:64`: kwantyzacja upływu czasu na „ticki”, mnożniki osobowości, podłoga miłości (`loveFloor`), suwak przyspieszenia czasu `timeScale`.
- **Wyprowadzanie nastroju** — `deriveMood()` w `creature_service.dart:44` (priorytet choroby, „najgorsza” z pozostałych bied decyduje).
- **Bramka akceptacji/odmowy karmienia** — `pickyFactor()`, `rejectProbability()`, `evaluateFeed()` w `feed_service.dart:27–99` (grymaśność wyprowadzana z cech, monotoniczna względem głodu i smakowitości).
- **Delty sterowane osobowością** — `playDelta()`/`playEnergyCost()` (`play_service.dart:40`), `cureDelta()`/`cureRelief()` (`cure_service.dart:30`).
- **Losowanie cech przy narodzinach** — `randomPersonalityModifiers()` (`creature_service.dart:56`).
- **Integracje przetwarzające dane** — składanie promptów LLM + okno „pamięci” dziennika (`journal_memory.dart`), generowanie obrazka stworka (Gemini).

To dokładnie unikalna wartość produktu opisana w PRD. **Spełnione.**

---

### ✅ Kryterium 3 — Testy adresujące zdefiniowane ryzyko

Istnieje formalny **plan testów**: `context/foundation/test-plan.md` z mapą ryzyk (§2, tabela R1–R7). Testy mapują się na konkretne ryzyka:

- **Ryzyko R1/R2** (kontrakt determinizmu karmienia + monotoniczność bramki akceptacji/odmowy) → `tamagotchi_server/test/unit/feed_service_test.dart` — asercje `pickyFactor` względem wzoru z kontraktu (nie względem wyjścia implementacji), losowanie skryptowane przez `ScriptedRandom`.
- **Ryzyko R5** (IDOR / własność zasobu) → `tamagotchi_server/test/integration/feed_endpoint_test.dart:343` — test *„feed is owner-scoped: feeding as user B never touches user A's creature”* jawnie weryfikuje, że karmienie jako użytkownik B nie rusza stworka użytkownika A.

Dodatkowo istnieje szeroki zestaw testów (jednostkowe, integracyjne na realnym Postgresie, kontraktowe LLM, e2e Patrol). Realne testy odwzorowują nazwane ryzyka z planu. **Spełnione.**

---

### ✅ Kryterium 4 — Uwierzytelnianie powiązane z użytkownikiem

- **Logowanie e-mail + hasło** przez moduł Serverpod: `EmailIdpEndpoint extends EmailIdpBaseEndpoint` (`auth/email_idp_endpoint.dart`) oraz odświeżanie tokenu (`jwt_refresh_endpoint.dart`); ekran logowania po stronie klienta (`tamagotchi_flutter/lib/auth/sign_in_screen.dart`), przekierowania w routerze.
- **Wymuszenie logowania:** `CreatureEndpoint` ma `requireLogin => true` (`creature_endpoint.dart:23`).
- **Zasoby zawężone do właściciela:** każda metoda wyprowadza `ownerUuid` z `session.authenticated!.userIdentifier` i filtruje po `ownerUuid` (np. `:32`, `:308`, `:389`; odczyt dziennika ma dodatkowo backstop `t.ownerUuid.equals(ownerUuid)` przeciw IDOR — `:762`).
- Zgodne z sekcją **Access Control** w PRD („each user … can only see and interact with their own”).

**Spełnione.**

---

### ✅ Kryterium 5 — Dokumentacja

- **PRD:** `context/foundation/prd.md` — pełny, merytoryczny dokument (wizja i problem, persona, kryteria sukcesu, 11 wymagań funkcjonalnych z argumentacją sokratejską, logika biznesowa, kontrola dostępu, non-goals, otwarte pytania). Zero placeholderów.
- **Bogata warstwa „foundation” 10x:** `tech-stack.md`, `roadmap.md`, `test-plan.md`, `health-check.md`, `stack-assessment.md`, `infrastructure.md`, `shape-notes.md`, `lessons.md` + immutable `archive/` z historią zmian.
- **Konwencje projektu:** `CLAUDE.md` (root) i `tamagotchi_server/CLAUDE.md` szczegółowo opisują strukturę i reguły.
- **README:** obecny `README.md` w katalogu głównym oraz `tamagotchi_server/README.md` i `tamagotchi_flutter/README.md`.

Wymagane minimum (README + PRD) jest spełnione **z dużym zapasem** dzięki warstwie foundation. **Spełnione.**

---

## 2. Status projektu

| # | Kryterium | Status |
|---|-----------|:------:|
| 1 | Operacje CRUD | ✅ |
| 2 | Logika biznesowa | ✅ |
| 3 | Testy adresujące ryzyko | ✅ |
| 4 | Uwierzytelnianie powiązane z użytkownikiem | ✅ |
| 5 | Dokumentacja | ✅ |

### 🎯 Wynik: **5 / 5 = 100%**

Projekt **spełnia komplet minimalnych wymagań technicznych** — nie widać żadnej oczywistej luki w fundamentach.

---

## 3. Rekomendacje (opcjonalne — poza minimum)

Wszystkie kryteria są spełnione, więc poniższe to jedynie „polish”, nie braki:

1. **README główny (root).** Dodany w ramach tej analizy (`README.md`) — czym jest projekt, jak uruchomić serwer + klienta, linki do `context/foundation/prd.md`. Wcześniej istniały jedynie boilerplate'owe README starterów w `tamagotchi_server/` i `tamagotchi_flutter/`.
2. **CI dla warstw e2e/mutation.** Plan testów świadomie odkłada `mutation_test` i Patrol e2e jako „local-only, CI deferred” (§4/§6.7). To decyzja projektowa, ale domknięcie ich w CI podniosłoby wartość dowodową testów przy dalszej rozbudowie.

---

## 4. Ponad minimum — potencjał na wyróżnienie

Projekt **wyraźnie wykracza poza próg MVP** i wygląda na kandydata do specjalnego wyróżnienia / Demo Day:

- **Realny czas gry** — leniwe dekawowanie statystyk liczone z upływu czasu, z suwakiem przyspieszenia i zapisem tylko po pełnym „ticku”.
- **Integracja AI** — spersonalizowane odpowiedzi LLM (Mistral) + generowanie obrazka stworka (Gemini), z hermetycznymi stubami dla determinizmu testów.
- **Dbałość o współbieżność i spójność** — transakcje „stat+journal jako spójna para”, blokady `forUpdate`, backstop na unikalny indeks właściciela (obsługa wyścigu duplikatu hatch), sprzątanie osieroconych blobów.
- **Dojrzała inżynieria testów** — mapa ryzyk, testy oparte na „oracle” z kontraktu (a nie na wyjściu implementacji), bramka mutacyjna, testy IDOR na dwóch sesjach, e2e Patrol.
- **Wzorcowa dokumentacja 10x** — kompletna warstwa foundation + archiwum zmian z przeglądami implementacji.

**Podsumowanie:** fundamenty techniczne są solidne i kompletne (5/5). Zaliczenie progu technicznego samo w sobie nie gwarantuje certyfikacji, ale tutaj brak oczywistych luk, a zakres i jakość inżynierska plasują projekt zauważalnie powyżej minimum.

---

*Raport wygenerowany na podstawie analizy kodu i dokumentacji repozytorium. Data: 2026-07-04.*
