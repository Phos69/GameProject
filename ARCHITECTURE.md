# ARCHITECTURE

## Visione tecnica

Il progetto e un sandbox Godot 4.x 2D con resa pseudo-isometrica. La scena principale avvia un playground minimo e registra i sistemi base. Le modalita future devono usare sistemi comuni invece di duplicare gameplay.

## Flusso runtime attuale

1. `main.tscn` carica manager, world e `MainMenu`.
2. `GameModeManager` entra nello stato `menu` senza avviare gameplay.
3. `SaveManager` carica progressione party, unlock e ultima modalita da JSON.
4. `MainMenu` seleziona una modalita registrata; per survival apre prima
   `Character Select`, dove tastiera/mouse/pad 0 guidano il focus del Giocatore
   1 e ogni pad aggiuntivo controlla lo slot corrispondente con cursore e
   conferma indipendenti. La schermata accetta `Start`/`pause` solo dagli slot
   attivi con selezione valida e passa `character_ids_by_slot` nel context, con
   `character_id` come fallback legacy.
5. `SettingsPanel` e condiviso da main menu e pausa, con tab Audio, Video e
   Controls; LB/RB cambiano tab in modo circolare e rifocalizzano il contenuto.
6. `InputManager` registra azioni tastiera/joypad e applica i binding joypad
   persistenti a tutti gli slot.
7. `LocalMultiplayerManager` mantiene gli slot locali attivi.
8. `PlayerManager` ascolta gli slot attivi e spawna/despawna i player.
9. `PlayerController` legge input solo quando una modalita gameplay e attiva.
10. `PauseMenu` intercetta l'azione `pause`, mette in pausa il tree e consente
   resume, settings, ritorno al menu o quit.
11. `WeaponSystem` gestisce un `PlayerWeaponInventory` per-player: l'istanza
    base e separata dalla collezione, mentre ogni arma raccolta conserva ammo,
    reload, cooldown, carica e stato temporaneo e la selezione resta un indice.
12. `WeaponData` inoltra l'eventuale `WeaponVisualData` a player, HUD,
    proiettile o hitbox melee temporanea.
13. `ProjectileSystem` spawna proiettili ranged; `MeleeAttack` copre i colpi
    melee temporanei. Entrambi applicano danno tramite `HealthSystem`.
14. `EnemySystem` spawna basic, runner, tank e shooter; gli archetipi riusano targeting, health, scaling, morte e drop condivisi.
15. Alla morte, il nemico chiede a `DropSystem` di generare pickup dalla propria `LootTable`.
16. `DropPickup` delega l'applicazione della ricompensa a `DropSystem`.
17. `GameModeManager` avvia `SurvivalMode`, che applica il profilo RPG scelto e seleziona un profilo arena tramite `SurvivalArenaManager`.
18. `ZombieModeController` avvia i componenti revamp zombie e forza il bioma iniziale tramite `BiomeManager`.
19. `BiomeManager` genera una megamappa seed-based tramite `BiomeWorldGenerator`, con territori default `3x3` da `500x500`, grafo connesso, passaggi condivisi, fall boundary, layout validati e regione corrente.
20. `WorldRuntime` mantiene grafo, stato esplorazione, regione corrente e stato persistente sovrapposto al layout rigenerato dal seed.
21. `RegionSeamSystem` legge posizione world-space del party, grafo e
    `WorldRegionConnection` aperti per aggiornare la regione corrente senza
    portali, trigger visibili o teletrasporto.
22. `WorldRegionStreamer` mantiene la regione corrente e i vicini connessi come
    contenuto gameplay attivo: tile, ostacoli, hazard/fall zone e crate sono
    gia presenti prima dell'attraversamento.
23. `SurvivalArenaManager` configura playground, player, crate, gate e fallback spawn per lo spawner.
24. `HazardSystem` genera fall zone e hazard ambientali, aggiorna posizioni sicure, status e modificatori movimento.
25. `WaveManager` interroga `WaveDirector` per roster/scaling bioma e `ZombieSpawner` per spawn dai bordi camera, poi crea zombie tramite `EnemySystem`.
26. `SurvivalMode` usa `GameModeManager` e `BossSystem` per creare il boss della quinta ondata.
27. `WaveManager` conta scorte e boss prima di assegnare la ricompensa.
28. `DungeonMode` genera un layout da seed, istanzia una `DungeonRoom` alla volta e usa nemici, drop e boss condivisi.
29. `DungeonRoom` controlla pareti, portale e stato locked/unlocked della stanza corrente.
30. `TowerDefenseMode` gestisce lifecycle, arena, player e richieste costruzione.
31. `TowerDefenseWaveController` governa ondate e usa `EnemySystem` per i nemici da percorso.
32. `TowerDefenseManager` mantiene vita core e crediti, mentre gli slot delegano lo spawn delle torri.
33. `DefenseTower` seleziona target e inoltra direzione e fuoco a `DefenseTowerVisual`.
34. `ProgressionManager` prepara i player a ogni nuova run applicando gli unlock persistenti.
35. `ReviveSystem` coordina prossimita, interact tenuto e progresso per i player downed.
36. `SurvivalAmmoDirector` osserva l'ammo speciale dei player vivi e genera supply crate configurabili.
37. `AudioEventRouter` traduce eventi gameplay in cue richiesti ad `AudioManager`.
38. `AudioManager` gestisce bus, fallback, stream opzionali, priorita e volumi.
39. `VideoSettingsManager` applica fullscreen, borderless, risoluzione, VSync
   e limite framerate.
40. `VisualSettingsManager` distribuisce solo impostazioni presentazionali e le persiste nel save.
41. `IsometricCameraController` segue il gruppo e applica shake solo tramite offset.
42. `HUDManager` mostra schede slot leggere negli angoli, boss, mappa
    esplorazione e il pannello status persistente solo per Tower Defense;
    Survival/Infinite Arena lo tengono nascosto e `PlayerWorldHudVisual`
    mantiene sopra ogni player vita, ammo/reload, livello, EXP e super. I suoi
    riferimenti a mode, wave, boss, drop, world runtime, bioma e hazard sono
    NodePath/cache locali, con fallback a gruppi solo per scene isolate.
43. I componenti visuali ricevono stato e profilo senza possedere logica gameplay.
44. `BossTelegraphVisual` riceve pattern, direzione e durata senza possedere danno.
45. `WaveWardenVisual` e `RiftArchitectVisual` ricevono solo stato presentazionale.
46. `CombatAnnouncement` presenta segnali wave e boss tradotti da `HUDManager`.
47. `GameplayEffects` ascolta segnali pubblici e genera effetti temporanei.
48. `RunSessionTracker` misura durata e delta progressione tra start e fine run.
49. `RunResultsScreen` presenta il risultato e delega retry/menu/cambio.

## Sistemi principali

- `InputManager`: crea e legge azioni per slot player e globali. Ogni slot usa azioni `p{slot}_{azione}`, incluso `dodge`; `world_map` e una azione globale; `ui_cancel` mappa `Esc` e joypad `B` per tornare dai pannelli menu; `ui_up/down/left/right` includono frecce, D-pad e stick sinistro per la navigazione UI.
- `MenuNavigationController`: helper UI riusabile per liste focus circolari,
  Back/B, input D-pad/stick con cooldown, cambio tab LB/RB e callback di
  movimento custom quando una schermata deve interpretare le quattro direzioni.
- `LocalMultiplayerManager`: mantiene gli slot locali attivi, gestisce join/leave e usa mapping deterministico `device joypad + 1 = player_slot`.
- `PlayerManager`: spawna/despawna player in base agli slot attivi e tiene il registro degli slot; risolve via NodePath le dipendenze runtime principali e le inietta nei `PlayerController` istanziati.
- `PlayerController`: movimento, mira, attacchi base/equipaggiato, dodge/roll, stato entity
  `normal/dodging/falling/dead` e colore visuale per slot; riceve
  `InputManager`, `GameModeManager` e `HazardSystem` da `PlayerManager`, con
  fallback a gruppi solo per uso isolato della scena player.
- `PlayerDodgeComponent`: roll con cooldown, invulnerabilita breve, blocco
  del fuoco durante la schivata e validazione di landing/gap/ostacoli; solo le
  fall zone sono trattate come gap attraversabili, mentre gli hazard
  ambientali bloccano traiettoria e landing. Il controllo void e sospeso
  durante il movimento e viene rieseguito sulla posizione finale.
- `EntityVoidFallComponent`: animazione condivisa player/zombie con lock
  temporaneo, discesa world-space, riduzione scala/alpha e callback di impatto;
  non applica direttamente danni o reward.
- `ReviveSystem`: progresso cooperativo centralizzato per target downed e reviver vicino.
- `GameModeManager`: registra, arresta e avvia le modalita.
- `RunSessionTracker`: traduce i segnali terminali in dati risultato runtime.
- `RunResultsScreen`: overlay condiviso con focus e azioni di fine run.
- `MainMenu`: UI iniziale, selezione modalita, `Character Select` survival per
  slot player, continue e ritorno con `Esc`/joypad `B`; usa
  `MenuNavigationController` per focus/back coerenti, grid navigation della
  roster, cursori indipendenti dei pad aggiuntivi e avvio con `Start`/`pause`
  solo quando gli slot attivi sono validi.
- `CharacterSelectCard`: card RPG selezionabile con portrait menu dedicato,
  fallback gameplay/procedurale, icone classe/arma, stat bar compatte e
  indicatori slot, inclusi anelli cursore e pip di commit per-player.
- `CharacterDetailPanel`: dossier scrollabile della Character Select con
  descrizione stile, stat leggibili, range arma e preview, aggiornato dal focus
  della card roster corrente.
- `CharacterGameplayPreview`: preview procedurale isometrica del personaggio selezionato, con silhouette, palette e arma derivate dal profilo.
- `RpgCharacterRegistry`: catalogo centralizzato dei personaggi RPG iniziali.
- `RpgCharacterData`: risorsa dati per un profilo classe RPG selezionabile, inclusi nome proprio, descrizione stile, palette e riferimenti asset opzionali per portrait, preview gameplay, sprite, arma e icone.
- `RpgPlayerComponent`: profilo RPG runtime, statistiche, XP per-run, adrenalina, passive automatiche, companion RPG, super e formule danno del player survival.
- `RpgSuperResolver`: esecuzione delle super RPG usando `ProjectileSystem`, `HealthSystem` e bersagli damageable condivisi, incluse meteora arcana e trasformazione licantropo.
- `SaveManager`: persistenza JSON versionata e autosave di progressione, impostazioni e stato mondo/esplorazione.
- `VisualSettingsManager`: preset, valori visuali, notifica consumer e persistenza.
- `VideoSettingsManager`: stato finestra, fullscreen, borderless, risoluzione,
  VSync e limite framerate persistenti.
- `AudioManager`: bus, cue, fallback procedurali, stream opzionali e volumi.
- `AudioCueData`: contratto sostituibile per asset e fallback.
- `AudioVoicePool`: limite voci e sostituzione guidata dalla priorita.
- `AudioEventRouter`: hook gameplay separati dalla riproduzione audio.
- `WeaponData`: risorsa immutabile con statistiche gameplay, `attack_type`,
  timing melee, metadati catalogo/effetti e riferimento visuale opzionale.
- `WeaponInstance`: stato runtime persistente di una singola definizione.
- `PlayerWeaponInventory`: istanza base separata, collezione ordinata delle
  armi raccolte e indice equipaggiato.
- `WeaponCatalog`: registry centralizzato di 30 armi drop con ID stabili.
- `WeaponCatalogVisualPalette`: tabella presentazionale separata dal catalogo
  gameplay; assegna body, accent e glow per `weapon_id` e rende esplicito un
  profilo mancante durante lo sviluppo.
- `WeaponEffectResolver`: risoluzione condivisa di AOE, status, chain,
  knockback, delayed explosion e ground hazard.
- `WeaponVisualData`: palette, dimensioni, profilo legacy, ID visuali opzionali
  per target, family, outline/glow, scale e sprite path condivisi da arma, HUD,
  proiettile e flash.
- `WeaponVisualRenderer`: helper condiviso che risolve fallback, silhouette e
  asset opzionali da `WeaponVisualData`, inclusi projectile, muzzle, slash e
  impact, delegando le geometrie procedurali statiche a
  `WeaponVisualShapeLibrary` senza spostare regole di combat nei consumer
  visuali.
- `WeaponVisualShapeLibrary`: libreria presentazionale delle shape statiche per
  pickup, dettagli e projectile; non legge `WeaponData`, non applica danno e
  resta dietro l'API pubblica di `WeaponVisualRenderer`.
- `WeaponSystem`: loadout runtime per-player, attacchi indipendenti base/
  equipaggiato, switch circolare delle sole armi raccolte e dispatch tra
  projectile e melee.
- `MeleeAttack`: hitbox temporanea world-space per swing melee con wind-up,
  active time, recovery tramite cooldown, anti-multihit per bersaglio e
  feedback trail derivato dal profilo visuale; applica anche knockback e
  hitstop configurati in `WeaponData`.
- `ProjectileSystem` e `Projectile`: spawn, movimento, collisione e consegna del danno.
- `HealthSystem` e `HealthComponent`: richieste globali di danno/cura, stato vita locale e invulnerabilita componibile per sorgente; il danno ambientale puo ignorarla esplicitamente.
- `EnemySystem`: registro di scene nemico per ID, spawn, contenitore, registro runtime e notifica morte. In survival assegna `spawn_region_id` dalla posizione world-space tramite `RegionSeamSystem`.
- `BasicEnemy`: AI melee condivisa con stati idle, chase, attack e dead; resta
  world-space durante il chase cross-bioma e traccia `spawn_region_id`,
  `current_region_id` e `last_seen_player_region_id` senza modificare target,
  health, status o drop.
- `RangedEnemy`: specializzazione di `BasicEnemy` con distanza preferita, windup e proiettile ostile.
- `ZombieVisual`: profili procedurali basic, runner e tank senza autorita gameplay.
- `EnemyShotTelegraphVisual`: corsia e countdown ranged senza collisioni o danno.
- `BossSystem`: registro scene/compatibilita, spawn per ID, boss attivo e notifica sconfitta.
- `BasicBoss`: boss modulare con targeting, movimento, fasi e pattern proiettile.
- `RiftArchitect`: secondo boss con lane sweep, cross burst e visual dedicato.
- `SurvivalMode`: ciclo survival, condizione di sconfitta e inoltro richieste boss.
- `ZombieModeController`: coordinatore interno del revamp survival per bioma, terrain, casse, ostacoli e hazard.
- `BiomeManager`: registro biomi, regione/bioma corrente, layout procedurale corrente e selezione iniziale della `Pianura Infetta`.
- `WorldGraph`: grafo seed-based dei territori, connesso tramite spanning tree ed edge extra, con API per raggiungibilita e connessioni fisiche.
- `WorldRegion`: dati stabili di un territorio `500x500`, inclusi biome ID, coordinate, origine mondo, vicini, connessioni e layout generato.
- `WorldRegionConnection`: edge navigazionale tra due regioni confinanti, con lato, direzione opposta, centro/larghezza del passaggio e coordinate globali.
- `WorldExplorationState`: stato unknown/discovered/visited/cleared per regione e marker della regione corrente.
- `PersistentWorldState`: payload serializzabile del mondo, seed, regione corrente, posizione party e stato esplorazione.
- `WorldRuntime`: runtime del grafo persistente; sincronizza `BiomeManager`, exploration state e save/load, con spazio per streaming regioni.
- `WorldRegionStreamer`: streamer gameplay multi-regione; istanzia regione
  corrente e vicini connessi a offset derivati da `WorldRegion.world_origin`,
  con tile layer, ostacoli, hazard/fall zone e crate gia presenti prima
  dell'attraversamento. Registra i nodi nei sistemi zombie esistenti, cosi
  query di collisione, safe position, danno da caduta e ledger crate restano
  centralizzati.
- `MultiRegionRenderer`: prototipo/fallback visuale storico; conserva il
  contratto dei vicini solo ground per test e debug. Non viene creato durante
  la risoluzione componenti della survival standard; `ZombieModeController` lo
  istanzia solo come fallback lazy se `WorldRegionStreamer` non puo streamare.
- `WorldGenerationSeed`: seed globale di run e derivazione deterministica degli stream RNG per mappa, terreno, ostacoli, bordi, loot e spawn.
- `BiomeWorldGenerator`: orchestratore della pipeline procedurale globale per mappa biomi, layout per cella e debug seed.
- `BiomeMapGenerator`: costruisce la griglia di `BiomeCell` `500x500` con default `3x3`, assegna tipi bioma, coordinate globali, vicini, seed locali e grafo connesso con loop.
- `BorderGenerator`: calcola lati connessi e lati esterni di caduta per ogni cella bioma.
- `BiomePassageGenerator`: crea passaggi condivisi e allineati tra celle
  confinanti, con larghezza fisica standard di 40 celle, rettangoli
  local/global e tile entry/exit derivati dal `passage_type`.
- `BiomeTerrainGenerator`: genera il layout interno del bioma attivo e collega
  ostacoli, casse, hazard, summary deterministico e report di validazione.
- `IsometricEnvironmentManifest`: legge `assets/environment/isometric/manifest.json`
  come inventario di ostacoli, draw mode oggetto, border tematici, fall zone
  procedurali, tag terrain generati e contratto asset v9 (`tile_sets`,
  `tile_variants`, `terrain_tiles`, `edge_tiles`, `void_tiles`, `object_scenes`,
  `passage_tiles`, `biome_asset_sets`, `fallback_policy`). Il loader normalizza
  path, status, footprint, anchor, collisione, blocchi e attribution senza
  rendere obbligatori asset esterni.
- `ObstacleLayoutGenerator`: produce strade e sentieri isometrici con scala
  standard 40 celle per strade principali e 20 celle per sentieri medi,
  diramazioni verso i passaggi, case grandi, ostacoli secondari e muri/bordi
  tematici sui lati connessi o bloccati. Nel bioma starter garantisce anche
  una `ruined_house`, vegetazione densa impassabile, auto abbandonate,
  un fiume `deep_water` segmentato e bridge sui crossing.
- `FallBoundaryGenerator`: trasforma i lati senza vicino in `fall_zone` data-driven con il contratto di danno ambientale esistente.
- `MapValidationSystem`: valida con flood-fill spawn, corridoi, passaggi, casse
  raggiungibili, grafo connesso, passaggi non ostruiti, void non attraversabile
  e classificazione completa del `500x500`. `deep_water` blocca pathfinding
  salvo celle bridge; i crossing d'acqua richiedono bridge solo nei layout che
  dichiarano un fiume nello `generation_summary`.
- `BiomeMapDebugOverlay`: espone seed corrente, riepilogo celle/passaggi,
  metriche di generazione (strade, sentieri, case, vegetazione densa, bridge,
  fiumi, acqua, auto, fence), classi terrain aggregate, il report di
  connettivita del grafo (`WorldGraph.get_connectivity_report()`), regione
  corrente e active regions caricate, con toggle `F8`, e richieste di
  rigenerazione per debug.
- `BiomeDefinition`: risorsa dati con terreno, ostacoli, casse, zombie ammessi, pesi, palette e moltiplicatori.
- `RegionSeamSystem`: tracker world-space della regione survival corrente.
  Converte la posizione del party in tile globali, verifica che il bordo
  attraversato appartenga a un `WorldRegionConnection` aperto e aggiorna
  `BiomeManager`/`WorldRuntime` senza creare `Area2D` o marker di transizione.
- `BiomeTransitionSystem`: API legacy/debug per forzare `transition_to()` negli
  smoke e nei tool esistenti; non istanzia piu `BiomeTransitionGate` nel
  runtime survival standard.
- `BiomeTransitionGate`: classe storica mantenuta per compatibilita dei test di
  dimensionamento/span; non e piu creata dalla survival.
- `BiomeEnvironmentLayout`: placement deterministico di floor scavati,
  `road_cell_tags`, rettangoli di apertura, blocchi interni, bridge,
  water/deep-water rects, ostacoli fisici, casse e hazard per un bioma, con
  classificazione completa del `500x500` e `generation_summary` per debug.
- `WaveDirector`: composizione wave e scaling basati sul bioma corrente.
- `ZombieSpawner`: spawn dai bordi della camera con distanza minima dai player,
  validazione walkable/hazard/ostacoli/blocker e fallback arena solo se valido.
  Riceve obstacle, hazard, biome manager, seam system e world streamer da
  `ZombieModeController`, evitando lookup globali ripetuti nel path spawn.
  Espone motivo di scarto e report tentativi per test/debug; nella megamappa
  valida le posizioni contro regioni streamate world-space invece del solo
  layout locale corrente.
- `TerrainGenerator`: applica la palette del bioma, genera il piano visuale
  `500x500` e legge gli stili terrain dal manifest. Nel percorso standard
  registra il tile layer streamato; patch e ground procedurali restano fallback
  espliciti.
- `BiomeRegionGround`: base visuale estesa dell'intero territorio, separata
  dalle patch decorative puntuali, con `sample_step` guidato dai preset del
  manifest. E un fallback tecnico, non un nodo della survival standard
  asset-driven.
- `BiomeTerrainPatch`: patch decorativa procedurale che usa draw mode
  data-driven per strade, passaggi e dettagli bioma senza possedere collisioni.
  Rimane per fallback/test legacy e non viene istanziata quando il tile layer
  asset-driven e attivo.
- `ObstacleSystem`: genera e registra ostacoli fisici usati anche come spawn
  blocker; nel percorso asset-driven delega a `IsometricEnvironmentObjectFactory`.
- `IsometricEnvironmentObjectFactory`: legge il contratto `object_scenes` dal
  manifest e istanzia `IsometricEnvironmentObject` quando esiste un asset,
  lasciando `BiomeObstacle` come fallback tecnico esplicito.
- `IsometricEnvironmentObject`: scena base `StaticBody2D` per oggetti
  slot-based con `Sprite2D`, ombra, anchor/footprint debug opzionale,
  collisione/layer/sort dal manifest e hook futuri per overlay danneggiato.
- `BiomeObstacle`: fallback compatibile che conserva draw mode procedurali
  data-driven dal manifest per distinguere gli ostacoli dei biomi senza cambiare
  collisioni o placement.
- `BiomeObstaclePainter`: helper presentazionale usato da `BiomeObstacle` per
  muri perimetrali e boundary tematiche; riceve solo canvas, colori, draw mode e
  dimensioni, senza leggere manifest o modificare collisioni.
- `ResourceCrateSystem`: genera casse ambientali raggiungibili riusando `SupplyCrate` e `DropSystem`.
- `BiomeFallZone`: `Area2D` fisica e leggibile generata dai dati del bioma,
  con stile cliff/depth procedurale.
- `BiomeHazardZone`: area dati per danno periodico, slowdown e hazard runtime.
- `HazardSystem`: coordina fall zone e hazard, valida posizioni sicure/spawn,
  espone query separate per fall zone e hazard ambientali, e gestisce il
  recupero da caduta.
- `BiomeHazardCatalog`: mantiene configurazione e resa cromatica degli hazard ambientali.
- `BiomeStatusRuntime`: applica danno periodico, status temporanei e modificatori movimento ai player.
- `BiomeEnemyProfile`: statistiche e tratti tematici riusabili da `BasicEnemy`.
- `SurvivalArenaManager`: selezione profilo e configurazione dei sistemi survival.
- `SurvivalArenaProfile`: dati di layout, spawn, player, crate, boss e props.
- `BiomePalette`: palette ambientale indipendente dal controller.
- `SpawnGateVisual`: ingresso non collidente con feedback sugli spawn reali.
- `ExplosiveBarrel`: prop damageable non bloccante con warning e danno ad area.
- `WaveManager`: macchina a stati per intermissione, spawn, combat, reward e boss wave.
- `SurvivalAmmoDirector`: supporto anti-frustrazione esclusivo della survival.
- `DungeonGenerator`: generazione deterministica dei dati layout dungeon.
- `DungeonMode`: avanzamento stanza, encounter, loot, boss e completamento run.
- `DungeonRoom`: rappresentazione riusabile della stanza attiva e portale di transizione.
- `TowerDefenseMode`: lifecycle della modalita, arena, player, costruzione e pulizia runtime.
- `TowerDefenseWaveController`: macchina a stati per intermissione, spawn, combat, boss e reward.
- `TowerDefenseManager`: vita core, crediti di run e acquisto centralizzato delle torri.
- `TowerDefenseArena`: percorso, rappresentazione core, spawn party e slot costruzione.
- `TowerDefenseEnemy`: movimento a waypoint, danno al core e contratto health/drop condiviso.
- `TowerBuildSlot`: rileva il player e inoltra la richiesta di costruzione.
- `DefenseTower`: targeting automatico e sparo tramite `ProjectileSystem`.
- `DefenseTowerVisual`: base, canne, tracking, idle scan e feedback di fuoco senza logica gameplay.
- `DropEntry` e `LootTable`: dati tipizzati per chance, quantita e arma associata.
- `DropSystem`: roll, spawn pickup e applicazione centralizzata delle ricompense.
- `DropPickup`: rappresentazione fisica e raccolta da parte dei player.
- `SupplyCrate`: contenitore fisico configurato da `LootTable` per ammo e cura.
- `ProgressionManager`: XP, livello, denaro, unlock party e bonus di inizio run.
- `SettingsPanel`: pannello UI condiviso con tab Audio, Video e Controls;
  usa `MenuNavigationController` per focus circolare, Back e tab LB/RB.
- `PauseMenu`: overlay durante le run; usa `SceneTree.paused` e resta attivo
  insieme alla propria UI.
- `HUDManager`: UI prototipo per HUD gameplay, boss, annunci, mappa
  esplorazione e status Tower Defense; ancora le schede player ai quattro
  angoli senza duplicare le informazioni immediate del pacchetto world-space.
  Il `StatusPanel` persistente e owner della telemetria Tower Defense e resta
  nascosto in Survival/Infinite Arena.
- `ExplorationMapPanel`: pannello consultabile che disegna grafo, fog/unknown, regioni discovered/visited/cleared, connessioni note tematizzate per `passage_type`, marker per le active/loaded regions e regione corrente; consuma `apply_visual_settings` per il high contrast.
- `OffscreenEnemyMarkers`: overlay HUD che converte i minion del gruppo
  `enemies` fuori dalla visuale in frecce ancorate al bordo del viewport; deriva
  colore dal `theme_id` del `BiomeEnemyProfile`, dimensione e opacita dalla
  distanza dal party, esclude i nemici on-screen e i boss, limita il numero di
  marker e rispetta high contrast e reduced motion. La logica di calcolo vive in
  `compute_markers()` separata dal `_draw` per essere testabile in headless; non
  possiede ne modifica stato gameplay.
- `PlayerVisual`: presentazione procedurale data-driven del player, con
  silhouette e palette derivate dal profilo RPG; disegna l'arma equipaggiata
  tramite `WeaponVisualRenderer` e non possiede piu il mini HUD.
- `PlayerWorldHudVisual`: pacchetto UI world-space child del player; legge
  `HealthComponent`, `WeaponSystem` e `RpgPlayerComponent` e disegna il livello
  con gauge EXP circolare, vita orizzontale su due righe a soglie
  verde/arancio/rosso, ammo/reload in basso e super verticale. Quando la super
  e pronta applica un glow blu
  all'intero faceplate; il bordo mantiene il colore slot senza mostrare P1-P4.
- `ZombieVisual`: presentazione animata procedurale degli zombie.
- `DropPickupVisual` e `SupplyCrateVisual`: icone world-space sostituibili; i
  drop arma ricevono `WeaponData.visual_data` e disegnano la silhouette pickup
  tramite `WeaponVisualRenderer`, mentre XP, money, ammo e health mantengono le
  icone dedicate. La supply crate usa `object_scenes/supply_crate` come sprite
  asset-backed e conserva il draw procedurale solo come fallback tecnico.
- `BossTelegraphVisual`: warning world-space per pattern aimed, radial e cambio fase.
- `WaveWardenVisual`: silhouette, animazione e stato visuale delle due fasi del boss.
- `PlayerHudCard`: scheda HUD riusabile per ogni slot locale, pensata come
  pannello statistiche angolo con ritratto, arma, riserva/stato speciale,
  statistiche, passive e status; caricatore, reload, EXP e super restano nel
  `PlayerWorldHudVisual`.
- `CharacterSelectCard`, `CharacterDetailPanel` e `CharacterGameplayPreview`: controlli presentazionali della selezione RPG, senza autorita su context survival o applicazione profili.
- `RpgHudIcon`: icona procedurale leggera per ritratto classe, passive e super RPG.
- `BriciolaCompanion`: companion alleato leggero della Domatrice con follow,
  target acquire, dash attack, recover e frenzy super bounded; e `Node2D`
  visuale/assistivo, senza collisione fisica con Nina.
- `ReviveIndicatorVisual`: anello world-space con colore slot e progresso.
- `WeaponIcon`: icona HUD generata dal profilo dell'arma attiva tramite
  `WeaponVisualRenderer`, allineata alla silhouette pickup/held.
- `CombatAnnouncement`: banner temporaneo e riusabile per transizioni gameplay.
- `GameplayEffects`: feedback visuale event-driven, inclusi muzzle/impact
  temizzati, level-up e super RPG tipizzate per starter e classi avanzate,
  senza dipendenze dai controller.

### Ownership HUD gameplay

| Dato | Owner UI | Note |
| --- | --- | --- |
| Slot player, ritratto, classe, arma equipaggiata | `PlayerHudCard` | Riepilogo stabile ai quattro angoli. |
| Riserva ammo, stato speciale, inventario arma | `PlayerHudCard` | Non rappresenta caricatore o reload in tempo reale. |
| Statistiche RPG, passive e status temporanei | `PlayerHudCard` | Sintesi compatta; i dettagli immediati restano vicino al player. |
| HP, caricatore, reload, livello, EXP e super | `PlayerWorldHudVisual` | Feedback reattivo sopra il player, leggibile nel punto di azione. |
| Boss, annunci, mappa esplorazione e aggregazione modalita | `HUDManager` | Non duplica la telemetria per-player gia mostrata nei componenti dedicati. |
| Status panel Tower Defense | `HUDManager` | Visibile solo in `TowerDefenseMode`, ancorato al centro alto sotto il boss HUD e fuori dalle corner card. |
| Status panel persistente in Survival/Infinite Arena | `HUDManager` | Nascosto durante il gameplay standard; wave e reward usano annunci temporanei o world HUD. |

## Contratto fine run

- Le modalita restano proprietarie dei propri segnali di vittoria o sconfitta.
- `RunSessionTracker` calcola tempo, XP, denaro, unlock e progresso raggiunto.
- `GameModeManager.finish_run()` blocca il gameplay senza cambiare subito l'ID modalita.
- Il runtime terminale viene pulito su retry, menu o cambio modalita.
- Retry riusa il nodo registrato e l'ultimo context.
- Il ritorno al menu salva prima di emettere il cambio modalita.

## Contratto audio

- I bus `UI`, `Weapons`, `Enemies`, `Boss` ed `Environment` inviano a `SFX`.
- `AudioCueData.optional_stream` e facoltativo; il fallback resta sempre valido.
- `AudioVoicePool` non supera il limite configurato e preserva cue prioritari.
- `AudioEventRouter` puo cambiare senza modificare i sistemi gameplay.
- In headless `AudioManager` simula fallback e stream opzionali senza creare
  player audio o `AudioStreamGeneratorPlayback` runtime.
- `shutdown_audio()` ferma e libera voice pool e generatori procedurali prima
  dello shutdown del tree.
- Master, Music e SFX sono persistiti nel save v6.

## Contratto impostazioni visuali

- `VisualSettingsManager` non dipende da health, collisioni o controller.
- I consumer implementano `apply_visual_settings(settings)`.
- I consumer visuali isolati possono sincronizzarsi dal gruppo
  `visual_settings_manager` senza una dipendenza statica obbligatoria.
- Flash, glow, trail, shake e scala testo sono clampati.
- Reduced motion agisce solo su clock, pulse, bob, scale UI e camera offset.
- High contrast rafforza bordi, warning e marker geometrici.
- Circle, triangle, square e diamond identificano P1-P4 oltre al colore.
- Pickup e crate conservano icone e silhouette indipendenti dalla palette.
- Il cambio profilo non modifica damage, velocity, cooldown o hitbox.

## Contratto impostazioni video e controlli

- `VideoSettingsManager` applica solo stato finestra e frame pacing:
  display mode, borderless, risoluzione, VSync e `Engine.max_fps`.
- In headless le impostazioni video restano serializzabili senza chiamate
  finestra non disponibili.
- `InputManager` mantiene binding joypad device-agnostic e li applica alle
  azioni `p{slot}_{action}` con il device corretto dello slot.
- La rimappatura joypad non rimuove i fallback tastiera di player 1.
- `dodge` e una azione per-slot: tastiera `Shift`/`Ctrl` per player 1 e
  joypad `B` per lo slot associato.
- `world_map` e una azione globale: tastiera `M` e joypad `Back/Select/View`.
- `pause` e una azione globale mappata di default su joypad `Start` e tastiera
  `P`.
- `LocalMultiplayerManager` serializza separatamente i pulsanti joypad di
  join e leave.
- `SettingsPanel` e l'unico punto UI per modificare audio, video e controlli,
  sia dal main menu sia dal pause menu.

## Contratto presentazione visuale

- Controller, collisioni, health, armi, wave e drop restano autoritativi.
- I nodi visuali ricevono solo stato, direzione, velocita e richieste di feedback.
- Sostituire un placeholder con sprite o animazioni non deve cambiare scene manager o sistemi gameplay.
- Lo sfondo survival usa colori meno saturi e meno luminosi degli attori.
- Il colore slot resta il primo identificatore del player nel multiplayer locale.
- Pickup e supply crate devono essere riconoscibili dalla forma e dal colore senza dipendere da label world-space.
- I pickup arma usano `WeaponVisualData.pickup_shape_id`; se il profilo manca,
  `DropPickupVisual` mostra un marker `missing_weapon_visual` esplicito.
- I telegraph boss mostrano direzione, area e durata prima del danno e non possiedono collisioni.
- `WaveWardenVisual` riceve solo stato presentazionale da `BasicBoss`.
- Gli annunci HUD reagiscono ai segnali pubblici e non pilotano wave o boss.
- Pickup arma, arma world-space, icona HUD, proiettile e muzzle flash leggono
  lo stesso `WeaponVisualData`.
- Gli impact projectile leggono kind, colore, size e shake da
  `WeaponVisualData`/`WeaponVisualRenderer`; questi valori sono
  presentazionali e non modificano danno, collisioni o timing.
- Gli slash e gli hit effect melee leggono `slash_shape_id`, `impact_shape_id`
  e `impact_vfx_id` tramite `WeaponVisualRenderer`; la hitbox resta definita da
  `WeaponData.attack_type`, `melee_*` e `hitbox_*`.
- Ritratto classe e icona super RPG sono disegnati da `RpgHudIcon` e non alterano stats, input o cooldown.
- `DefenseTowerVisual` riceve mira e feedback ma non sceglie target, range, danno o fire rate.
- `GameplayEffects` reagisce a segnali pubblici e non applica danno, cura o ricompense.
- Level-up e super RPG emettono segnali dal `RpgPlayerComponent`; feedback visuale e audio li consumano senza modificare stats o cooldown.
- I bersagli combat debug restano istanziati ma invisibili e senza collisione nel gameplay normale; lo smoke test combat abilita la fixture usata.

### Contratto visuale delle armi

`WeaponData.visual_data` e l'unica sorgente visuale passata ai consumer:

```text
WeaponData.visual_data
  -> DropPickupVisual        pickup_shape_id
  -> PlayerVisual            held_shape_id
  -> WeaponIcon              hud_shape_id
  -> Projectile              projectile_shape_id, trail e glow
  -> GameplayEffects         muzzle_shape_id, impact_shape_id, impact_vfx_id
  -> MeleeAttack             slash_shape_id e hit feedback
```

- `profile_id` identifica il profilo stabile; per le 30 armi catalogo coincide
  con `weapon_id`. `family_id` resta `firearm`, `melee` o `elemental`.
- `primary_color`, `secondary_color` e `glow_color` descrivono corpo, accento e
  aura. Le palette catalogo vivono in `weapon_catalog_visual_palette.gd`, non
  nel controller né nel renderer.
- Gli ID target selezionano geometrie procedurali specifiche. Gli sprite path
  opzionali permettono di sostituirle con arte finale senza cambiare i consumer.
- `WeaponVisualRenderer` risolve shape, scale, colori ed effect kind; i consumer
  non aggiungono eccezioni per singolo `weapon_id`.
- Il fallback legacy basato su `profile_id` resta disponibile per armi storiche,
  boss e torri. Un pickup arma privo di profilo usa invece il marker esplicito
  `missing_weapon_visual`, mai un placeholder silenzioso.
- Hitbox, danno, timing, status e knockback restano in `WeaponData`,
  `Projectile`, `MeleeAttack` e `WeaponEffectResolver`: nessun campo visuale
  modifica il combat.

Per aggiungere una futura arma: registrare il `WeaponData`, assegnare un
`profile_id` stabile e una famiglia, definire palette e ID target pertinenti,
aggiungere la geometria o gli sprite opzionali al renderer e coprire il nuovo
ID negli smoke catalogo/pickup/projectile o melee e nella QA screenshot.

## Contratto combat

- Ogni istanza player possiede il proprio `WeaponSystem`; inventario, caricatore, riserva e cooldown non sono condivisi.
- Ogni `WeaponSystem` conserva sempre un'istanza base separata e un numero
  arbitrario di armi raccolte nell'inventario equipaggiabile.
- `WeaponData` resta definizione statica; ogni stato mutabile vive in `WeaponInstance`.
- Lo switch D-pad su/giu e circolare solo tra le armi raccolte e non cancella
  reload, cooldown o ammo.
- `base_attack` usa l'istanza base senza cambiare l'arma equipaggiata;
  `equipped_attack` usa esclusivamente l'arma raccolta selezionata.
- Con i binding default `RB` attiva `base_attack` e `LB` attiva
  `equipped_attack`; player 1 mantiene `Spazio` e `F` come fallback tastiera.
- Esaurire caricatore e riserva dell'arma equipaggiata non attiva uno switch
  implicito: l'arma base resta disponibile dal proprio input.
- L'arma base infinita conserva caricatore e reload; solo la riserva e
  virtualmente infinita.
- Un rifornimento della speciale vuota avvia il reload senza cambiare slot.
- Le statistiche di bilanciamento vivono in risorse `WeaponData`, non nel controller player.
- Le armi RPG di base sono `WeaponData` dedicate e vengono equipaggiate dal profilo `RpgPlayerComponent`.
- `WeaponData.max_range` limita la vita del proiettile o definisce la portata
  leggibile delle armi melee.
- `WeaponData.scatter_degrees` viene applicato da `WeaponSystem` alla direzione di sparo.
- `projectile_count`, `burst_count`, `charge_duration`, `windup_duration`,
  `effect_tags`, `aoe_radius`, `chain_targets`, `delayed_explosion` e
  `ground_hazard_duration` descrivono i comportamenti catalogo senza controller dedicati.
- `WeaponData.attack_type` decide il runtime: `projectile` usa
  `ProjectileSystem`, mentre `melee_arc`, `melee_rect`, `melee_sweep` e
  `dash_slash` usano `MeleeAttack`.
- `WeaponData.hitbox_type`, `hitbox_size` e `max_hit_count` configurano la
  collisione runtime separatamente dal visual; i campi `melee_*`,
  `windup_time`, `active_time`, `recovery_time`, `knockback`, `hitstop`,
  `trail_style`, `effect_key` e `sound_key` rifiniscono i colpi melee senza
  duplicare il sistema danni.
- Per le armi melee, `trail_style` puo indicare lo slash style visuale ma non
  modifica la collisione; `MeleeAttack` continua a creare la shape da
  `WeaponData.get_resolved_melee_shape()`.
- `WeaponSystem.get_reload_ratio()` espone il progresso reload; il moltiplicatore `reload_speed` RPG riduce la durata.
- `WeaponSystem` legge il moltiplicatore fire rate RPG solo dal componente del proprio player, usato dalla passiva `Mano Veloce`.
- Le passive RPG modificano danno, cadenza o mitigazione attraverso `RpgPlayerComponent`, senza duplicare collisioni o logica proiettile.
- Le super RPG consumano 100 adrenalina e delegano proiettili/danni ai sistemi condivisi, senza creare un combat path separato.
- L'adrenalina arriva da danno applicato, danno subito, kill confermate e reward wave survival.
- Palette, silhouette, trail, ID shape e sprite opzionali vivono in
  `WeaponVisualData` e non modificano il bilanciamento.
- `ProjectileSystem` riceve i dati dello sparo e configura il proiettile prima di aggiungerlo alla scena.
- Il parametro visuale di `ProjectileSystem` e opzionale per mantenere compatibili boss e chiamanti esistenti.
- `Projectile` usa `WeaponVisualRenderer` per risolvere poligono e glow,
  mantenendo i fallback legacy basati su `profile_id`.
- `Projectile` espone getter presentazionali per muzzle e impact usati da
  `GameplayEffects`; il movimento, la collisione e il danno restano invariati.
- Il proiettile non conosce classi nemico specifiche: colpisce body o area damageable e inoltra il danno a `HealthSystem`.
- `Projectile` emette l'impatto risolto e `ProjectileSystem` lo espone ai sistemi di feedback.
- `HealthSystem` cerca un figlio `HealthComponent` sul target; player, nemici, boss e bersagli debug possono condividere lo stesso contratto.
- `HealthSystem.apply_damage()` accetta una sorgente opzionale per applicare attacco/difesa RPG senza cambiare collisioni o AI.
- `HealthSystem` conserva la sorgente dell'ultimo danno valido per assegnare XP al killer.
- Collision layer `1`: player e corpi generici; gli ostacoli ambientali che
  bloccano il movimento restano su questo layer per fermare player e zombie.
- Collision layer `2`: bersagli damageable.
- Collision layer `4`: proiettili player; la mask colpisce il layer `2` e il
  layer `32` per fermarsi sui muri solidi.
- Collision layer `8`: pickup; la mask attuale rileva i player sul layer `1`.
- Collision layer `16`: proiettili ostili; la mask colpisce i player sul layer
  `1` e il layer `32` per fermarsi sui muri solidi.
- Collision layer `32`: ostacoli ambientali che bloccano i proiettili
  (`blocks_projectiles` nel manifest); un `BiomeObstacle` solido sta sul layer
  `1 | 32`. Il `Projectile` condiviso, su contatto con un nodo del gruppo
  `environment_obstacles` che dichiara `is_projectile_blocker()`, viene
  assorbito (queue_free) prima di applicare danno, ignorando il pierce residuo.
- `CombatTarget` e una fixture statica della scena principale per verificare il combat e non sostituisce l'AI nemica della Milestone 4.

## Contratto nemici

- `EnemySystem.spawn_enemy()` e il punto di ingresso per modalita e wave future.
- `EnemySystem` mantiene solo nemici validi in `active_enemies` ed emette `enemy_died`.
- `BasicEnemy` cerca periodicamente il player vivo piu vicino entro il detection range.
- Il target viene rivalutato anche quando un player lascia la sessione o muore.
- L'attacco inoltra il danno a `HealthSystem`; non modifica direttamente la vita del player.
- La morte nasce dal segnale `HealthComponent.died`, disabilita collisioni, genera drop e rimuove il nodo.
- I dati di movimento, detection, attacco, cooldown, vita e loot sono configurabili dalla scena o da risorse.
- `EnemySystem` registra `survival_runner`, `survival_tank` e `survival_shooter` su scene dedicate.
- Basic, runner e tank riusano `BasicEnemy`; lo shooter lo estende e sostituisce solo movimento e attacco.
- Il windup shooter blocca la direzione e crea il proiettile solo alla scadenza.
- `EnemyShotTelegraphVisual` riceve direzione e durata ma non possiede autorita gameplay.
- `ZombieVisual.archetype_id` cambia silhouette e animazione senza cambiare collisioni o statistiche.
- Runner: 18 HP, velocita 155, danno 6 e cooldown 0,62 secondi.
- Tank: 90 HP, velocita 58, danno 18 e cooldown 1,25 secondi.

## Contratto drop

- Ogni nemico possiede una `LootTable` composta da risorse `DropEntry`.
- `DropSystem` e l'unico sistema che esegue roll, crea pickup e applica ricompense.
- I pickup XP fisici aggiornano ancora `ProgressionManager` quando presenti.
- Gli zombie survival assegnano XP RPG direttamente al killer e non usano piu pickup XP.
- Le munizioni vengono applicate alle speciali di tutti i player vivi.
- Cura e nuova istanza arma vengono applicate al player che raccoglie.
- Un pickup non viene consumato se la ricompensa non puo essere applicata, per esempio cura su vita piena.
- Un pickup ammo non viene consumato se nessun player vivo possiede una speciale.
- Il drop arma aggiunge una `WeaponInstance` e la seleziona; un duplicato viene convertito in ammo/denaro.
- `dropped_weapon_ids_for_run` filtra globalmente gli ID gia apparsi; il pool
  catalogo esaurito produce ammo e viene azzerato a ogni `game_mode_started`.
- Le supply crate usano una `LootTable` e generano pickup standard tramite `DropSystem`.

## Contratto multiplayer locale

- Player 1 e sempre attivo e non puo lasciare la sessione dal prototipo.
- Gli slot 2-4 possono entrare/uscire durante la scena.
- Un joypad con `device = 0` controlla lo slot 1, `device = 1` controlla lo slot 2, e cosi via.
- Nel menu `Start` attiva lo slot del controller; durante una run la stessa
  azione apre il menu pausa prima del join.
- `Back/Select` disattiva lo slot se non e player 1.
- `F2`, `F3` e `F4` sono fallback debug per attivare/disattivare gli slot 2, 3 e 4 senza controller fisici.
- Ogni slot possiede anche l'azione `interact`: joypad `A`, con fallback tastiera `E` per player 1.
- Ogni slot possiede l'azione `super`: joypad `Y`, con fallback tastiera `Q` per player 1.
- Ogni slot possiede l'azione `dodge`: joypad `B`, con fallback tastiera `Shift`/`Ctrl` per player 1.
- La mappa esplorazione usa l'azione globale `world_map`: `M` e joypad `Back/Select/View`.
- `InputManager` garantisce che `ui_accept` includa joypad `A` con device globale, cosi ogni controller puo navigare e confermare il menu.
- `InputManager` espone la rimappatura joypad di movimento, mira, attacco base,
  attacco equipaggiato, reload, super, interact, dodge, pause e world map.
- `active_slots_changed` e il segnale autoritativo: i sistemi interessati devono ascoltare questo segnale invece di duplicare lo stato multiplayer.

## Contratti per modalita

Ogni modalita deriva da `BaseGameMode` e fornisce:

- `mode_id`;
- start/stop;
- condizione di vittoria/sconfitta;
- richiesta boss;
- collegamento a spawn nemici, drop e progressione.

Lo stato `menu` non e una modalita gameplay registrata. Entrare in `menu` arresta la modalita corrente; i player restano istanziati ma il loro input gameplay viene sospeso.

`Infinite Arena` e la modalita gameplay di default (`MODE_INFINITE_ARENA`):
riusa il runtime combat/survival condiviso, ma passa un context arena `1x1`
`500x500` con `arena_boundary_mode = "walled"` e disabilita `WorldRuntime`,
region seam, streaming multi-regione e mappa esplorazione. `Zombie Survival`
resta un mode id separato (`MODE_SURVIVAL`) e mantiene il contratto megamappa
multi-bioma.

## Contratto salvataggi

- Il file predefinito e `user://savegame.json`.
- Il formato v6 contiene progressione, ultima modalita, audio, impostazioni
  visuali, video, controlli joypad e stato mondo/esplorazione.
- Il default di `last_mode` per nuovi save e save non validi e
  `MODE_INFINITE_ARENA`; i save esistenti con `MODE_SURVIVAL` restano validi e
  continuano a puntare a `Zombie Survival`.
- I save v1-v3 restano caricabili; i campi assenti ricevono default validati.
- I save v4-v5 restano caricabili e ricevono uno stato mondo vuoto inizializzato dal seed della run successiva.
- `ProgressionManager` espone dati serializzabili e applica valori validati.
- XP, denaro e unlock attivano autosave; il cambio modalita aggiorna `last_mode`.
- Cambi audio e visuali attivano lo stesso autosave differito.
- Cambi della regione corrente o dello stato esplorazione possono attivare autosave quando l'auto-persistenza e abilitata.
- `PersistentWorldState` serializza seed, firma mondo, regione corrente, posizione party e snapshot esplorazione senza salvare il layout completo rigenerabile.
- File assente, root non valida o versione non supportata non modificano lo stato runtime.
- L'auto-persistenza e disabilitata nei test headless, ma save/load espliciti restano disponibili.

## Contratto megamappa persistente

- `WorldGenerationSeed` resta la sorgente deterministica; il layout fisico viene rigenerato dal seed, non salvato integralmente.
- Il contratto megamappa appartiene a `Zombie Survival`; `Infinite Arena` usa
  solo una cella `500x500` murata e non avvia runtime/esplorazione mondo.
- `BiomeMapGenerator` produce una griglia default `3x3` di territori `500x500`
  con grafo connesso: uno spanning tree garantisce raggiungibilita e edge extra
  aggiungono loop. La dimensione e il numero regioni restano override di debug
  tramite context.
- `ZombieModeController` non sovrascrive questi default nella survival
  standard. Il profilo compatto `1x1` esiste solo con context
  `single_biome_arena = true` e non prevale su `biome_map_width` /
  `biome_map_height` espliciti.
- Il context `arena_boundary_mode = "walled"` converte i lati senza vicino in
  `BLOCKED`, genera segmenti di muro perimetrali e disabilita i void/fall pocket
  interni del layout arena.
- Ogni `WorldRegionConnection` deve corrispondere a un passaggio fisico aperto su entrambi i lati confinanti.
- Due regioni adiacenti senza edge navigazionale hanno bordo bloccato; un lato senza regione vicina diventa fall boundary.
- `BiomeEnvironmentLayout` deve classificare tutto il `500x500` come walkable,
  obstacle, hazard, border, void o fall zone. Il layout non assume piu pavimento
  continuo: parte da void e scava floor, strade, passaggi e blocchi interni.
- `MapValidationSystem` rifiuta grafi non connessi, passaggi ostruiti, passaggi non fisici e classificazione incompleta.
- `WorldRuntime` mantiene `current_region_id` e marca visited/discovered senza possedere regole combat.
- `WorldRuntime.stop_run()` rilascia riferimenti a grafo e `BiomeManager`; i
  generatori di supporto procedurale senza lifecycle di scena sono `RefCounted`.
- `ExplorationMapPanel` mostra solo regioni note; unknown/fog non rivela la topologia completa.
- `SaveManager` sovrappone `PersistentWorldState` alla prossima generazione con lo stesso seed.
- Contratto megamappa scelto (Milestone 10.8): continuita fisica multi-regione
  gameplay. `WorldRegionStreamer` istanzia la regione corrente piu i vicini
  connessi entro `active_radius`, posizionandoli con offset
  `(world_origin_regione - world_origin_start) * logical_tile_scale`. Current e
  vicini hanno contenuto `FULL`; regioni oltre il raggio restano dati
  persistenti non istanziati.
- `ZombieModeController` invoca `WorldRegionStreamer.stream_world()` a ogni
  cambio regione e lo pulisce a `stop_run()`; l'integrazione e gated da
  `enable_multi_region_render`. `MultiRegionRenderer` resta fallback visuale
  lazy-only se lo streamer non e disponibile, quindi il bootstrap survival
  standard non crea piu neighbor ground placeholder.

## Contratto progressione e run

- `Field Kit` e l'unlock base: viene concesso al livello party 2 e resta persistente.
- All'ingresso in una modalita gameplay, `ProgressionManager` prepara tutti i player attivi.
- `GameModeManager.game_mode_started` viene emesso anche quando riparte la stessa modalita dopo un arresto.
- I player che entrano durante una run ricevono la stessa preparazione.
- `PlayerController.prepare_for_run()` calcola la vita dal valore base, quindi i bonus non si accumulano tra cambi modalita.
- Ogni nuova run ripristina la vita; `Field Kit` porta il massimo da 100 a 120 HP.

## Contratto audio

- `AudioManager` mantiene player separati per UI e gameplay.
- In headless i cue mantengono semantica e conteggio frame senza istanziare
  player audio temporanei.
- `ProjectileSystem.projectile_spawned` genera il feedback di sparo.
- Solo un impatto con danno applicato genera il feedback di colpo.
- `DropSystem.drop_collected` genera il feedback pickup in base al tipo raccolto.
- `WeaponSystem` genera feedback per low ammo e reload; l'uso della base non e
  piu un evento fallback perche possiede un input dedicato.
- I toni procedurali restano placeholder e non richiedono asset esterni.
- Spawn boss, telegraph e cambio fase usano cue distinti esposti da `gameplay_feedback_generated`.

## Contratto survival e wave

- `GameModeManager.register_mode()` avvia la modalita registrata se coincide con `default_mode`.
- La survival avviata dal menu riceve `context.character_ids_by_slot` dalla schermata `Character Select`; `context.character_id` resta fallback per debug, hotkey e test.
- In assenza di context, hotkey/debug e test mantengono il profilo sandbox generico precedente.
- Il profilo selezionato per lo slot viene applicato al player locale corrispondente; i player senza selezione dedicata usano il fallback `character_id`.
- I profili classe sono risorse `RpgCharacterData`; il registry mantiene solo path e funzioni di accesso.
- Il profilo survival modifica HP massimi, velocita, attacco, difesa, passive, super, adrenalina e progressione per-run del player.
- `SurvivalMode` avvia e arresta `WaveManager` e controlla la sconfitta del party.
- `SurvivalMode` avvia e arresta `ZombieModeController` prima del ciclo wave.
- `BiomeManager` e il punto unico per leggere il bioma corrente della survival.
- `BiomeManager.stop_run()` ripristina i layout base dei biomi e libera i dati
  world generati, evitando che celle, grafi e report restino vivi tra test.
- Ogni run survival genera o rigenera una megamappa persistente seed-based
  `3x3`; in assenza di seed manuale usa un seed default stabile, mentre un
  context `world_seed` permette riproduzione e debug.
- Il context `single_biome_arena = true` e riservato a quick test/debug e genera
  una sola cella `infected_plains` con bordi esterni fall-to-void, salvo
  dimensioni mappa esplicite nel context.
- La megamappa contiene territori `500x500`, seed locali, vicini, bordi, grafo connesso, passaggi fisici, fall boundary e layout ambientali validati prima di essere assegnati alle `BiomeDefinition`.
- Ogni nuova run survival riparte dalla `Pianura Infetta`.
- `WorldRuntime` marca la regione iniziale come visited, scopre i vicini collegati e conserva lo stato esplorazione.
- `BiomeTransitionSystem` collega territori confinanti tramite passaggi aperti; il party condivide una sola regione corrente.
- Quando il party attraversa un varco, `RegionSeamSystem` verifica posizione,
  regione target e connessione aperta usando coordinate globali; i lati senza
  edge non cambiano regione e restano muro, bordo o fall zone.
- Durante la survival standard non esistono nodi nel gruppo
  `biome_transition_gates`; i passaggi sono comunicati da tile, apertura fisica
  e continuita del terreno.
- Il cambio regione applica terreno, ostacoli, casse, hazard e passaggi della nuova regione senza riavviare `WaveManager`.
- `WaveDirector` legge il bioma corrente per risolvere roster, moltiplicatori, ritmo spawn e drop.
- Lo scaling contestuale considera wave, player vivi, tempo sopravvissuto e profondita del bioma.
- Ogni bioma legge `BiomeEnvironmentLayout` per terreno, ostacoli, casse e hazard senza placement hardcoded nei controller.
- Ogni `BiomeEnvironmentLayout` espone una classificazione completa del `500x500`
  usata da validazione, dodge/gap, spawn, streaming e debug.
- `BiomeEnvironmentLayout.get_floor_tag_at_cell()` espone anche il tag visuale
  dei floor rect scavati, cosi il resolver puo distinguere tall grass, path e
  altre superfici senza cambiare la classe terrain walkable.
- `TerrainGenerator` modifica palette e ground visuale; non possiede collisioni
  o regole combat.
- In modalita asset, `TerrainGenerator` registra il `BiomeTileLayer` della
  regione corrente creato da `WorldRegionStreamer`; nel fallback mono-regione
  puo ancora creare direttamente il ground primario e non istanzia i vecchi
  `BiomeTerrainPatch` ovali. Se `use_asset_tile_layer` viene disattivato o lo
  streaming non e disponibile, `BiomeRegionGround` e `BiomeTerrainPatch`
  restano fallback tecnici controllati, non visuali della survival standard.
- `IsometricTileResolver` risolve deterministicamente ogni cella logica
  `500x500` in `floor_base`, varianti floor, route tile asset-driven
  (`main_road`, road tematiche, curve/edge/intersezioni), passage tile
  (`road`, `bridge`, `snow_pass`, `broken_gate`, `burned_road`, entry/exit),
  `hazard_floor`, `border_floor`, `void_depth` o una transizione cliff
  neighbor-aware. Le transizioni distinguono bordi north/south/east/west,
  angoli interni/esterni e due raccordi diagonali. Le route generate
  preferiscono `road_cell_tags` diagonali; i
  rettangoli restano per aperture/passaggi e compatibilita. I connector di
  passaggio hanno priorita sulle road decorative sovrapposte.
- `IsometricTileCatalog` possiede solo ID statici, sezioni manifest e liste di
  route/tile richiesti. `IsometricTileResolver` mantiene alias pubblici per i
  consumer esistenti e resta l'unico responsabile della scelta per-cella.
- `IsometricTileResolverUtils` contiene helper statici condivisi dal resolver
  per hashing stabile, membership in rettangoli e verifica path asset; non
  decide tile, sezioni o ruoli.
- Per `infected_plains`, `IsometricTileResolver` usa il set forestale dedicato:
  `forest_grass`, `forest_tall_grass`, `forest_path`, `forest_road`,
  `forest_void`, `forest_cliff_edge`, `forest_mountain_wall` e le transizioni
  `grass_to_path`, `grass_to_road`, `grass_to_tall_grass`, `path_to_road`,
  `ground_to_void_cliff` e `ground_to_mountain_wall`. Queste scelte sono
  presentazionali e neighbor-aware: non cambiano pathfinding, collisioni,
  hazard o spawn.
- `BiomeTileLayer` cache-a tutti i 250.000 tile e li divide in chunk
  (`balanced` 20x20, `performance` 25x25, `quality` 16x16) senza creare nodi
  per-tile. Il layer pre-bake-a anche linee di dettaglio per grass, tall grass,
  path, road, transizioni e cliff; le celle pure `void_depth`/`forest_void`
  restano escluse dalla mesh e dal reticolo, lasciando un fondale uniforme con
  lo stesso colore condiviso dal `VoidBackdrop` fuori-mappa.
  `IsometricCliffMeshBuilder` costruisce
  per le sole celle `fall_zone` di confine la faccia verticale con gradiente,
  cresta chiara e fenditure; il gradiente della faccia termina direttamente nel
  colore del void senza shadow mesh o secondo contorno. Collisioni e regole di
  caduta restano in `BiomeFallZone`/`HazardSystem`.
- Gli ostacoli runtime sono `StaticBody2D` sul layer `1`, quindi player e zombie
  li trattano come impedimento fisico.
- Gli ostacoli appartengono anche ai gruppi `environment_obstacles` e `spawn_blockers`.
- `ObstacleSystem` usa `IsometricEnvironmentObjectFactory` per preferire
  `IsometricEnvironmentObject`: uno sprite asset-backed costruito dal
  `asset_path` `object_scenes`, ancorato al pavimento e ordinato con
  `sort_offset`. `BiomeObstacle` resta adapter/fallback quando il contratto
  dichiara esplicitamente un fallback procedurale.
- Il loader accetta SVG e texture raster importate. `forest_tree` e
  `large_rock` usano PNG trasparenti originali; la dimensione sorgente non
  cambia il gameplay perche il runtime scala sempre al target deterministico
  prodotto da footprint e `visual_height_tiles`.
- In streaming multi-regione, `ObstacleSystem` registra gli ostacoli creati da
  `WorldRegionStreamer`; le query `is_position_blocked` leggono tutti i nodi
  attivi nei gruppi `environment_obstacles`/`spawn_blockers`, inclusi i vicini.
- `IsometricSvgTextureLoader` evita che il runtime dipenda dall'import editor:
  rasterizza direttamente il contenuto SVG quando mantiene corner trasparenti,
  accetta la texture importata solo se non introduce un canvas opaco e, in
  fallback, delega la silhouette isometrica categoriale al builder dedicato.
- `IsometricSvgFallbackTextureBuilder` rasterizza i fallback per
  `object_scenes`, `void_tiles` e slot generici usando i metadata
  `data-section`/`data-id`; non legge manifest, non possiede path asset e non
  cambia collisioni o regole gameplay. Gli SVG ambiente interni restano
  trasparenti e hanno silhouette specifiche per case, recinti, muri, barili,
  relitti, tronchi, ponti e crate.
- `BiomeObstacle` legge `draw_mode` e `dedicated_draw` da
  `IsometricEnvironmentManifest`; se un ID ricade su `generic_barrier`, deve
  essere una scelta esplicita del manifest e non un fallback implicito.
- `BiomeObstaclePainter` disegna i fallback procedurali piu pesanti
  (perimeter wall e boundary tematiche) dietro il dispatch di `BiomeObstacle`;
  il nodo ostacolo resta proprietario di collision layer, shape, footprint,
  sort metadata e gruppi runtime.
- Il manifest v9 vieta fallback impliciti: ogni ID generato da ostacoli,
  terrain, passaggi, bordi o fall zone deve avere un contratto asset-driven con
  `asset_path`, `status`, `biome_ids`, `anchor`, footprint/collisione, sorgente,
  licenza, attribution e `fallback_path` quando l'asset e ancora assente.
- La fallback policy M10 distingue fallback tecnici necessari da status
  temporanei. Il percorso survival standard non puo usare path
  `placeholder`/`generic`, `generic_barrier` implicito, `BiomeRegionGround`,
  `BiomeTerrainPatch`, `MultiRegionRenderer`, `NeighborGround_*` o
  `BiomeTransitionGate`; `tests/milestone_10_asset_fallback_policy_smoke_test.gd`
  blocca queste regressioni insieme all'asset check.
- `BiomeObstacle` costruisce la collisione dal manifest: `collision_shape`
  (`rectangle`/`circle`/`open`) guida lo shape runtime e `contains_global_position`,
  `blocks_movement` e `blocks_projectiles` guidano i bit di `collision_layer`,
  `is_jumpable_gap_anchor` espone `is_jumpable_obstacle()`. La stessa footprint
  serve collisione fisica, spawn blocker e validazione casse.
- Il contratto v9 usa slot `4x4` celle: `footprint_slots` produce
  `footprint_tiles`, mentre `BiomeEnvironmentLayout.obstacle_rects` conserva le
  celle realmente occupate. `ObstacleLayoutGenerator` normalizza ogni oggetto
  non-border al footprint manifest prima delle query di spazio; posizione,
  collisione e base visiva derivano poi dallo stesso rettangolo.
- Gli ostacoli `forest_tree` e `large_rock` dichiarano entrambi slot `3x3`
  (`12x12` celle), collisione `rectangle` e blocchi movimento/proiettili. Il
  generatore starter garantisce un'istanza per ID su terreno walkable libero;
  le nove celle-slot sono quindi interamente non attraversabili, non solo il
  centro della sprite.
- `BiomeEnvironmentLayout.get_obstacle_record()` espone tipo, categoria,
  footprint, celle, asset/variante, altezza e blocchi. La validazione rifiuta
  mismatch o ostacoli solidi privi di asset; `ObstacleSystem` propaga il record
  ai nodi streamati e usa `F9` per il debug footprint runtime.
- `ObstacleSystem` espone `is_position_blocked` (tutti gli ostacoli, usato da
  spawn/crate/landing) e `is_position_blocked_by_non_jumpable` /
  `is_position_jumpable_obstacle`; il dodge usa la query non-jumpable per la
  traiettoria cosi futuri gap anchor saranno scavalcabili senza permettere il
  landing sopra un ostacolo.
- `ObstacleSystem.make_obstacle_key(biome_id, index, obstacle_id)` assegna a ogni
  `BiomeObstacle` una chiave stabile rigenerabile dal seed, pronta come chiave di
  persistenza per il ledger `destroyed_obstacles` (trigger gameplay in Milestone 8).
- `SupplyCrateVisual` usa lo stesso loader SVG-runtime sul contratto
  `object_scenes/supply_crate`; la collisione e l'apertura della crate restano
  nel nodo `SupplyCrate`.
- I lati con regione adiacente ma senza edge e i segmenti chiusi dei lati
  collegati usano border ID tematici per bioma; il lato senza regione resta
  fall zone e non ostacolo. Le pareti dei lati non-fall vengono accorciate di
  `FALL_THICKNESS` quando un'estremita tocca un lato fall; inoltre i
  `full_void` adiacenti al perimetro attraversano la fascia border e il loro
  intervallo viene escluso dai wall segment, evitando bordi sopra il vuoto.
- Ogni layout conserva un corridoio centrale libero per l'AI diretta esistente.
- `assets/environment/isometric/manifest.json` v9 contiene i draw mode oggetto
  legacy in `object_visuals`, i contratti asset per tile, terrain, edge, void,
  object scenes, passage tiles e asset set di bioma, inclusi i 14 tile cliff
  orientati, `void_depth`, tile forestali, road connector e entry/exit
  passaggio, `abandoned_car`, `dense_vegetation`, `forest_tree` e
  `large_rock`; i preset
  `performance`/`balanced`/`quality` restano disponibili per fallback ground e
  qualita del tile layer.
- `WorldRegionConnection` serializza apertura locale, connector locale,
  rettangoli world-space source/target e tile `entry_tile_id`/`exit_tile_id` per
  mantenere continuita visuale tra regioni adiacenti.
- I tag terrain generati da `ObstacleLayoutGenerator` e
  `BiomePassageGenerator` devono essere presenti nel manifest o avere fallback
  documentato; gli smoke falliscono se un nuovo tag strada/passaggio ricade su
  `dirt` generico.
- Cambiare draw mode oggetto/terrain o `sample_step` e un cambio
  presentazionale: non modifica classificazione, collisioni, pathfinding,
  hazard o regole di movimento.
- `ResourceCrateSystem` valida le posizioni contro `ObstacleSystem`, `HazardSystem` e la distanza minima tra casse.
- In streaming multi-regione, le crate layout create da `WorldRegionStreamer`
  portano `region_id` e `region_crate_key`; aprirle aggiorna il ledger del
  rispettivo territorio e il re-stream non le ripristina.
- Casse comuni, mediche, militari e tematiche usano loot table dedicate ma continuano a generare pickup tramite `DropSystem`.
- I loot tematici aggiungono `resource_tag` presentazionali senza creare un secondo inventario.
- `HazardSystem` delega tossico, fuoco, gelo, acqua e fango a `BiomeStatusRuntime`, tramite danno periodico o `environment_speed_multiplier`.
- `BiomeHazardCatalog` centralizza valori runtime e colori, evitando tuning nascosto nel controller.
- La fall zone conserva il contratto speciale: 20 HP, respawn sicuro e invulnerabilita dedicata.
- `HazardSystem.get_terrain_at_world_position()` converte la posizione reale
  dell'entita nella cella della regione e legge la classificazione completa;
  `is_void_at_world_position()` considera void sia `void` sia `fall_zone`.
- `HazardSystem` registra posizioni sicure solo su terreno non-void e avvia la
  caduta di player e zombie dalla cella sotto i piedi, non dall'attraversamento
  del bounding box di un border.
- `HazardSystem.is_position_hazardous()` resta la query aggregata per spawn e
  sicurezza; `is_position_fall_zone()` identifica il vuoto/caduta, mentre
  `is_position_environment_hazard()` identifica lava, gas, acqua profonda e
  altri hazard ambientali.
- Il dodge usa la query fall zone per attraversare piccoli gap e rifiuta gli
  hazard ambientali come ostacoli di traiettoria/landing.
- `EnemySystem` registra i profili tematici sullo stesso `basic_enemy.tscn`.
- `BasicEnemy` applica status al contatto, resistenza, emersione o hazard alla morte solo se definiti dal profilo.
- `BasicEnemy.death_reason` distingue `combat` da `void`: le morti void
  disabilitano XP, drop, risorse e hazard on-death, poi notificano normalmente
  `EnemySystem` solo al termine dell'animazione.
- Terreno, ostacoli e casse ambientali vengono rimossi da `ZombieModeController.stop_run()`.
- L'arresto di survival rimuove i nemici e il boss della wave prima di attivare un'altra modalita.
- `WaveManager` e autoritativo per indice ondata, stato, spawn pendenti e nemici della wave.
- Gli stati runtime sono `idle`, `intermission`, `spawning`, `combat` e `reward`.
- Gli zombie vengono creati esclusivamente tramite `EnemySystem.spawn_enemy()`.
- `WaveManager.get_enemy_id_for_spawn()` delega a `WaveDirector` quando presente, con fallback deterministico legacy.
- Le posizioni spawn reali vengono richieste a `ZombieSpawner`; lo spawner prova
  candidate camera-edge, poi fallback su regioni streamate valide e infine
  `spawn_points` solo come fallback/debug di arena validato. `spawn_points` non
  rappresenta il cambio bioma.
- Gli zombie gia vivi non vengono despawnati al cambio regione: mantengono
  target, health, status e loot, aggiornando solo metadata di regione mentre
  inseguono il player attraverso varchi aperti.
- `SurvivalArenaManager` applica `context.arena_id` senza duplicare `SurvivalMode`.
- Il profilo attivo configura spawn nemici, player, supply crate e boss.
- I gate non hanno collisioni; il loro impulso deriva da `WaveManager.enemy_spawned`.
- I barili sono `Area2D` sul layer damageable e non bloccano il movimento.
- Un barile letale emette prima il warning e applica danno solo alla scadenza.
- La wave 1 usa solo basic; dalla wave 2 ogni terzo slot e runner.
- Dalla wave 3, se sono presenti almeno cinque zombie regolari, l'ultimo slot e tank.
- Ogni ondata aumenta il conteggio base e passa moltiplicatori a `BasicEnemy`.
- Solo le morti dei nemici registrati nella wave contribuiscono al completamento.
- Le ricompense tra ondate aggiungono denaro party e munizioni/cura ai player attivi vivi.
- Le ricompense tra ondate aggiungono anche XP RPG uguale ai player vivi con profilo attivo.
- Le ricompense ammo alimentano solo lo slot equipaggiato; l'arma base non necessita drop.
- `SurvivalAmmoDirector` valuta ogni secondo i player vivi con speciale.
- Sotto la soglia configurata di 8 colpi totali puo generare una supply crate, con cooldown di 12 secondi.
- Ogni boss wave riceve una supply crate garantita prima dell'avvio o all'inizio della wave.
- Le crate attive non aperte vengono rimosse quando survival si arresta.
- Join e leave non modificano il conteggio nemici; i nuovi player partecipano alle ricompense successive.
- Ogni quinta ondata emette `boss_wave_requested` e `SurvivalMode` la inoltra a `BossSystem`.
- La boss wave usa due zombie di scorta e un boss registrato separatamente.
- `WaveManager` include il boss nel conteggio e aspetta il suo segnale `died`.
- Dopo una boss wave completata, `SurvivalMarketController` imposta il blocco
  generico `WaveManager.set_next_wave_blocked(true)`: il manager resta in
  `reward` e non avvia intermission, spawn o combat finche il mercato non lo
  rilascia.
- `SurvivalMarketController` possiede stato mercato, offerte e ready;
  `SurvivalMarketPurchaseService` valida/applica gli acquisti;
  `SurvivalMarketUI` possiede rendering e polling input per slot. Nessuno crea
  zombie o modifica l'indice wave.
- Il wallet mercato e il denaro party autoritativo di `ProgressionManager`;
  `try_spend_money()` scala il saldo una sola volta e notifica tutti i consumer.
- Le offerte arma sono ID unici estratti con peso rarita dal `WeaponCatalog`.
  L'acquisto chiama `WeaponSystem.add_weapon()` sul player che compra, quindi
  conserva tutte le altre `WeaponInstance` e il loro stato runtime.
- Cura e ammo validano prima l'effetto: HP pieni, ammo pieni, duplicati e fondi
  insufficienti non consumano denaro. Il refill puo agire sull'arma attiva o
  su tutte le istanze del player.
- Durante il mercato i player hanno combat input bloccato e invulnerabilita
  temporanea. La chiusura richiede ready da tutti i player vivi e ripristina la
  progressione dalla wave successiva.
- Se tutti i player attivi sono morti, `SurvivalMode` arresta la run.

## Contratto boss

- Le modalita richiedono boss tramite `GameModeManager.request_boss()`.
- `BossSystem` e l'unico proprietario dello spawn, risolve `boss_id` e impedisce boss attivi duplicati.
- `wave_warden` e compatibile con survival, dungeon e tower defense.
- `rift_architect` e compatibile con survival e dungeon; il dungeon lo richiede esplicitamente.
- Il boss riceve un dizionario di configurazione prima di entrare nell'albero.
- `BasicBoss` usa `HealthComponent` e appartiene al gruppo `damageable_targets`.
- Il targeting seleziona il player vivo piu vicino e supporta join/leave.
- I pattern usano `ProjectileSystem` con una scena proiettile ostile separata.
- Aimed e radial passano profili `WeaponVisualData` distinti allo stesso proiettile ostile.
- La fase 1 usa una raffica mirata da tre proiettili.
- Sotto il 50% di vita, la fase 2 alterna raffica radiale e mirata.
- Gli attacchi schedulati entrano prima in uno stato di telegraph.
- La raffica mirata mostra cono e corsie per 0,70 secondi e blocca la direzione annunciata.
- La raffica radiale mostra raggi e countdown per 0,90 secondi.
- Nessun proiettile viene creato durante il warning.
- `attack_telegraph_started` e `attack_telegraph_finished` espongono il timing ai sistemi di presentazione.
- `BossTelegraphVisual` puo essere sostituito senza cambiare pattern, danno o targeting.
- `WaveWardenVisual` puo essere sostituito senza cambiare health, collisioni o timing.
- Il danno letale genera un effetto `boss_death` senza ritardare il segnale `died`.
- La morte genera la `LootTable` boss, emette `died` e notifica `BossSystem`.
- `HUDManager` legge il boss attivo da `BossSystem` e mostra nome, fase e vita.
- Il contratto non dipende da survival: dungeon e tower defense possono riusare la stessa API.

## Contratto dungeon

- `DungeonGenerator.generate_layout(seed, room_count)` produce almeno quattro stanze con celle uniche.
- Lo stesso seed e conteggio producono lo stesso layout.
- Il prototipo genera un percorso sequenziale con start room, combat room, una loot room e boss room finale.
- `DungeonMode` istanzia una sola `DungeonRoom` attiva per volta e riposiziona il party al suo ingresso.
- Start e loot room hanno il portale aperto; combat e boss room lo bloccano fino al completamento.
- I nemici vengono creati solo tramite `EnemySystem` e tracciati localmente dalla modalita.
- La loot room usa una `LootTable` e `DropSystem`; i pickup non raccolti vengono rimossi al cambio stanza.
- Il boss finale viene richiesto tramite `GameModeManager` e `BossSystem`.
- La sostituzione di una stanza richiesta da un trigger fisico avviene in modo differito.
- Il menu principale seleziona dungeon; `F5` resta scorciatoia debug per dungeon,
  mentre `F1` avvia Infinite Arena e `F7` Zombie Survival.
- Diramazioni, shop, biomi e persistenza della run non fanno parte del prototipo minimo.

## Contratto tower defense

- `F6` seleziona `TowerDefenseMode`; il cambio modalita arresta e ripulisce survival o dungeon.
- La modalita istanzia una `TowerDefenseArena` e nasconde il playground prototipo.
- `TowerDefenseWaveController` e autoritativo per stato, indice wave, spawn e bersagli tracciati.
- `HUDManager` mostra il `StatusPanel` persistente solo durante Tower Defense:
  titolo modalita, core, crediti, wave, nemici e reward recente. Il pannello e
  ancorato al centro alto e non interseca le card player agli angoli.
- Il percorso e un `PackedVector2Array` convertito in coordinate globali dall'arena.
- `EnemySystem.register_enemy_scene()` associa l'ID `tower_defense_raider` alla scena dedicata.
- `TowerDefenseEnemy` segue i waypoint senza selezionare player; alla fine chiama `TowerDefenseManager.damage_base()`.
- Vita, morte, drop e collisione proiettile continuano a usare `HealthComponent`, `DropSystem` e `ProjectileSystem`.
- I crediti sono valuta di run separata dal denaro party e vengono azzerati all'avvio della modalita.
- `TowerBuildSlot` rileva player sovrapposti e richiede la costruzione con l'azione `interact`.
- `TowerDefenseManager` valida disponibilita e costo prima di creare la torre.
- `DefenseTower` considera solo nodi nel gruppo `tower_defense_targets`.
- `DefenseTower` calcola target e origine di fuoco; `DefenseTowerVisual` presenta orientamento, rinculo e flash.
- Il proiettile torre usa il profilo visuale `defense_tower` senza cambiare danno o collisioni.
- Le boss wave richiedono il `Wave Warden` tramite `GameModeManager` e `BossSystem`.
- `BasicBoss` mantiene il comportamento action normale, ma se riceve `path_points` usa il percorso e danneggia il core al termine.
- La distruzione del core porta la modalita in stato `defeated` e ripulisce la wave.
- Percorsi multipli, upgrade, vendita, riparazione e tipi torre aggiuntivi restano futuri.

Modalita previste:

- `survival`: ondate zombie, boss ogni N ondate.
- `dungeon`: stanze generate, boss finale per livello/area.
- `tower_defense`: path nemici, base da difendere, boss nelle ondate principali.

## Contratto packaging e QA

- `export_presets.cfg` definisce il preset `Windows Desktop` x86_64.
- `build/*` e `tests/*` sono esclusi dal pacchetto release.
- `Main` crea `BuildRuntimeSmoke` solo con l'argomento utente `--build-smoke`.
- Il runner verifica bootstrap menu, focus, D-pad, joypad `A`, audio UI, avvio survival, HUD e ritorno con `Esc`.
- Il QA visuale usa `tests/menu_visual_qa.gd` e salva catture temporanee in `build/qa/`.

## Estendibilita IA

Per mantenere il progetto gestibile:

- aggiungere sistemi piccoli con responsabilita chiara;
- documentare ogni nuovo contratto pubblico;
- lasciare esempi minimi giocabili;
- mantenere milestone e TODO aggiornati;
- preferire scene/test manuali ripetibili.

## Contratto iterazione status biome survival

`BiomeStatusRuntime` e il runtime unico dei malus ambientali e tematici: espone `apply_status(status_id, duration, intensity, source)`, `clear_status(status_id)`, `has_status(status_id)` e snapshot per HUD. `HazardSystem` lo possiede e resta la facciata usata da hazard, nemici, encounter e HUD; alla chiusura run resetta moltiplicatori movimento e status temporanei.

Il flusso nemici e `WaveDirector -> EnemySystem -> BasicEnemy`: il director risolve un ID pesato dal `BiomeDefinition`, `EnemySystem` inietta il `BiomeEnemyProfile`, `BasicEnemy` applica statistiche, visual profile e status on-hit/on-death. `ZombieVisual` riceve solo archetipo e tema, mantenendo silhouette procedurali distinte senza autorita gameplay.

`RandomEncounterSystem` e un sistema leggero seed-based per survival biome:
produce ambush, elite pack, cursed crate, hazard burst, survivor cache e i
mini-eventi `toxic_leak`, `fire_breakout`, `whiteout` e `marsh_emergence`,
annunciando l'evento via segnale e delegando spawn nemici/status/hazard/casse ai
sistemi esistenti. I telegraph temporizzati usano l'ID reale dell'evento,
`Timer` figli tracciati e cancellabili, cosi il cleanup della run non lascia
callback pendenti nello shutdown headless. Gli status da telegraph vengono
applicati solo ai player rimasti nell'area annunciata, mentre i mini-eventi
avanzati possono generare reward crate tematiche tramite `ResourceCrateSystem`.
