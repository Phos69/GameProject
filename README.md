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

Dopo un clone nuovo o un `git pull` su una macchina dove il progetto non e gia
stato aperto, rigenerare prima la cache locale di Godot:

```text
godot --headless --path . --import
```

La cartella `.godot/` e locale e non viene versionata. Senza questo primo import,
l'avvio runtime puo non vedere le classi globali GDScript e generare errori del
tipo `Could not find type "RpgPlayerComponent" in the current scope`.

Controlli debug:

- Menu: frecce/D-pad o stick per navigare in modo circolare,
  `Invio`/joypad `A` per confermare e `Esc`/joypad `B`/`Back` per tornare al
  menu precedente quando presente.
- Settings: `LB` e `RB` cambiano tab in modo circolare e spostano il focus su
  un controllo valido della tab corrente.
- Character Select: frecce/D-pad cambiano card, `Invio`/joypad `A` assegna
  il personaggio allo slot attivo, il pulsante `Start Zombie Survival`
  conferma la run, `Esc`/joypad `B` torna al menu.
- Partita: joypad `Start` o `P` apre/chiude la pausa; `Esc` torna al menu principale arrestando la run.
- Tastiera: `WASD` per movimento, frecce per mira, `Spazio` per sparare, `R` per ricaricare e `Q` per la super RPG.
- Tastiera: `Shift`/`Ctrl` esegue dodge/roll, `M` apre o chiude la mappa dei territori esplorati.
- Tastiera debug multiplayer: `F2`, `F3`, `F4` attivano/disattivano gli slot player 2, 3 e 4.
- Modalita debug: `F1` avvia survival, `F5` avvia una run dungeon e `F6` avvia tower defense.
- Joypad: stick sinistro per movimento, stick destro per mira, trigger/spalla destra per sparare, pulsante `X` per ricaricare e pulsante `Y` per la super RPG.
- Joypad: pulsante `B` per dodge/roll, `Back/Select/View` apre o chiude la mappa dei territori esplorati.
- Joypad multiplayer: nel menu `Start` attiva lo slot del controller, `Back/Select` lascia lo slot se non e player 1.
- Dungeon: attraversare il portale verde a destra; nelle stanze combat e boss diventa verde solo dopo aver eliminato tutti i bersagli.
- Tower defense: entrare in uno slot azzurro e premere `E` o pulsante joypad `A` per costruire una torre se ci sono crediti sufficienti.

La suite e stata verificata con Godot `4.6.3`. Se `godot` non e nel PATH, usare l'eseguibile Godot installato localmente o avviare i test dall'editor. In un checkout pulito, eseguire prima il comando di import indicato sopra, poi avviare il runtime con `godot --path .`.


## Character art RPG

I profili RPG zombie survival mantengono gli ID tecnici `ranger`, `pistoliere`, `berserker` e `spadaccino`, ma ora espongono anche un nome proprio per menu e HUD:

- `Mira Vento` — Ranger · Arco, palette verde/oro.
- `Dante Ferraglia` — Pistoliere · Pistola, palette giallo/arancio.
- `Bruna Spaccaferro` — Berserker · Ascia, palette rosso/ferro.
- `Kael Guardia` — Spadaccino · Spada, palette blu/bianco.
- `Elio Braciastella` — Mago · Bastone arcano, palette viola/blu.
- `Nina Bullone` — Domatrice · Fionda magnetica, palette turchese/rame e companion Briciola.
- `Rocco Lunastorta` — Licantropo · Artigli, palette grigio/luna/rosso e trasformazione super.

I campi artistici in `RpgCharacterData` collegano palette, ritratti, sprite,
preview gameplay, weapon visual e icone passive/super senza rendere
obbligatori asset esterni. La Character Select usa card RPG grafiche,
stat visuali e un dossier gameplay: le card leggono prima
`portrait_hud_path`/`portrait_full_path`, poi `gameplay_sprite_path` come
fallback controllato e infine una preview procedurale generata da palette e
arma base. Il dossier laterale usa `style_description` e
`gameplay_sprite_path` per mostrare la preview gameplay. Per sostituire gli
asset, popolare i path `assets/characters/<id>/...` nei `.tres` e validare la
checklist `docs/rpg_character_visual_checklist.md`.

Il pass combat RPG distingue anche il runtime arma: arco, pistola, bastone e
fionda restano `projectile`, mentre ascia, spada e artigli usano hitbox melee
temporanee con wind-up, finestra attiva, recovery, trail e niente nodo
projectile.

Smoke test headless:

```text
godot --headless --path . --script res://tests/headless_shutdown_loop_test.gd
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/zombie_revamp_foundation_smoke_test.gd
godot --headless --path . --script res://tests/zombie_spawner_edge_smoke_test.gd
godot --headless --path . --script res://tests/zombie_biome_wave_director_smoke_test.gd
godot --headless --path . --script res://tests/zombie_environment_milestone_smoke_test.gd
godot --headless --path . --script res://tests/zombie_fall_hazard_smoke_test.gd
godot --headless --path . --script res://tests/zombie_biome_transition_smoke_test.gd
godot --headless --path . --script res://tests/zombie_biome_enemy_smoke_test.gd
godot --headless --path . --script res://tests/zombie_revamp_ten_wave_smoke_test.gd
godot --headless --path . --script res://tests/zombie_revamp_ten_minute_soak_test.gd
godot --headless --path . --script res://tests/biome_world_generation_smoke_test.gd
godot --headless --path . --script res://tests/world_graph_connectivity_smoke_test.gd
godot --headless --path . --script res://tests/persistent_world_generation_smoke_test.gd
godot --headless --path . --script res://tests/open_passage_transition_smoke_test.gd
godot --headless --path . --script res://tests/isometric_environment_manifest_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_asset_manifest_v7_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_asset_pipeline_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_tile_layer_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_passage_tile_smoke_test.gd
godot --headless --path . --script res://tests/isometric_biome_terrain_coverage_smoke_test.gd
godot --headless --path . --script res://tests/fall_boundary_visual_logic_smoke_test.gd
godot --headless --path . --script res://tests/player_dodge_gap_smoke_test.gd
godot --headless --path . --script res://tests/exploration_map_smoke_test.gd
godot --headless --path . --script res://tests/biome_debug_overlay_smoke_test.gd
godot --headless --path . --script res://tests/biome_mini_events_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
godot --headless --path . --script res://tests/milestone_9_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_visual_smoke_test.gd
godot --headless --path . --script res://tests/milestone_11_boss_telegraph_smoke_test.gd
godot --headless --path . --script res://tests/milestone_12_enemy_variants_smoke_test.gd
godot --headless --path . --script res://tests/milestone_13_weapon_tower_visual_smoke_test.gd
godot --headless --path . --script res://tests/milestone_14_final_polish_smoke_test.gd
godot --headless --path . --script res://tests/character_select_ui_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_1_character_select_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_2_stats_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_3_weapons_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_4_hitbox_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_5_ammo_reload_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_6_xp_level_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_7_passives_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_8_adrenaline_super_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_9_hud_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_10_balance_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_11_data_driven_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_12_feedback_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_13_new_classes_smoke_test.gd
godot --headless --path . --script res://tests/rpg_melee_attack_resolution_smoke_test.gd
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
  rpg/               profili classe, componenti RPG e super
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
  world/             grafo persistente, regioni e stato esplorazione
  ui/                HUD e interfaccia
  audio/             audio manager
  settings/          impostazioni video e stato configurabile condiviso
  saves/             salvataggi JSON versionati
  visuals/           visual modulari ed effetti gameplay sostituibili
  environment/       profili arena, palette, gate e props interattivi
  modes/zombie/      componenti revamp survival: biomi, spawner e wave director
  debug/             strumenti debug
docs/                documentazione tecnica e checklist
prompts/             prompt operativi per task IA futuri
assets/              sprite, tileset, audio, font, UI e manifest isometrici
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
- selezione personaggio prima della zombie survival con quattro profili iniziali;
- statistiche classe RPG con HP, attacco, difesa, velocita, XP bar e level-up per-run;
- armi base RPG per arco, pistola, ascia e spada con range, scatter, ammo,
  reload e `attack_type` distinti;
- hitbox arma configurabili e separate dal visual, con projectile per ranged e
  hitbox temporanee melee per ascia/spada/artigli;
- pips ammo e barra reload nel player HUD per le armi RPG;
- XP RPG assegnata al killer e a fine ondata senza pickup XP dagli zombie;
- passive automatiche RPG per Ranger, Pistoliere, Berserker e Spadaccino con stato visibile nell'HUD;
- adrenalina RPG da combat e fine ondata, con super attivabile a 100 per ogni classe;
- HUD RPG con ritratto classe, icona arma, pips ammo, barre XP/adrenalina e icona super ready;
- primo pass di bilanciamento RPG per differenziare meglio range, accessibilita, rischio e difesa;
- profili classe RPG data-driven tramite risorse `RpgCharacterData`;
- feedback world-space e cue procedurali dedicati per level-up e super RPG;
- revamp zombie completo con controller, biomi, wave director, spawner camera-edge, transizioni e sistemi ambientali modulari;
- motore procedurale seed-based per mappa globale biomi, celle `200x200`, passaggi, fall boundary, layout interno e validazione pathfinding;
- megamappa persistente seed-based con grafo connesso, regioni `200x200`, passaggi fisici aperti, stato esplorazione salvabile e mappa consultabile;
- classificazione completa del terreno `200x200` come walkable, obstacle, hazard, border, void o fall zone;
- dodge/roll per player con cooldown, invulnerabilita breve e validazione per
  piccoli gap/fall zone attraversabili, lasciando gli hazard ambientali
  bloccanti;
- manifest `assets/environment/isometric/manifest.json` per censire ostacoli,
  props, border tematici, fall zone, draw mode oggetti e tag terrain/passaggi
  da sostituire con versioni isometriche coerenti;
- tile layer asset-driven per ground, road connector e passaggi: entry/exit,
  ponti, snow pass, broken gate e burned road sono risolti come asset tile nel
  `200x200`, non come patch o frecce del gate;
- draw procedurali dedicati per gli ostacoli generati e i border tematici dei
  cinque biomi, senza asset esterni obbligatori e senza fallback barriera
  generico implicito;
- cinque biomi giocabili nella stessa run, con partenza forzata dalla `Pianura Infetta`;
- spawn zombie delegato a `ZombieSpawner` dai bordi della camera, con fallback ai punti arena esistenti;
- layout ambientali data-driven per Pianura, Tossico, Infuocato, Neve e Palude;
- casse comuni, mediche, militari e tematiche con loot dedicato tramite `SupplyCrate` e `DropSystem`;
- zona di caduta data-driven con visuale cliff/depth, 20 HP di danno, respawn
  all'ultima posizione sicura e invulnerabilita temporanea componibile;
- feedback visuale/audio della caduta e rifiuto della zona da parte dello spawner zombie;
- pozze tossiche, gas, fuoco, lava, ghiaccio, neve alta, acqua profonda e fango con danno o modifica movimento;
- undici varianti zombie tematiche configurate tramite `BiomeEnemyProfile`;
- HUD bioma con pericoli, risorse, status e annunci di transizione;
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
- menu pausa durante la partita con resume, settings, ritorno al menu e quit;
- bus audio separati, cue sostituibili, fallback e volumi persistenti;
- pagina settings condivisa tra main menu e pausa, con tab Audio, Video e Controls;
- impostazioni video per fullscreen, borderless, risoluzione, VSync e limite framerate;
- rimappatura persistente dei controlli joypad gameplay, pausa, join e leave;
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
3. Affinare bilanciamento e performance del revamp zombie dopo playtest reali.
4. Firmare digitalmente la build pubblica.

Smoke test aggiunti per l'iterazione biome survival:

```text
godot --headless --path . --script res://tests/biome_status_effects_smoke_test.gd
godot --headless --path . --script res://tests/biome_roster_smoke_test.gd
godot --headless --path . --script res://tests/biome_obstacle_generation_smoke_test.gd
godot --headless --path . --script res://tests/random_encounter_smoke_test.gd
godot --headless --path . --script res://tests/biome_debug_overlay_smoke_test.gd
godot --headless --path . --script res://tests/biome_mini_events_smoke_test.gd
```
