# Iso Local Sandbox

Base sandbox per un gioco multiplayer locale isometrico/pseudo-isometrico ispirato al ritmo action di Enter the Gungeon, pensato per crescere nel tempo con interventi iterativi della IA.

## Obiettivo

Il progetto vuole diventare una piattaforma modulare per sperimentare tre modalita principali:

- dungeon proceduralmente generato;
- zombie survival a ondate;
- tower defense;
- boss fight ricorrenti nelle ondate importanti o alla fine dei livelli.

La base attuale contiene Milestone 0-21 completate: tre modalita giocabili,
progressione persistente, build Windows verificata e sistemi modulari per
visual, co-op, risultati, audio, boss e varianti arena survival.

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

- Menu: frecce/D-pad o stick per navigare, `Invio`/joypad `A` per confermare e `Esc` per tornare al menu durante una run.
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
godot --headless --path . --script res://tests/milestone_9_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_visual_smoke_test.gd
godot --headless --path . --script res://tests/milestone_11_boss_telegraph_smoke_test.gd
godot --headless --path . --script res://tests/milestone_12_enemy_variants_smoke_test.gd
godot --headless --path . --script res://tests/milestone_13_weapon_tower_visual_smoke_test.gd
godot --headless --path . --script res://tests/milestone_14_final_polish_smoke_test.gd
```

Export Windows:

```text
godot --headless --path . --export-release "Windows Desktop" build/iso_local_sandbox.exe
godot --headless --path . --export-pack "Windows Desktop" build/iso_local_sandbox.pck
build/iso_local_sandbox.exe --rendering-method gl_compatibility -- --build-smoke
```

I template Windows ufficiali Godot `4.6.3` devono essere installati in `Godot/export_templates/4.6.3.stable`. EXE e PCK sono stati generati; lo smoke test della release passa con exit code `0`.

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
  saves/             salvataggi JSON versionati
  visuals/           visual modulari ed effetti gameplay sostituibili
  environment/       profili arena, palette, gate e props interattivi
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
- `Starter Pistol` configurata tramite `WeaponData` con riserva infinita;
- slot fallback permanente e slot arma speciale con stato indipendente per ogni player;
- fallback automatico quando una speciale esaurisce caricatore e riserva;
- proiettili con collisione e danno tramite `HealthSystem`;
- bersagli statici con vita nella scena principale;
- HUD per-player con vita e munizioni;
- nemico base melee con stati idle, chase, attack e dead;
- targeting del player vivo piu vicino e retarget su join/leave;
- spawn e registro nemici tramite `EnemySystem`;
- loot table tipizzate con probabilita e quantita configurabili;
- pickup fisici per XP, denaro, munizioni, vita e armi;
- XP e denaro condivisi dal party;
- munizioni condivise tra tutti i player vivi con arma speciale;
- cura e cambio arma applicati solo al player che raccoglie;
- seconda arma prototipo ottenibile come drop;
- menu principale mostrato all'avvio;
- selezione di survival, dungeon e tower defense da tastiera o joypad;
- ritorno al menu con `Esc` e arresto pulito della modalita attiva;
- survival avviabile dal menu o con hotkey debug;
- ondate con spawn scaglionato e conteggio crescente;
- scaling progressivo di vita, velocita e danno dei nemici;
- intermissione e ricompense party tra le ondate;
- ammo director survival con soglia anti-frustrazione e cooldown configurabili;
- supply crate con drop ammo/vita e fonte garantita nelle boss wave;
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
- salvataggio JSON versionato di livello, XP, denaro e ultima modalita;
- save v2 con migrazione automatica dei dati v1 e unlock persistenti;
- autosave su variazioni della progressione;
- rifiuto dei save malformati o con versione non supportata;
- unlock `Field Kit` al livello party 2, con 120 HP a inizio run;
- reset idempotente della salute a ogni nuova run e sui player che entrano durante il gameplay;
- feedback audio procedurale per focus e conferma menu;
- feedback audio procedurale per sparo, impatto valido e pickup;
- feedback HUD/audio per low ammo, reload, fallback e ammo condivisa;
- arena survival desaturata con dettagli post-apocalittici;
- survivor e zombie con visuali modulari animate proceduralmente;
- pickup e supply crate grafici senza etichette testuali;
- HUD per-player con barre vita, identita arma e munizioni;
- effetti visuali per sparo, hit, morte nemico e raccolta;
- telegraph world-space e HUD/audio per i pattern del `Wave Warden`;
- `Wave Warden` segmentato e animato con identita distinta per le due fasi;
- annunci centrali per wave, reward, boss, overdrive e sconfitta;
- proiettili boss aimed/radial con profili, glow e trail distinti;
- effetto morte boss e presentazione del drop speciale;
- runner e tank con silhouette, statistiche e loot distinti;
- shooter ranged con distanza preferita, windup, corsia telegrafata e colpo schivabile;
- stato downed e revive locale con input tenuto, anello world-space e HUD;
- schermate risultati condivise con durata, progressione, retry e cambio modalita;
- bus audio separati, cue sostituibili, fallback e volumi persistenti;
- registro boss per ID con compatibilita esplicita per modalita;
- boss dungeon `Rift Architect` con due pattern, fase e drop dedicati;
- due arena survival data-driven con palette, spawn e player start distinti;
- gate zombie visibili e non collidenti collegati allo spawn reale;
- barili esplosivi con warning world-space e danno tramite `HealthSystem`;
- impostazioni visuali persistenti per flash, glow, trail, shake e testo HUD;
- preset default, comfort e high contrast con marker geometrici player;
- pipeline asset con fallback, import coerenti e registro attribuzioni;
- pistola, blaster e Wave Cannon con silhouette, icone HUD e proiettili distinti;
- torre con base esagonale, doppia canna, tracking e feedback di fuoco;
- primo pass di bilanciamento sulle armi base;
- preset export `Windows Desktop`;
- mapping globale `ui_accept` su joypad `A`;
- build Windows release generata e avviata;
- smoke test interno della build con menu, joypad, audio e survival;
- QA visuale a 1280x720 con controller XInput e audio WASAPI;
- esclusione di `tests/` e `build/` dal pacchetto distribuito;
- struttura modulare per multiplayer, modalita, combat, proiettili, health, drop, boss, progressione e UI;
- documentazione iniziale.

Non ancora completato:

- ulteriori boss e pattern avanzati;
- dungeon ramificati, shop, biomi e selezione stanza;
- asset definitivi e ulteriori pass di bilanciamento;
- firma digitale dell'eseguibile Windows.

## Prossimi obiettivi post-roadmap

1. Espandere il dungeon con diramazioni, shop e biomi dedicati.
2. Sostituire gradualmente i placeholder con asset licenziati.
3. Affinare bilanciamento e performance dopo playtest reali.
