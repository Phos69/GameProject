# Iso Local Sandbox

Base sandbox per un gioco multiplayer locale isometrico/pseudo-isometrico ispirato al ritmo action di Enter the Gungeon, pensato per crescere nel tempo con interventi iterativi della IA.

## Obiettivo

Il progetto vuole diventare una piattaforma modulare per sperimentare tre modalita principali:

- dungeon proceduralmente generato;
- zombie survival a ondate;
- tower defense;
- boss fight ricorrenti nelle ondate importanti o alla fine dei livelli.

La base attuale contiene Milestone 0-3 come prototipi minimi: repository iniziale, documentazione, progetto Godot, scena pseudo-isometrica, player controllabile, input tastiera/joypad, camera funzionante, multiplayer locale 1-4 player e combat base con armi, munizioni, proiettili, danni e vita.

## Stack tecnico

- Engine: Godot 4.x
- Linguaggio: typed GDScript
- Target iniziale: desktop locale
- Input: joypad con fallback tastiera
- Multiplayer previsto: locale 2-4 giocatori

Godot e stato scelto perche offre scene 2D, input controller, UI, audio, packaging e workflow rapido senza dover costruire un engine custom.

## Come eseguire

1. Installa Godot 4.x stable.
2. Apri Godot.
3. Importa/apri la cartella del progetto: `e:\AI_TEST\GameProject`.
4. Avvia la scena principale con Play.

Scena principale:

```text
res://game/main/main.tscn
```

Controlli debug:

- Tastiera: `WASD` per movimento, frecce per mira, `Spazio` per sparare e `R` per ricaricare.
- Tastiera debug multiplayer: `F2`, `F3`, `F4` attivano/disattivano gli slot player 2, 3 e 4.
- Joypad: stick sinistro per movimento, stick destro per mira, trigger/spalla destra per sparare e pulsante `X` per ricaricare.
- Joypad multiplayer: `Start` attiva lo slot del controller, `Back/Select` lascia lo slot se non e player 1.

Nota: in questo ambiente `godot` non risulta disponibile nel PATH, quindi la verifica runtime va eseguita dall'editor Godot installato localmente.

Smoke test combat headless:

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
```

## Struttura cartelle

```text
game/
  main/              bootstrap, scena principale, playground pseudo-isometrico
  core/              costanti e contratti condivisi
  input/             gestione input tastiera/joypad
  multiplayer/       predisposizione multiplayer locale
  camera/            camera di gruppo
  player/            player controller e scena player
  combat/            contratti combattimento
  weapons/           sistema armi
  projectiles/       proiettili
  health/            health system e componenti vita/danno
  enemies/           sistema nemici
  bosses/            sistema boss
  drops/             drop e loot table
  progression/       XP, denaro e progressione
  modes/             modalita survival, dungeon, tower defense
  procedural/        generatori procedurali
  ui/                HUD e interfaccia
  audio/             audio manager
  saves/             salvataggi futuri
  debug/             strumenti debug
docs/                documentazione tecnica e checklist
prompts/             prompt operativi per task IA futuri
assets/              sprite, tileset, audio, font, UI
tests/               test e checklist automatizzabili futuri
```

## Stato attuale

Completato:

- repository Git inizializzato;
- progetto Godot 4.x testuale;
- scena principale con griglia pseudo-isometrica;
- player controllabile;
- camera che segue il gruppo player;
- input manager per tastiera e joypad;
- multiplayer locale 1-4 player con mapping controller deterministico;
- join/leave locale per slot 2-4;
- spawn/despawn dinamico dei player locali;
- HUD con slot locali attivi;
- pistola base configurata tramite `WeaponData`;
- munizioni, riserva e ricarica indipendenti per ogni player;
- proiettili con collisione e danno tramite `HealthSystem`;
- bersagli statici con vita nella scena principale;
- HUD per-player con vita e munizioni;
- struttura modulare per multiplayer, modalita, combat, proiettili, health, drop, boss, progressione e UI;
- documentazione iniziale.

Non ancora completato:

- AI nemici;
- drop e pickup;
- wave gameplay;
- dungeon generato giocabile;
- tower defense giocabile;
- salvataggi e packaging.

## Prossime milestone

1. Milestone 4: nemici base e drop system funzionante.
2. Milestone 5: zombie survival a ondate.
3. Milestone 6: boss system modulare.
4. Milestone 7: dungeon procedurale giocabile.
