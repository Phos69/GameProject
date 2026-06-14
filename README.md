# Iso Local Sandbox

Base sandbox per un gioco multiplayer locale isometrico/pseudo-isometrico ispirato al ritmo action di Enter the Gungeon, pensato per crescere nel tempo con interventi iterativi della IA.

## Obiettivo

Il progetto vuole diventare una piattaforma modulare per sperimentare tre modalita principali:

- dungeon proceduralmente generato;
- zombie survival a ondate;
- tower defense;
- boss fight ricorrenti nelle ondate importanti o alla fine dei livelli.

La base attuale contiene Milestone 0 e Milestone 1: repository iniziale, documentazione, progetto Godot, scena pseudo-isometrica, player controllabile, input tastiera/joypad e camera funzionante.

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

- Tastiera: `WASD` per movimento, frecce per mira, `Spazio` per fire action.
- Joypad player 1: stick sinistro per movimento, stick destro per mira, trigger/spalla destra per fire action.

Nota: in questo ambiente `godot` non risulta disponibile nel PATH, quindi la verifica runtime va eseguita dall'editor Godot installato localmente.

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
- fire action con proiettili placeholder visibili;
- struttura modulare per multiplayer, modalita, combat, proiettili, health, drop, boss, progressione e UI;
- documentazione iniziale.

Non ancora completato:

- multiplayer locale effettivo 2-4 player;
- collisioni proiettile/nemico, ammo e combat completo;
- AI nemici;
- wave gameplay;
- dungeon generato giocabile;
- tower defense giocabile;
- salvataggi e packaging.

## Prossime milestone

1. Milestone 2: multiplayer locale reale 2-4 giocatori.
2. Milestone 3: sparo, armi, proiettili, danni e vita.
3. Milestone 4: nemici base e drop system funzionante.
4. Milestone 5: zombie survival a ondate.
