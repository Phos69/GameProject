# Roadmap Visual Gameplay - Prossimi Sviluppi

Repository: `Phos69/GameProject`

## Scopo

Questa roadmap registra il ciclo visual/gameplay M15-M21, ora completato.

Il prossimo ciclo deve espandere profondita, varieta e presentazione senza
perdere i principi gia stabiliti:

- arcade pseudo-isometrico leggibile da divano;
- sfondo meno saturo degli elementi gameplay;
- silhouette riconoscibili anche con quattro player;
- telegraph prima del danno;
- visual modulari separati dalla logica;
- nessun asset esterno obbligatorio per avviare il progetto;
- regressione obbligatoria di survival, dungeon e tower defense.

## Ordine Consigliato

1. Milestone 15 - Zombie Ranged e Pressione a Distanza
2. Milestone 16 - Downed e Revive Multiplayer
3. Milestone 17 - Fine Run, Risultati e Menu
4. Milestone 18 - Audio Mix e SFX Sostituibili
5. Milestone 19 - Secondo Boss e Registro Boss
6. Milestone 20 - Arena, Biomi e Props Interattivi
7. Milestone 21 - Accessibilita, Performance e Asset Pipeline

Le milestone sono state affrontate una alla volta. Ogni milestone ha incluso
analisi, implementazione, smoke test, QA visuale, checklist manuale e
aggiornamento della documentazione coinvolta.

---

## Milestone 15 - Zombie Ranged e Pressione a Distanza

Stato: completata come primo pass gameplay e visuale.

### Obiettivo

Introdurre uno zombie shooter che costringa il party a cambiare posizione,
senza duplicare health, drop, targeting o tracking delle wave.

### Design

- Silhouette alta o curva, distinta da basic, runner e tank.
- Accento cromatico freddo o tossico, non confondibile con player e pickup.
- Mantiene una distanza preferita dal target.
- Mostra windup, direzione e corsia del colpo prima di sparare.
- Il proiettile ostile deve essere distinto dai pattern del `Wave Warden`.
- Deve lasciare spazio sicuro e tempo di reazione anche con quattro player.

### File e Sistemi Coinvolti

- `game/enemies/`
- `game/visuals/zombie_visual.gd`
- `game/enemies/enemy_system.gd`
- `game/modes/shared/wave_manager.gd`
- `game/projectiles/`
- `game/drops/`
- HUD, audio e QA visuale

### Criteri di Accettazione

- Lo shooter e riconoscibile senza leggere testo.
- Il windup precede sempre il proiettile.
- Il colpo puo essere evitato leggendo il telegraph.
- Il nemico usa `HealthComponent`, `DropSystem` ed `EnemySystem`.
- La composizione wave resta deterministica e documentata.
- Basic, runner e tank mantengono il comportamento attuale.

### Test Richiesti

- Smoke test spawn, target, windup, sparo, danno, morte e drop.
- Test che nessun proiettile venga creato durante il warning.
- QA a quattro player con roster misto.
- Regressione survival, dungeon e tower defense.

### Fuori Scope

- Copertura, pathfinding avanzato o gruppi tattici.
- Piu di un nuovo archetipo ranged.

---

## Milestone 16 - Downed e Revive Multiplayer

Stato: completata come primo pass cooperativo.

### Obiettivo

Evitare che un player locale resti escluso a lungo dalla partita e creare
scelte cooperative leggibili durante survival e boss fight.

### Design

- A zero HP il player entra nello stato `downed`.
- Il player downed non si muove e non spara.
- Un alleato puo rianimarlo restando vicino e tenendo premuto interact.
- Un anello mostra distanza, progresso e interruzione del revive.
- Il colore slot resta visibile anche nella posa downed.
- La run termina solo quando tutti i player attivi sono downed o morti.

### File e Sistemi Coinvolti

- `game/player/`
- `game/health/`
- `game/player/player_manager.gd`
- `game/modes/survival/survival_mode.gd`
- `game/modes/dungeon/dungeon_mode.gd`
- `game/ui/player_hud_card.gd`
- input interact, visual ed effetti

### Criteri di Accettazione

- Un player downed puo essere rianimato da un altro slot.
- Il revive interrotto non completa in ritardo.
- Join e leave non bloccano lo stato della run.
- HUD e world-space mostrano chiaramente chi deve essere aiutato.
- Il bonus `Field Kit` non si accumula dopo un revive.
- Le condizioni di sconfitta sono documentate per ogni modalita.

### Test Richiesti

- Smoke test downed, revive, interruzione e sconfitta party.
- Test con due e quattro player.
- Checklist manuale input tastiera e joypad.
- Regressione health, boss, dungeon e tower defense.

### Fuori Scope

- Respawn infinito automatico.
- Classi con abilita di revive diverse.

---

## Milestone 17 - Fine Run, Risultati e Menu

Stato: completata come primo flusso UI condiviso.

### Obiettivo

Sostituire le uscite brusche o puramente testuali con una presentazione chiara
di vittoria, sconfitta e risultati della sessione.

### Design

- Schermata `Run Over` per survival.
- Schermata `Dungeon Complete`.
- Schermata `Defense Failed` e risultato tower defense.
- Riepilogo wave/stanza raggiunta, tempo, XP, denaro e unlock.
- Azioni grandi e leggibili: retry, menu, cambia modalita.
- Menu principale coerente con HUD, armi e palette post-apocalittica.
- Focus joypad sempre evidente.

### File e Sistemi Coinvolti

- `game/ui/main_menu.gd`
- nuovo componente risultati in `game/ui/`
- `GameModeManager`
- survival, dungeon e tower defense
- `ProgressionManager` e `SaveManager`
- audio UI e QA packaging

### Criteri di Accettazione

- Ogni modalita termina con uno stato UI esplicito.
- Retry riparte senza duplicare nodi o bonus.
- Il riepilogo usa dati runtime reali.
- Tutte le azioni funzionano da tastiera e joypad.
- Il salvataggio avviene prima del ritorno al menu.

### Test Richiesti

- Smoke test dei tre flussi di fine run.
- Test retry e ritorno al menu.
- QA visuale a 1280x720.
- Build smoke Windows con navigazione joypad.

### Fuori Scope

- Classifiche online.
- Account, profili cloud o matchmaking.

---

## Milestone 18 - Audio Mix e SFX Sostituibili

Stato: completata come infrastruttura audio modulare.

### Obiettivo

Passare dai soli toni procedurali a un sistema audio pronto per asset
licenziati, mantenendo fallback funzionanti e controllo del mix.

### Design

- Bus separati per master, UI, armi, nemici, boss e ambiente.
- SFX distinti per le tre armi player.
- SFX dedicati per basic, runner, tank e shooter.
- Cue per wave start, wave clear, downed, revive e fine run.
- Variazione leggera di pitch per evitare ripetizione.
- Limite di voci e priorita per le situazioni affollate.

### File e Sistemi Coinvolti

- `game/audio/audio_manager.gd`
- `assets/audio/`
- impostazioni bus Godot
- armi, nemici, boss, drop e UI
- menu impostazioni

### Criteri di Accettazione

- Il gioco non genera errori se un asset opzionale manca.
- Gli eventi critici restano udibili con quattro player.
- Non si verifica clipping durante boss wave affollate.
- Volumi master, musica e SFX sono regolabili e persistenti.
- I toni procedurali restano disponibili come fallback di sviluppo.

### Test Richiesti

- Test automatico degli hook e dei bus.
- Checklist cuffie, speaker e volume basso.
- QA con quattro player e molti proiettili.
- Verifica persistenza impostazioni.

### Fuori Scope

- Colonna sonora completa.
- Doppiaggio.

---

## Milestone 19 - Secondo Boss e Registro Boss

Stato: completata come primo registro boss configurabile.

### Obiettivo

Dimostrare che `BossSystem` supporta boss realmente configurabili per modalita
e non dipende dal solo `Wave Warden`.

### Design

- Nuovo boss con silhouette e pattern diversi dal `Wave Warden`.
- Almeno due fasi o una trasformazione leggibile.
- Telegraph coerenti ma non copiati.
- Drop speciale dedicato.
- Selezione boss per ID o configurazione della modalita.
- Compatibilita con survival, dungeon o tower defense definita esplicitamente.

### File e Sistemi Coinvolti

- `game/bosses/`
- `game/visuals/`
- `BossSystem`
- projectile e telegraph condivisi
- loot table e armi
- HUD boss e audio

### Criteri di Accettazione

- Due boss possono essere richiesti per ID senza cambiare il chiamante.
- Ogni boss ha visual, pattern, drop e test dedicati.
- La barra HUD mostra correttamente entrambi.
- Il boss non compatibile con una modalita viene rifiutato o configurato in
  modo esplicito.

### Test Richiesti

- Smoke test spawn, fase, pattern, morte e drop per entrambi i boss.
- Test registro e richiesta per ID.
- QA visuale dei telegraph.
- Regressione delle boss wave esistenti.

### Fuori Scope

- Selezione casuale complessa o boss rush.
- Piu di un nuovo boss.

---

## Milestone 20 - Arena, Biomi e Props Interattivi

Stato: completata come primo sistema arena survival data-driven.

### Obiettivo

Aumentare varieta e identita ambientale senza compromettere la leggibilita o
bloccare il movimento degli zombie.

### Design

- Seconda variante dell'arena survival.
- Spawn gate o ingressi zombie visibili.
- Props modulari con chiara distinzione tra decorazione e collisione.
- Barile esplosivo o prop interattivo con telegraph e area leggibile.
- Palette di bioma definita da dati.
- Elementi di sfondo sempre meno saturi degli attori.

### File e Sistemi Coinvolti

- `game/main/isometric_playground.gd`
- nuove scene in `game/visuals/` o `game/environment/`
- `WaveManager` per i punti spawn
- health, projectile ed effetti per props interattivi
- risorse palette/bioma

### Criteri di Accettazione

- Almeno due layout sono selezionabili senza duplicare il controller survival.
- Gli spawn sono leggibili ma non confusi con pickup o telegraph.
- I props solidi non intrappolano basic, runner, tank o shooter.
- Il prop interattivo non danneggia senza preavviso.
- Il multiplayer locale resta leggibile a zoom massimo.

### Test Richiesti

- Smoke test selezione arena e spawn.
- Test collisioni e danno del prop interattivo.
- QA visuale di entrambi i layout.
- Stress test con roster misto.

### Fuori Scope

- Generazione procedurale completa dell'arena.
- Sistema fisico distruttibile generale.

---

## Milestone 21 - Accessibilita, Performance e Asset Pipeline

Stato: completata come primo pass configurabile e misurabile.

### Obiettivo

Rendere il visual pass configurabile, misurabile e pronto alla sostituzione
graduale dei placeholder con asset definitivi.

### Design e Accessibilita

- Intensita regolabile per flash, glow, trail e camera shake.
- Modalita ad alto contrasto.
- Alternative ai soli codici colore per player e pickup.
- Dimensione testo HUD configurabile.
- Riduzione movimento per animazioni UI e pulsazioni.

### Pipeline Asset

- Convenzioni per sprite, atlanti, animazioni e licenze.
- Risorse visuali con fallback procedurale.
- Import preset coerenti per pixel filtering e compressione.
- Documento di attribuzione e provenienza degli asset.

### File e Sistemi Coinvolti

- impostazioni e salvataggi
- `game/visuals/`
- HUD e menu
- `WeaponVisualData` e future risorse visuali
- `assets/`
- test e profiling

### Criteri di Accettazione

- Le opzioni visuali persistono tra sessioni.
- Nessuna opzione modifica collisioni, timing o danno.
- Il gioco resta leggibile senza affidarsi solo al colore.
- Una scena puo passare da placeholder a sprite senza cambiare controller.
- Il frame time resta stabile nelle wave affollate sul target hardware.
- Tutti gli asset esterni hanno licenza e origine documentate.

### Test Richiesti

- Smoke test round-trip delle impostazioni.
- QA con profili default, ridotto movimento e alto contrasto.
- Profiling con quattro player, boss e roster misto.
- Regressione visuale e gameplay completa.

### Fuori Scope

- Supporto console certificato.
- Localizzazione completa.

---

## Backlog Trasversale

Questi task possono essere affrontati solo quando non allargano una milestone
in corso:

- stabilizzare lo shutdown headless Godot 4.6.3, inclusi warning `ObjectDB`
  e l'access violation intermittente gia riproducibile sul commit di partenza;
- ampliare i test automatici dei lifecycle runtime;
- firmare digitalmente la build Windows pubblica;
- aggiungere diramazioni, shop e mappa al dungeon;
- aggiungere upgrade, vendita e nuovi tipi torre;
- introdurre nuove armi e un inventario esplicito;
- migliorare bilanciamento dopo playtest reali con 2-4 player.

## Definition of Done per Ogni Milestone

Una milestone del ciclo e completata solo quando:

1. il design e documentato prima o insieme al codice;
2. i sistemi condivisi vengono riusati invece di duplicati;
3. la scena principale parte senza errori;
4. esiste almeno uno smoke test o un test futuro motivato;
5. esiste una checklist manuale ripetibile;
6. survival, dungeon e tower defense sono verificati;
7. il QA visuale include quattro player quando la feature appare in survival;
8. `CHANGELOG.md`, `TODO.md`, `ROADMAP.md`, `ARCHITECTURE.md` e
   `GAME_DESIGN.md` vengono aggiornati quando pertinenti.
