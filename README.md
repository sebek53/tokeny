# Tokeny – licznik zużycia Claude Code

Małe okienko „zawsze na wierzchu” (Windows) pokazujące dzisiejsze zużycie tokenów Claude Code
oraz procent limitu (sesja 5h i tydzień) – to samo co `/usage`.

## Wymagania

- Windows 10/11 (PowerShell 5.1 jest wbudowany)
- Zainstalowany i zalogowany [Claude Code](https://claude.com/claude-code)

## Uruchomienie

1. Pobierz repo (Code → Download ZIP) i rozpakuj.
2. Kliknij dwukrotnie `tokeny-tray.vbs`.

Okienko pojawi się w prawym dolnym rogu. Lewy przycisk – przeciąganie, prawy – menu
(Odśwież, Zaloguj, Zamknij). Najechanie myszką pokazuje dokładne liczby.

Autostart: wrzuć skrót do `tokeny-tray.vbs` do folderu `shell:startup` (Win+R).

## Procent limitu

Brak procentów (`brak % - prawy klik: Zaloguj`) oznacza wygasłe logowanie.
Prawy klik → „Zaloguj Claude” → w terminalu wpisz `/login` i zaloguj się w przeglądarce.
**Nigdy nie wpisuj hasła w terminalu.**

## Jak to działa

- Tokeny liczone są lokalnie z logów `~/.claude/projects/*.jsonl` – nic nie jest wysyłane,
  nie zużywa tokenów.
- Procent limitu pobierany jest z nieoficjalnego endpointu Anthropic
  (`api.anthropic.com/api/oauth/usage`) przy użyciu tokenu zapisanego przez Claude Code.
  Może przestać działać bez ostrzeżenia. Zapytanie najwyżej raz na 5 minut.
- `tokeny.py` – osobny skrypt w konsoli: tabela tokenów dzień po dniu (wymaga Pythona).

Projekt nieoficjalny, niezwiązany z Anthropic.
