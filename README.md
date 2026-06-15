# Iso Local Sandbox

Base sandbox per un gioco multiplayer locale isometrico/pseudo-isometrico ispirato al ritmo action di Enter the Gungeon, pensato per crescere nel tempo con interventi iterativi della IA.

## Obiettivo

Il progetto vuole diventare una piattaforma modulare per sperimentare tre modalita principali:

- dungeon proceduralmente generato;
- zombie survival a ondate;
- tower defense;
- boss fight ricorrenti nelle ondate importanti o alla fine dei livelli.

La base attuale contiene Milestone 0-8 come prototipi minimi: repository iniziale, documentazione, progetto Godot, scena pseudo-isometrica, player controllabile, input tastiera/joypad, camera funzionante, multiplayer locale 1-4 player, combat base, nemico melee, drop raccoglibili, zombie survival, boss modulare, dungeon procedurale e tower defense giocabile.

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
- Modalita debug: `F1` avvia survival, `F5` avvia una run dungeon e `F6` avvia tower defense.
- Joypad: stick sinistro per movimento, stick destro per mira, trigger/spalla destra per sparare e pulsante `X` per ricaricare.
- Joypad multiplayer: `Start` attiva lo slot del controller, `Back/Select` lascia lo slot se non e player 1.
- Dungeon: attraversare il portale verde a destra; nelle stanze combat e boss diventa verde solo dopo aver eliminato tutti i bersagli.
- Tower defense: entrare in uno slot azzurro e premere `E` o pulsante joypad `A` per costruire una torre se ci sono crediti sufficienti.

La suite e stata verificata con Godot `4.6.3`. Se `godot` non e nel PATH, usare l'eseguibile Godot installato localmente o avviare i test dall'editor.

Smoke test headless:

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
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
- nemico base melee con stati idle, chase, attack e dead;
- targeting del player vivo piu vicino e retarget su join/leave;
- spawn e registro nemici tramite `EnemySystem`;
- loot table tipizzate con probabilita e quantita configurabili;
- pickup fisici per XP, denaro, munizioni, vita e armi;
- XP e denaro condivisi dal party;
- munizioni, cura e cambio arma applicati solo al player che raccoglie;
- seconda arma prototipo ottenibile come drop;
- survival avviato automaticamente dalla scena principale;
- ondate con spawn scaglionato e conteggio crescente;
- scaling progressivo di vita, velocita e danno dei nemici;
- intermissione e ricompense party tra le ondate;
- HUD con ondata, nemici rimasti, countdown e ultima ricompensa;
- boss reale ogni cinque ondate, integrato nel conteggio e nel completamento della wave;
- sconfitta survival quando tutti i player attivi sono morti;
- boss `Wave Warden` nella quinta ondata con due fasi;
- raffica mirata e attacco radiale tramite proiettili ostili;
- barra vita boss con nome, fase e vita corrente;
- scaling boss in base all'ondata;
- drop speciale garantito `Wave Cannon`;
- completamento della boss wave vincolato alla morte del boss;
- layout dungeon deterministico da seed con celle uniche e link sequenziali;
- start room, combat room, loot room e boss room;
- stanza modulare confinata con portale di uscita bloccabile;
- spawn nemici crescente nelle stanze combat;
- loot room con XP, denaro, munizioni e vita;
- boss finale richiesto tramite il `BossSystem` condiviso;
- HUD dungeon con seed, stanza corrente, stato uscita e nemici rimasti;
- hotkey debug `F1`/`F5`/`F6` per passare tra survival, dungeon e tower defense;
- tower defense avviabile con `F6`;
- arena dedicata con percorso a waypoint e core da 250 HP;
- nemici da percorso che danneggiano il core se raggiungono la fine;
- tre slot costruzione con crediti di run e input `E`/joypad `A`;
- torre automatica con targeting e proiettili condivisi;
- ondate crescenti, ricompense crediti e boss ogni cinque ondate;
- HUD tower defense con vita core, crediti, ondata e nemici rimasti;
- struttura modulare per multiplayer, modalita, combat, proiettili, health, drop, boss, progressione e UI;
- documentazione iniziale.

Non ancora completato:

- ulteriori boss, pattern avanzati e telegraph;
- varianti nemico ranged/tank/runner;
- respawn o revive dei player;
- dungeon ramificati, shop, biomi e selezione stanza;
- salvataggi e packaging.

## Prossime milestone

1. Milestone 9: progressione persistente, menu, polish e packaging.
