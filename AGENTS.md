# AGENTS.md

Regole operative per agenti IA che lavorano su questo repository.

## Principi

- Leggere prima il codice e la documentazione esistente.
- Non cancellare o riscrivere sistemi senza una ragione tecnica chiara.
- Preferire modifiche piccole, verificabili e coerenti con la roadmap.
- Evitare mega-file: ogni sistema deve stare nella propria cartella.
- Aggiornare documentazione e backlog insieme alle modifiche importanti.

## Prima di modificare

1. Controllare `git status --short --branch`.
2. Leggere `README.md`, `ROADMAP.md`, `TODO.md` e il file di architettura rilevante.
3. Cercare sistemi esistenti con `rg` prima di crearne di nuovi.
4. Integrare il codice presente invece di duplicare responsabilita.

## Dopo ogni modifica importante

- Aggiornare `CHANGELOG.md`.
- Aggiornare `TODO.md` se cambia il backlog.
- Aggiornare `ROADMAP.md` se una milestone avanza.
- Aggiornare `ARCHITECTURE.md` se cambia il contratto tra sistemi.
- Aggiornare `GAME_DESIGN.md` se cambia una regola di gioco.

## Convenzioni codice

- Linguaggio: typed GDScript.
- File e cartelle: `snake_case`.
- Classi con `class_name`: `PascalCase`.
- Variabili e funzioni: `snake_case`.
- Scene: nome descrittivo in `snake_case`.
- Segnali: evento al passato o richiesta chiara, per esempio `player_spawned`, `boss_requested`.
- Dati di bilanciamento: preferire `Resource` o export variables, non valori nascosti in controller grandi.

## Regole anti-regressione

- Non cambiare input, health, combat o player controller senza testare la scena principale.
- Non introdurre una nuova modalita copiando logica condivisa: estrarre in `modes/shared/` o nel sistema adatto.
- Non rendere obbligatori asset esterni per il prototipo minimo.
- Ogni nuova feature deve avere una checklist manuale o un test futuro documentato.

## Commit

Usare commit atomici:

- `feat:` per feature;
- `fix:` per bugfix;
- `docs:` per documentazione;
- `refactor:` per refactor senza cambio comportamento;
- `chore:` per setup/manutenzione.

Non mescolare feature non correlate nello stesso commit.

## Task futuri

Per ogni task futuro, indicare:

- obiettivo;
- milestone collegata;
- file/sistemi coinvolti;
- criterio di accettazione;
- test manuale o automatico richiesto.

