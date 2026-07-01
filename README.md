# Iso Local Sandbox

Base sandbox per un gioco multiplayer locale isometrico/pseudo-isometrico ispirato al ritmo action di Enter the Gungeon, pensato per crescere nel tempo con interventi iterativi della IA.

## Obiettivo

Il progetto vuole diventare una piattaforma modulare per sperimentare tre modalita principali:

- dungeon proceduralmente generato;
- zombie survival a ondate;
- tower defense;
- boss fight ricorrenti nelle ondate importanti o alla fine dei livelli.

La base attuale contiene Milestone 0-21 completate: tre modalita giocabili,
progressione persistente, preset export Windows documentato e sistemi modulari
per visual, co-op, risultati, audio, boss e varianti arena survival.

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
- Character Select: frecce/D-pad/stick navigano la griglia in quattro
  direzioni con wrapping solo su card valide; tastiera/mouse/pad 0 controllano
  il Giocatore 1, mentre i pad aggiuntivi muovono e confermano lo slot
  corrispondente senza rubare il focus. `Invio`/joypad `A` assegna il
  personaggio allo slot del controller attivo, `Start` joypad o `P` avvia la
  run quando tutti gli slot attivi hanno una selezione valida, `Esc`/joypad `B`
  torna al menu.
- Partita: joypad `Start` o `P` apre/chiude la pausa; `Esc` torna al menu principale arrestando la run.
- Tastiera: `WASD` per movimento, frecce per mira, `Spazio` per l'arma base,
  `F` per l'arma equipaggiata, `R` per ricaricare e `Q` per la super RPG.
- Tastiera: `Shift`/`Ctrl` esegue dodge/roll, `M` apre o chiude la mappa dei territori esplorati.
- Tastiera debug multiplayer: `F2`, `F3`, `F4` attivano/disattivano gli slot player 2, 3 e 4.
- Modalita debug: `F1` avvia Infinite Arena, `F7` avvia Zombie Survival, `F5` avvia una run dungeon e `F6` avvia tower defense.
- Debug ambiente: `F8` mostra il riepilogo biomi e `F9` evidenzia footprint e celle bloccate degli ostacoli.
- Joypad: stick sinistro per movimento, stick destro per mira, `RB` per l'arma
  base, `LB` per l'arma equipaggiata, pulsante `X` per ricaricare e pulsante `Y`
  per la super RPG.
- Joypad: pulsante `B` per dodge/roll, `Back/Select/View` apre o chiude la mappa dei territori esplorati.
- Joypad gameplay: D-pad su/giu seleziona ciclicamente l'arma raccolta
  precedente/successiva per il relativo player; tastiera debug `[`/`]` per player 1.
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

## Weapon visual identity

Le 30 armi del catalogo drop hanno profili visuali specifici condivisi tra
pickup, held weapon, HUD, projectile oppure slash e impact. Le famiglie firearm,
melee ed elemental usano silhouette, palette e linguaggi VFX distinti; un
profilo pickup mancante mostra sempre il marker esplicito
`missing_weapon_visual`.

Il contratto estensibile e documentato in [ARCHITECTURE.md](ARCHITECTURE.md),
la lista completa arma-per-arma in [GAME_DESIGN.md](GAME_DESIGN.md) e gli esiti
W0-W8 nel
[report di validazione](docs/weapon_visual_identity_validation_report.md).

## Test

La suite di test e interamente [GUT](https://github.com/bitwes/Gut) (Godot Unit
Test): un solo processo Godot esegue tutte le suite logiche sotto
`tests/suites/**`. La CI (`.github/workflows/ci.yml`) lancia solo questo runner.

```text
# Tutte le suite logiche rapide (un solo processo Godot).
tools/run_gut.sh
./tools/run_gut.ps1

# Solo il sottoinsieme golden.
tools/run_gut.sh --golden
./tools/run_gut.ps1 -Golden

# Solo un'area (es. world_gen, combat, ui_audio, balance...).
tools/run_gut.sh -gdir=res://tests/suites/combat
./tools/run_gut.ps1 -GutDir res://tests/suites/combat

# I wrapper locali stampano config/exit code e producono un report JUnit in build/test_logs/.

# Invocazione diretta (quella usata in CI).
godot --headless -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit

# Soak/stress (lunghi, esclusi dal run rapido; girano di notte via soak.yml).
godot --headless -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.soak.json -gexit

# Visual QA: tool a parte, richiedono rendering reale/GPU (non headless).
tools/run_visual_qa.sh            # vedi docs/testing/visual_qa.md

# Asset check isometrico.
godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check
```

> I runner legacy `tools/run_tests.sh` / `.ps1` ("un processo per file") sono
> deprecati e ora inoltrano a GUT. I Visual QA vivono in `tests/visual_qa/`,
> i soak/stress in `tests/suites/soak/`.

## Server MCP locale

Il tooling IA del progetto include un server MCP read-only in
`tools/mcp-server/`. Espone contesto strutturato su architettura, roadmap,
asset, ricerca e safe check allowlisted tramite transport `stdio`, senza
modificare il runtime Godot. Script principali:

```text
npm run mcp:build
npm run mcp:test
npm run mcp:smoke
npm run mcp:start
```

Installazione, configurazione Codex ed elenco tool sono documentati in
`tools/mcp-server/README.md`.

Export Windows:

```text
godot --headless --path . --import
godot --headless --path . --export-release "Windows Desktop" build/iso_local_sandbox.exe
godot --headless --path . --export-pack "Windows Desktop" build/iso_local_sandbox.pck
build/iso_local_sandbox.exe --rendering-method gl_compatibility -- --build-smoke
```

I template Windows ufficiali Godot `4.6.3` devono essere installati in
`%APPDATA%/Godot/export_templates/4.6.3.stable`. In questa validazione M13 del
2026-06-22 l'export PCK passa, mentre l'export EXE e il build smoke sono
bloccati localmente dai template `windows_debug_x86_64.exe` e
`windows_release_x86_64.exe` assenti; il blocco e esterno al codice del preset.

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
  modes/             modalita infinite arena, zombie survival, dungeon, tower defense
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

La policy di retention dei Markdown vive in
`docs/documentation_inventory.md`: le roadmap storiche completate sono
consolidate in `ROADMAP.md`, `CHANGELOG.md` e nei report tecnici invece di
restare come file separati. `TODO.md` contiene solo backlog aperto.

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
- inventario armi per-player con `WeaponInstance` persistenti per ammo, reload,
  cooldown, carica e stato temporaneo;
- arma base permanente separata dall'inventario delle armi raccolte;
- attacchi indipendenti: `RB` usa sempre la base e `LB` l'arma equipaggiata,
  senza switch automatico quando la speciale esaurisce le munizioni;
- proiettili con collisione e danno tramite `HealthSystem`;
- bersagli statici con vita nella scena principale;
- HUD per-player con vita e reload sopra il survivor e statistiche slot negli
  angoli schermo;
- nemico base melee con stati idle, chase, attack e dead;
- targeting del player vivo piu vicino e retarget su join/leave;
- spawn e registro nemici tramite `EnemySystem`;
- loot table tipizzate con probabilita e quantita configurabili;
- pickup fisici per XP, denaro, munizioni, vita e armi;
- XP e denaro condivisi dal party;
- munizioni condivise tra tutti i player vivi con arma speciale;
- cura e nuova arma applicate solo al player che raccoglie;
- catalogo centralizzato di 30 drop (10 firearm, 10 melee, 10 elemental),
  senza duplicati globali nella stessa run e con fallback ammo a pool esaurito;
- pass WVIS-001 W0-W8 completato: le 30 armi catalogo condividono una identita
  specifica tra pickup, held/HUD, projectile oppure slash e impact, verificata
  anche nei preset visuali e nello scenario survival affollato;
- menu principale mostrato all'avvio;
- `Infinite Arena` come modalita default/quick play: una cella `150x150`
  tile logici (`450x450` equivalenti legacy)
  chiusa da cliff rocciosi rialzati e solidi, ondate infinite, senza
  WorldRuntime, mappa esplorazione, fall boundary o streaming multi-regione;
- selezione personaggio prima della zombie survival con quattro profili iniziali;
- statistiche classe RPG con HP, attacco, difesa, velocita, progressione XP e level-up per-run;
- armi base RPG per arco, pistola, ascia e spada con range, scatter, ammo,
  reload e `attack_type` distinti;
- hitbox arma configurabili e separate dal visual, con projectile per ranged e
  hitbox temporanee melee per ascia/spada/artigli;
- pacchetto HUD sopra-player con livello e gauge EXP circolare al posto di
  P1/P2/P3/P4, vita cromatica sulle due righe superiori, ammo/reload in basso e
  super verticale blu con glow del faceplate quando pronta;
- XP RPG assegnata al killer e a fine ondata senza pickup XP dagli zombie;
- passive automatiche RPG per Ranger, Pistoliere, Berserker e Spadaccino con stato visibile nell'HUD;
- adrenalina RPG da combat e fine ondata, con super attivabile a 100 per ogni classe;
- HUD RPG con ritratto classe e icona arma nelle schede angolo, piu ammo,
  reload, EXP e super ready direttamente sopra il player;
- primo pass di bilanciamento RPG per differenziare meglio range, accessibilita, rischio e difesa;
- profili classe RPG data-driven tramite risorse `RpgCharacterData`;
- feedback world-space e cue procedurali dedicati per level-up e super RPG;
- revamp zombie completo con controller, biomi, wave director, spawner camera-edge, transizioni e sistemi ambientali modulari;
- motore procedurale seed-based per mappa globale biomi, celle `150x150` tile logici (`450x450` equivalenti legacy), passaggi, fall boundary, layout interno e validazione pathfinding;
- megamappa persistente seed-based con grafo connesso, regioni default `3x3` da `150x150`, passaggi fisici aperti, stato esplorazione salvabile e mappa consultabile;
- streaming senza caricamenti ai confini: regione corrente e vicini restano
  gameplay-ready, mentre il terreno e composto da chunk visuali `20x20`
  caricati attorno alla camera con prefetch, retention e isteresi;
- `Zombie Survival` avviata dal menu dedicato o da `F7` usa la megamappa `3x3`;
  l'arena compatta `1x1` resta disponibile solo passando
  `single_biome_arena = true` nel context di debug/test, mentre il profilo
  default `Infinite Arena` usa `arena_boundary_mode = "walled"`;
- classificazione completa del terreno `150x150` come walkable, obstacle, hazard, border, void o fall zone;
- dodge/roll per player con cooldown, invulnerabilita breve e validazione per
  piccoli gap/fall zone attraversabili, lasciando gli hazard ambientali
  bloccanti;
- manifest `assets/environment/isometric/manifest.json` per censire ostacoli,
  props, border tematici, fall zone, draw mode oggetti e tag terrain/passaggi
  da sostituire con versioni isometriche coerenti;
- tile layer asset-driven per ground, strade diagonali, road connector e
  passaggi: entry/exit, ponti, snow pass, broken gate e burned road sono
  risolti come asset tile nel `150x150`, non come patch o frecce del gate;
- oggetti e ostacoli asset-backed tramite SVG trasparenti e silhouette
  isometriche dedicate per case, cabine, laboratori, recinti, muri, barili,
  relitti, tronchi, ponti e crate, senza asset esterni obbligatori e senza
  fallback barriera generico implicito; il loader runtime evita canvas opachi e
  fallback placeholder generici;
- cinque biomi giocabili nella stessa run, con partenza forzata dalla `Pianura Infetta`;
- spawn zombie delegato a `ZombieSpawner` dai bordi della camera, validato
  contro camera, player, walkable, hazard, fall zone e blocker, con fallback
  stream-aware e punti arena usati solo se validi;
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
- annunci temporanei per ondata, reward e boss senza riquadro status persistente;
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
- hotkey debug `F1`/`F7`/`F5`/`F6` per passare tra Infinite Arena, Zombie Survival, dungeon e tower defense;
- tower defense avviabile con `F6`;
- arena dedicata con percorso a waypoint e core da 250 HP;
- nemici da percorso che danneggiano il core se raggiungono la fine;
- tre slot costruzione con crediti di run e input `E`/joypad `A`;
- torre automatica con targeting e proiettili condivisi;
- ondate crescenti, ricompense crediti e boss ogni cinque ondate;
- HUD tower defense con pannello status dedicato per vita core, crediti,
  ondata, nemici rimasti e reward, visibile solo in questa modalita;
- salvataggio JSON versionato di livello, XP, denaro e ultima modalita;
- save v2 con migrazione automatica dei dati v1 e unlock persistenti;
- autosave su variazioni della progressione;
- rifiuto dei save malformati o con versione non supportata;
- unlock `Field Kit` al livello party 2, con 120 HP a inizio run;
- reset idempotente della salute a ogni nuova run e sui player che entrano durante il gameplay;
- feedback audio procedurale per focus e conferma menu;
- feedback audio procedurale per sparo, impatto valido e pickup;
- feedback HUD/audio per low ammo, reload e ammo condivisa;
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

## Roadmap attiva

Il backlog aperto e categorizzato in `ROADMAP.md` e dettagliato in `TODO.md`:

- `UIUX-001`: polish menu, HUD, Character Select, status, mappa, boss, audio e
  leggibilita multi-risoluzione.
- `BOSS-001` e `TD-001`: espansioni contenute di boss e tower defense, senza
  duplicare sistemi condivisi.
- `QA-001` e `BAL-001`: test automatici critici, playtest, tuning e profiling.
- `REL-001`: export Windows, build smoke, attribuzioni e firma digitale se la
  toolchain e disponibile.

La copertura dell'iterazione biome survival vive ora nelle suite GUT
(`tests/suites/world_gen`, `environment`, `assets`, `modes`, `ui_audio`); vedi la
sezione [Test](#test).
