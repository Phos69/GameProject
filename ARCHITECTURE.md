# ARCHITECTURE

## Visione tecnica

Il progetto e un sandbox Godot 4.x 2D con resa top-down cardinale su griglia
ortogonale e volume prospettico controllato. La scena principale avvia un
playground minimo e registra i sistemi base. Le modalita future devono usare
sistemi comuni invece di duplicare gameplay. Il contratto di proiezione e
definito in `docs/top_down_cardinal_contract.md`.

## Flusso runtime attuale

1. `main.tscn` carica manager, world e `MainMenu`.
2. `GameModeManager` entra nello stato `menu` senza avviare gameplay.
3. `SaveManager` carica progressione party, unlock e ultima modalita da JSON.
4. `MainMenu` seleziona una modalita registrata; ogni modalita di gioco apre
   prima `Character Select` (titolo e pulsante di avvio adattati alla modalita
   tramite `pending_mode_id`), dove tastiera/mouse/pad 0 guidano il focus del
   Giocatore 1 e ogni pad aggiuntivo controlla lo slot corrispondente con
   cursore e conferma indipendenti. La schermata accetta `Start`/`pause` solo
   dagli slot attivi con selezione valida e passa `character_ids_by_slot` nel
   context, con `character_id` come fallback legacy.
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
19. `BiomeManager` genera una megamappa seed-based tramite `BiomeWorldGenerator`, con territori default `3x3` da `75x75` tile logici, grafo connesso, passaggi condivisi, fall boundary, layout validati e regione corrente.
20. `WorldRuntime` mantiene grafo, stato esplorazione, regione corrente e stato persistente sovrapposto al layout rigenerato dal seed.
21. `RegionSeamSystem` legge posizione world-space del party, grafo e
    `WorldRegionConnection` aperti per aggiornare la regione corrente senza
    portali, trigger visibili o teletrasporto.
22. `WorldRegionStreamer` mantiene incrementalmente la regione corrente e i
    vicini indicati da `WorldRuntime.active_regions` come contenuto gameplay
    `FULL`; `WorldChunkVisibilityController` rende solo i chunk attorno alla
    camera. Il passaggio di confine non pulisce ne ricostruisce il mondo.
23. `SurvivalArenaManager` configura playground, player, crate, gate e fallback spawn per lo spawner.
24. `HazardSystem` genera fall zone e hazard ambientali, aggiorna posizioni sicure, status e modificatori movimento.
25. `WaveManager` interroga `WaveDirector` per roster/scaling bioma e `ZombieSpawner` per spawn dai bordi camera, poi crea zombie tramite `EnemySystem`.
26. `SurvivalMode` usa `GameModeManager` e `BossSystem` per creare il boss della quinta ondata.
27. `WaveManager` conta minion e boss prima di assegnare la ricompensa.
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
41. `TopDownCameraController` segue il gruppo e applica shake solo tramite offset.
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
- `CharacterGameplayPreview`: preview procedurale top-down del personaggio selezionato, con silhouette, palette e arma derivate dal profilo.
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
- `ZombieVisual`: pittogrammi raster opzionali per basic, runner, tank,
  shooter ed elite; bob, facing e hit flash restano presentazionali, con
  profili procedurali come fallback senza autorita gameplay.
- `EnemyShotTelegraphVisual`: corsia e countdown ranged senza collisioni o danno.
- `BossSystem`: registro scene/compatibilita, spawn per ID, boss attivo e notifica sconfitta.
- `BasicBoss`: boss modulare con targeting, movimento, fasi e pattern proiettile.
- `RiftArchitect`: secondo boss con lane sweep, cross burst e visual dedicato.
- `ZombieBossBase`: estensione boss condivisa per melee ostile e proiettili
  zombie, senza duplicare health, fasi, drop o targeting.
- `ZombieBossVisual`: sprite raster opzionale per i cinque boss zombie con
  fallback procedurale profile-driven.
- `SurvivalMode`: ciclo survival, condizione di sconfitta e inoltro richieste boss.
- `ZombieModeController`: coordinatore interno del revamp survival per bioma, terrain, casse, ostacoli e hazard.
- `BiomeManager`: registro biomi, regione/bioma corrente, layout procedurale corrente e selezione iniziale della `Pianura Infetta`.
- `WorldGraph`: grafo seed-based dei territori, connesso tramite spanning tree ed edge extra, con API per raggiungibilita e connessioni fisiche.
- `WorldRegion`: dati stabili di un territorio `75x75` tile logici (`450x450` equivalenti legacy), inclusi biome ID, coordinate, origine mondo, vicini, connessioni e layout generato.
- `WorldRegionConnection`: edge navigazionale tra due regioni confinanti, con lato, direzione opposta, centro/larghezza del passaggio e coordinate globali.
- `WorldExplorationState`: stato unknown/discovered/visited/cleared per regione e marker della regione corrente.
- `PersistentWorldState`: payload serializzabile del mondo, seed, regione corrente, posizione party e stato esplorazione.
- `WorldRuntime`: runtime del grafo persistente; sincronizza `BiomeManager`, exploration state e save/load, con spazio per streaming regioni.
- `WorldRegionStreamer`: owner persistente del contenuto gameplay
  multi-regione. Espone `start_world`, `set_current_region`, `prepare_area`,
  `is_area_ready`, `get_loaded_visual_chunk_keys` e `get_streaming_stats`;
  applica solo il delta di regioni e registra/rimuove simmetricamente tile
  layer, ostacoli, hazard/fall zone e crate.
- `WorldChunkVisibilityController`: policy camera/chunk separata dal lifecycle
  gameplay. Mantiene visibile il rettangolo camera, prepara gli anelli +1/+2,
  trattiene il +3 con isteresi e ordina i commit per regione corrente,
  distanza e direzione di movimento. Un tile layer visibile ancora in build
  contribuisce a `visible_missing_chunks` e rende `is_area_ready()` falso,
  evitando readiness positive sopra un backdrop non ancora costruito.
- `BiomeTileChunkBaker` e `BiomeTileChunk`: commit main-thread dei dati visuali
  e nodo CanvasItem proprietario delle mesh, texture e linee di un chunk. Ogni
  chunk possiede un `TerrainSurfaceCanvas` che campiona il proprio sottorettangolo
  della maschera regionale, mantenendo separata la geometria di cliff, lip e
  ostacoli.
- `TerrainSurfaceClassifier`: converte il tile semantico risolto in una delle
  sole classi visuali `void`, `grass`, `path` o `asphalt`; non modifica
  collisioni, spawn, danno o pathfinding.
- `TerrainBoundaryMaskBuilder`: genera una maschera RGBA8 regionale a 8 pixel
  per tile. RGB seleziona rispettivamente grass, path e asphalt; RGB nullo
  rappresenta il void e alpha contiene il divisore di terra sui confini tra
  superfici diverse. I segmenti cardinali sono indicizzati per cella e alpha
  deriva dalla distanza euclidea al segmento piu vicino: estremita, svolte e
  incroci producono capsule e raccordi rotondi invece di quadrati sovrapposti.
- `TerrainSurfaceCanvas` e `terrain_surface_blend.gdshader`: stendono texture
  full-bleed in coordinate world-space, compongono sopra il divisore
  `terrain_divider_dirt` e usano un colore uniforme quando RGB e nullo. Lo
  streamer passa l'offset della regione alla fase UV, quindi texture uguali
  restano continue anche sui seam tra regioni.
- `GeneratedBiomeTextureTools`: normalizzazione condivisa dei PNG generati usati
  in repeat runtime; applica crop dei bordi chiari, fix dei pixel alpha e la
  stessa policy a ground, cliff/void e raised cliff perimetrali. Per
  `toxic_wastes` compone inoltre un atlas specchiato 2x2 a densita nativa,
  mentre `frozen_outskirts` e `drowned_marsh` compongono quilt `2x2` non
  specchiate da offset dello stesso raster base. `burning_fields` armonizza i
  bordi opposti del raster originale. La normalizzazione non cambia
  classificazione, collisioni o pathfinding.
- `WorldGenerationSeed`: seed globale di run e derivazione deterministica degli stream RNG per mappa, terreno, ostacoli, bordi, loot e spawn.
- `BiomeWorldGenerator`: orchestratore della pipeline procedurale globale per mappa biomi, layout per cella e debug seed.
- `WorldDataCache`: cache LRU in memoria e su disco dei `world_data` generati.
  I dati contengono cicli `RefCounted` tra celle, passaggi e layout; chi consuma
  uno snapshot direttamente fuori dal lifecycle di `BiomeManager` deve chiamare
  `WorldDataCache.release_world_data()` quando ha finito, mentre cache e
  generatore lo fanno automaticamente su clear/evizione/teardown. La chiave
  include `GENERATOR_REVISION = 4`; gli snapshot mondo usano il formato v6 e
  vengono accettati solo se la firma canonica profonda del layout rigenerato
  coincide con quella persistita.
- `WorldGridConfig`: centralizza la scala cartesiana e le conversioni legacy. Un tile logico vale `6x6` celle legacy, usa scala world `48.0` e mantiene gli asset alla loro scala legacy `8.0`.
- `BiomeMapGenerator`: costruisce la griglia di `BiomeCell` `75x75` con default `3x3`, assegna tipi bioma, coordinate globali, vicini, seed locali e grafo connesso con loop.
- `BorderGenerator`: calcola lati connessi e lati esterni di caduta per ogni cella bioma.
- `BiomePassageGenerator`: crea passaggi condivisi e allineati tra celle
  confinanti, con larghezza fisica standard di 7 tile logici, rettangoli
  local/global e tile entry/exit derivati dal `passage_type`.
- `BiomeTerrainGenerator`: genera il layout interno del bioma attivo e collega
  ostacoli, casse, hazard, summary deterministico e report di validazione.
- `EnvironmentAssetManifest`: legge `assets/environment/top_down/manifest.json`
  come inventario di ostacoli, draw mode oggetto, border tematici, fall zone
  procedurali, tag terrain generati e contratto asset v15 (`tile_sets`,
  `tile_variants`, `terrain_tiles`, `edge_tiles`, `void_tiles`, `object_scenes`,
  `passage_tiles`, `biome_asset_sets`, `fallback_policy`). Il loader normalizza
  path, varianti contestuali, status, footprint, anchor, collision shape, size
  e offset anche per variante, blocchi e attribution senza rendere obbligatori
  asset esterni. La validazione dei path riusa
  `BiomeTileResolverUtils.asset_path_exists`, unica query condivisa tra
  manifest e resolver.
- `ObstacleLayoutGenerator`: orchestra la pipeline terrain-parcels per i cinque
  biomi: passaggi e route hub-and-spokes da 7 tile, partizionamento con sentieri
  interni da 4, contenuti dei lotti, bordi, hazard e casse. Scatter globale,
  lottery void, vecchie macchie forestali e gruppi di mesa restano fuori dal
  percorso attivo.
- `TerrainRoutePass`: registra i passaggi ufficiali, costruisce hub e spokes da
  7 tile e sceglie uno spawn sicuro prima di qualunque lotto o contenuto.
- `TerrainParcelPartitionPass`: campiona 7-10 lotti, accetta solo tagli con area
  minima 180 e span minimo 8, usa fallback deterministico e assegna una town
  route-adjacent e una mesa; il resto segue pesi clearing/forest/fall-zone.
- `TerrainParcelContentPass`: costruisce montagna unica, foreste con corridoi,
  radure e filari, fall zone con rim e town tematizzate con vialetti verificati.
- `StaticHazardPlacementPass`: piazza gli hazard tematici esclusivamente nei
  lotti `clearing`, con clearance e fallback esaustivo per footprint.
- `FallBoundaryGenerator`: trasforma i lati senza vicino in `fall_zone` data-driven con il contratto di danno ambientale esistente.
- `MapValidationSystem`: valida con flood-fill spawn, corridoi, passaggi, casse
  raggiungibili, grafo connesso, passaggi non ostruiti, void non attraversabile
  e classificazione completa del `75x75`; rifiuta inoltre ostacoli fuori regione
  o sovrapposti alle fall zone. `deep_water` blocca pathfinding salvo celle
  bridge; i crossing d'acqua richiedono bridge solo nei layout che dichiarano
  un fiume nello `generation_summary`.
- `BiomeMapDebugOverlay`: espone seed corrente, riepilogo celle/passaggi,
  metriche di generazione (strade, sentieri, case, vegetazione densa, bridge,
  fiumi, acqua, auto, fence, mesa, prop e hazard statici), classi terrain
  aggregate, il report di
  connettivita del grafo (`WorldGraph.get_connectivity_report()`), regione
  corrente e active regions caricate, con toggle `F8`, e richieste di
  rigenerazione per debug.
- `BiomeDefinition`: risorsa dati con terreno, ostacoli, casse, zombie ammessi,
  pesi, palette e moltiplicatori; riferisce un `BiomeGenerationProfile`
  tipizzato per il tuning del contenuto interno.
- `BiomeGenerationProfile`: `Resource` per quantita/pesi dei lotti, probabilita
  filari, corridoi foresta, pool town e ID/dimensioni degli hazard statici. Il manifest resta
  l'autorita separata su asset, footprint, anchor e collisione.
- `RegionSeamSystem`: tracker world-space della regione survival corrente.
  Converte la posizione del party in tile globali, verifica che il bordo
  attraversato appartenga a un `WorldRegionConnection` aperto e aggiorna
  `BiomeManager`/`WorldRuntime` senza creare `Area2D` o marker di transizione.
- `BiomeTransitionSystem`: API imperativa di debug/test per forzare
  `transition_to()` (cambio bioma/regione) da smoke e tool. Il runtime survival
  standard non la usa per navigare: il cambio regione e rilevato da
  `RegionSeamSystem`. I portali Area2D `BiomeTransitionGate` sono stati rimossi e
  questo nodo non istanzia piu alcun gate.
- `BiomeEnvironmentLayout`: placement deterministico di floor scavati,
  `road_cell_tags`, rettangoli di apertura, `mesa_rects` con profilo visuale,
  `mass_rects`, prop casuali con ID, bridge, water/deep-water rects, ostacoli
  fisici, casse e hazard per un bioma; `parcel_types/bounds/areas` e la mappa
  cella->lotto descrivono i lotti indipendenti dallo streaming. La firma
  canonica e `layout-v4`; `rock_rects` resta
  solo mirror legacy delle mesa della Pianura Infetta.
- `WaveDirector`: composizione wave e scaling basati sul bioma corrente.
- `ZombieSpawner`: spawn dai bordi della camera con distanza minima dai player,
  validazione walkable/hazard/ostacoli/blocker e fallback arena solo se valido.
  Riceve obstacle, hazard, biome manager, seam system e world streamer da
  `ZombieModeController`, evitando lookup globali ripetuti nel path spawn.
  Espone motivo di scarto e report tentativi per test/debug; nella megamappa
  valida le posizioni contro regioni streamate world-space invece del solo
  layout locale corrente.
- `TerrainGenerator`: applica la palette del bioma, costruisce il piano visuale
  `75x75` come `BiomeTileLayer` asset-driven e legge gli stili terrain dal
  manifest. Nel percorso streaming registra il tile layer creato da
  `WorldRegionStreamer`; nel percorso mono-regione (es. Infinite Arena) crea
  direttamente il proprio `BiomeTileLayer`. I vecchi `BiomeRegionGround` e
  `BiomeTerrainPatch` procedurali sono stati rimossi.
- `ObstacleSystem`: genera e registra ostacoli fisici usati anche come spawn
  blocker; nel percorso asset-driven delega a `EnvironmentObjectFactory`.
- `EnvironmentObjectFactory`: legge il contratto `object_scenes` dal manifest,
  risolve l'eventuale `variant_asset_paths` con il bioma attivo e istanzia
  `EnvironmentObject` quando esiste un asset, lasciando `BiomeObstacle` come
  fallback tecnico esplicito.
- `EnvironmentObject`: scena base `StaticBody2D` per oggetti
  slot-based con `Sprite2D`, collider debug opzionale,
  collisione/layer/sort dal manifest e hook futuri per overlay danneggiato.
  Gli asset non aggiungono ombre, aloni o cerchi runtime sul floor; il floor
  resta responsabilita del tile layer.
  La Pianura Infetta usa raster originali trasparenti per i propri prop; il
  tronco condiviso seleziona il PNG tramite variante `infected_plains`, mentre
  gli altri biomi continuano a usare gli SVG dedicati in
  `objects/generated_props/` fino al loro pass. Il footprint di placement non
  cambia; la collisione puo usare `collision_size_ratio` per ID o
  `variant_collision_size_ratios` per una variante contestuale. `visual_scale`
  applica un fattore uniforme per singolo ID, mentre `variant_visual_scales`
  limita la correzione a una variante contestuale senza deformare X/Y. Le precedenti
  risorse `AtlasTexture` dei prop non fanno piu parte
  del runtime. `reed_wall` usa il raster SVG nativo stretto e
  verticale `56x136`, evitando che il loader canonico `160x120` lo riduca
  dentro la canvas; `dead_tree` conserva analogamente la canvas nativa verticale.
  La scelta resta presentazionale e non altera il footprint di placement.
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
- `SupplyCrate`: contenitore fisico configurato da `LootTable` per ammo e cura;
  usa un collider rettangolare `84x68` coerente con il visual raddoppiato.
- `ProgressionManager`: XP, livello, denaro, unlock party e bonus di inizio run.
- `SettingsPanel`: pannello UI condiviso con tab Audio, Video e Controls;
  usa `MenuNavigationController` per focus circolare, Back e tab LB/RB. Le tab
  lunghe scorrono internamente e lasciano Back fuori dallo scroll, cosi il
  pannello resta dentro la safe area a `1280x720`, `1024x768` e `960x540`.
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
- `PlayerVisual`: presentazione data-driven del player. Carica il pittogramma
  raster indicato da `RpgCharacterData.gameplay_sprite_path` come fallback. I
  sette profili configurano `directional_roll_atlas_path` con contratto `4x4`:
  righe Sud/Est/Nord/Ovest, colonne idle/anticipazione/tuck/recovery. Facing e
  roll selezionano regioni senza specchiare il fronte; durante la capriola il
  layer arma viene nascosto, poi `WeaponVisualRenderer` torna a disegnare
  l'equipaggiamento reale. Bob, hit flash e stati downed/dead restano runtime;
  se gli asset mancano usa la silhouette procedurale e non possiede il mini
  HUD.
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
  sia dal main menu sia dal pause menu; i controlli lunghi devono restare
  navigabili via focus anche quando la tab e scrollata.

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
- `ProjectileSystem` riceve i dati dello sparo e configura il proiettile prima
  di aggiungerlo alla scena. Se `current_scene` non e disponibile, per esempio
  in fixture sintetiche, usa il proprio parent locale prima del root del tree.
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
- `CombatRewardUtils.grant_kill_experience()` consuma tale sorgente e applica
  XP RPG e conferma kill con lo stesso contratto per `BasicEnemy` e
  `BasicBoss`; i due attori restano responsabili del proprio lifecycle di
  morte, loot ed effetti.
- Collision layer `1`: player e corpi generici; gli ostacoli ambientali che
  bloccano il movimento restano su questo layer per fermare player e zombie.
- Il player usa un collider a terra rettangolare `28x16`, centrato a `(0, 18)`
  come la sua ombra. Il contatto nord/sud dell'ombra coincide cosi con il
  limite fisico dei blocker cardinali senza alterarne il footprint.
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
- `ZombieVisual.archetype_id` cambia silhouette/fallback e scala del
  pittogramma senza cambiare collisioni o statistiche; `sprite_path` e
  `BiomeEnemyProfile.visual_sprite_path` sono riferimenti opzionali in-repo.
- `BiomeDefinition.elite_zombie_ids`, `elite_start_wave` ed
  `elite_spawn_chance` separano il gate elite dal roster pesato regolare. La
  selezione e deterministica per wave/spawn e non crea nuove scene o AI.
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

`BaseGameMode` possiede il sistema personaggi RPG condiviso da tutte le
modalita: legge `context.character_id` e `context.character_ids_by_slot`
all'avvio (`start_mode`), applica il profilo scelto ai player presenti e a
quelli che entrano dopo (segnale `player_spawned` del `PlayerManager`); senza
roster nel context riporta i player al profilo generico (`clear_rpg_character`).
Cosi Infinite Arena, Dungeon e Tower Defense applicano stat, passiva e super del
personaggio esattamente come Zombie Survival. Nel menu ogni modalita di gioco
passa dalla schermata `Character Select` prima di partire.

Lo stato `menu` non e una modalita gameplay registrata. Entrare in `menu` arresta la modalita corrente; i player restano istanziati ma il loro input gameplay viene sospeso.

`Infinite Arena` e la modalita gameplay di default (`MODE_INFINITE_ARENA`):
riusa il runtime combat/survival condiviso, ma passa un context arena `1x1`
`75x75` con `arena_boundary_mode = "walled"` e disabilita `WorldRuntime`,
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
- `WorldSnapshotCodec` formato v7 salva anche la firma `layout-v4`; snapshot di
  formato precedente o con layout alterato vengono rifiutati invece di
  contaminare cache e stato esplorazione. La terrain revision 5 conserva seed,
  progressione ed esplorazione dei save precedenti, azzera i ledger dipendenti
  dal layout e ricolloca il party sulla route sicura della regione corrente.
- File assente, root non valida o versione non supportata non modificano lo stato runtime.
- L'auto-persistenza e disabilitata nei test headless, ma save/load espliciti restano disponibili.

## Contratto megamappa persistente

- `WorldGenerationSeed` resta la sorgente deterministica; il layout fisico viene rigenerato dal seed, non salvato integralmente.
- Il contratto megamappa appartiene a `Zombie Survival`; `Infinite Arena` usa
  solo una cella `75x75` murata e non avvia runtime/esplorazione mondo.
- `BiomeMapGenerator` produce una griglia default `3x3` di territori `75x75`
  con grafo connesso: uno spanning tree garantisce raggiungibilita e edge extra
  aggiungono loop. La dimensione e il numero regioni restano override di debug
  tramite context.
- `ZombieModeController` non sovrascrive questi default nella survival
  standard. Il profilo compatto `1x1` esiste solo con context
  `single_biome_arena = true` e non prevale su `biome_map_width` /
  `biome_map_height` espliciti.
- Il context `arena_boundary_mode = "walled"` converte i lati senza vicino in
  `BLOCKED` e genera un anello continuo di segmenti perimetrali: governa solo il
  perimetro (muri al posto del precipizio), non il terreno interno. I void/chasm
  interni del layout sono ora una feature condivisa con `Zombie Survival` e
  restano attivi nell'arena; si disabilitano solo col flag context esplicito
  `disable_internal_void`. Il layout assegna
  `perimeter_visual_style = raised_cliff` e altezza due tile logiche: le strade
  decorative possono terminare sotto il bordo ma non lo aprono; solo un lato
  `CONNECTED` puo convertire la propria route in un varco. Nord/sud
  possiedono gli angoli e i lati verticali terminano al loro bordo interno.
  `Zombie Survival` mantiene invece `procedural_wall` e i varchi fisici reali.
- Ogni `WorldRegionConnection` deve corrispondere a un passaggio fisico aperto su entrambi i lati confinanti.
- Due regioni adiacenti senza edge navigazionale hanno bordo bloccato; un lato senza regione vicina diventa fall boundary.
- `BiomeEnvironmentLayout` deve classificare tutto il `75x75` come walkable,
  obstacle, hazard, border, void o fall zone. Il layout non assume piu pavimento
  continuo: parte da void e scava floor, strade, passaggi e blocchi interni.
- Ogni layout runtime contiene almeno un chasm interno con cliff verso il void,
  salvo l'opt-out esplicito `disable_internal_void`, mesa tematizzate e un pool
  pesato di prop. I quattro biomi avanzati aggiungono due hazard statici; la
  Pianura Infetta conserva solo fall zone/chasm come pericolo ambientale
  statico. Lo stesso contratto interno vale per Survival e Infinite Arena.
- `MapValidationSystem` rifiuta grafi non connessi, passaggi ostruiti, passaggi non fisici e classificazione incompleta.
- `WorldRuntime` mantiene `current_region_id` e marca visited/discovered senza possedere regole combat.
- `WorldRuntime.stop_run()` rilascia riferimenti a grafo e `BiomeManager`; i
  generatori di supporto procedurale senza lifecycle di scena sono `RefCounted`.
- `ExplorationMapPanel` mostra solo regioni note; unknown/fog non rivela la topologia completa.
- `SaveManager` sovrappone `PersistentWorldState` alla prossima generazione con lo stesso seed.
- Contratto megamappa scelto (Milestone 10.8): continuita fisica multi-regione
  gameplay. `WorldRuntime.active_regions` e la fonte unica per corrente e
  vicini: questi territori arrivano a contenuto `FULL`, mentre le regioni
  esterne restano dati persistenti non istanziati. Regioni con player, nemici,
  boss o hazard runtime vengono trattenute finche possiedono tali entita.
- `ZombieModeController` invoca `WorldRegionStreamer.start_world()` una sola
  volta e poi `set_current_region()`; il cambio regione non usa `clear()`,
  loading screen, teleport o ricostruzione. Le nuove regioni vengono aggiunte
  una per volta, con un solo worker tile attivo, e diventano `FULL` soltanto a
  bake terminato; `ZombieSpawner` continua a leggere esclusivamente le regioni
  `FULL`. Lo streamer viene pulito solo a `stop_run()`.
- Il caricamento iniziale pre-riscalda le texture dei biomi presenti, costruisce
  corrente e vicini e prepara camera piu due anelli prima di dichiarare il
  mondo ready. Texture, `ArrayMesh`, nodi e scene tree sono creati sul main
  thread; il worker produce soltanto dati del tile bake.

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
- Ogni modalita avviata dal menu riceve `context.character_ids_by_slot` dalla
  schermata `Character Select`; `context.character_id` resta fallback per debug,
  hotkey e test. L'applicazione del roster e gestita da `BaseGameMode`, comune a
  tutte le modalita (vedi "Contratti per modalita").
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
- La megamappa contiene territori `75x75`, seed locali, vicini, bordi, grafo connesso, passaggi fisici, fall boundary e layout ambientali validati prima di essere assegnati alle `BiomeDefinition`.
- Ogni nuova run survival riparte dalla `Pianura Infetta`.
- `WorldRuntime` marca la regione iniziale come visited, scopre i vicini collegati e conserva lo stato esplorazione.
- I territori confinanti sono collegati da passaggi aperti; `RegionSeamSystem` aggiorna la regione corrente e il party condivide una sola regione alla volta.
- Quando il party attraversa un varco, `RegionSeamSystem` verifica posizione,
  regione target e connessione aperta usando coordinate globali; i lati senza
  edge non cambiano regione e restano muro, bordo o fall zone.
- Durante la survival standard non esistono nodi nel gruppo
  `biome_transition_gates`; i passaggi sono comunicati da tile, apertura fisica
  e continuita del terreno.
- Il cambio regione seleziona bioma e tile layer gia esistenti senza riavviare
  `WaveManager`; terreno, ostacoli, casse, hazard e passaggi della destinazione
  sono gia gameplay-ready.
- `WaveDirector` legge il bioma corrente per risolvere roster, moltiplicatori, ritmo spawn e drop.
- Lo scaling contestuale considera wave, player vivi, tempo sopravvissuto e profondita del bioma.
- Ogni bioma legge `BiomeEnvironmentLayout` per terreno, ostacoli, casse e hazard senza placement hardcoded nei controller.
- Ogni `BiomeEnvironmentLayout` espone una classificazione completa del `75x75`
  usata da validazione, dodge/gap, spawn, streaming e debug.
- Le conversioni `logical_to_world()`/`world_to_logical()` usano lo stesso
  centro griglia intero (`zone_size / 2`), cosi anche regioni dispari `75x75`
  rimappano i centri di fall strip e ostacoli alla cella logica originale.
- `BiomeEnvironmentLayout.get_floor_tag_at_cell()` espone anche il tag visuale
  dei floor rect scavati, cosi il resolver puo distinguere tall grass, path e
  altre superfici senza cambiare la classe terrain walkable.
- `TerrainGenerator` modifica palette e ground visuale; non possiede collisioni
  o regole combat.
- `TerrainGenerator` registra il `BiomeTileLayer` della regione corrente creato
  da `WorldRegionStreamer` nel percorso streaming; nel percorso mono-regione crea
  direttamente il proprio `BiomeTileLayer`. Il tile layer asset-driven e l'unico
  produttore di ground: i vecchi `BiomeRegionGround` e `BiomeTerrainPatch`
  procedurali sono stati rimossi.
- `BiomeTileResolver` risolve deterministicamente ogni cella logica
  `75x75` in `floor_base`, varianti floor, route tile asset-driven
  (`main_road`, road tematiche, curve/edge/intersezioni), passage tile
  (`road`, `bridge`, `snow_pass`, `broken_gate`, `burned_road`, entry/exit),
  `hazard_floor`, `border_floor`, `void_depth` o una transizione cliff
  neighbor-aware. Le transizioni distinguono bordi north/south/east/west,
  angoli interni/esterni e raccordi d'angolo cardinali. Le aperture di passaggio
  dichiarate nei rettangoli hanno priorita sulle road decorative sovrapposte,
  cosi entry, exit e connector restano coerenti con il `passage_type`; le altre
  route generate usano segmenti H/V e curve tra lati cardinali; i rettangoli
  dei passaggi restano la fonte geometrica delle aperture.
- Nei biomi con `generated_theme_id`, il resolver conserva tile ID, sezione e
  ruolo semantico, mentre `TerrainSurfaceClassifier` riduce la resa del terreno
  alle classi visuali comuni. `service_lane`, `ash_lane`, `packed_snow_path` e
  `wooden_walkway` diventano `path`; route principali e passage road-like
  (`bridge`, `snow_pass`, `broken_gate`, `burned_road` e relative entry/exit)
  diventano `asphalt`. Il catalogo espone al runtime solo i raster full-bleed
  `ground`, `path` e `road`; transition e detail restano disponibili per
  catalogazione e tooling, ma non partecipano alla composizione della maschera.
- `BiomeTileCatalog` possiede solo ID statici, sezioni manifest e liste di
  route/tile richiesti. `BiomeTileResolver` mantiene alias pubblici per i
  consumer esistenti e resta l'unico responsabile della scelta per-cella.
- `BiomeTileResolverUtils` contiene helper statici condivisi dal resolver
  per hashing stabile, membership in rettangoli e verifica path asset; non
  decide tile, sezioni o ruoli.
- Per `infected_plains`, `BiomeTileResolver` usa il set forestale dedicato:
  `forest_grass`, `forest_tall_grass`, `forest_path`, `forest_road`,
  `forest_road_border`, `forest_void`, `forest_cliff_edge`,
  `forest_mountain_wall` e le transizioni `grass_to_path`, `grass_to_road`,
  `grass_to_tall_grass`, `path_to_road`,
  `ground_to_void_cliff` e `ground_to_mountain_wall`. Queste scelte sono
  presentazionali e neighbor-aware: non cambiano pathfinding, collisioni,
  hazard o spawn.
- `BiomeTileLayer` cache-a tutti i 5.625 tile e delega ogni unita visuale a un
  nodo `BiomeTileChunk` (`balanced` 10x10, `performance` 13x13, `quality`
  8x8), senza creare nodi per-tile. Ogni primitiva ground appartiene a un
  solo chunk; cliff, rocce e overhang restano geometria globale del layer e
  leggono il layout completo, evitando duplicati ai bordi. Il layer distingue
  tile logici totali, tile gia risolti nella cache, tile visuali residenti e
  chunk visibili; un worker in corso non espone il conteggio parziale come
  copertura totale.
  Quando il renderer rettilineo dei cliff e attivo, i `void_transition` non
  emettono un ground per-cella aggiuntivo: facce e lip dedicati sono l'unica
  sorgente visibile del pit, evitando sovrapposizioni fuori dal rettangolo void.
  Le pareti laterali degli scavi interni sono strip rettilinee clipped tra
  faccia alta e bassa, cosi i corner restano chiusi dai face orizzontali senza
  wedge scuri sovrapposti.
  In Zombie Survival il rettangolo camera e visibile, +1 e caricato, +2 viene
  prefabbricato e i residenti entro +3 vengono conservati; oltre +3 il rilascio
  avviene dopo 2 secondi. Lo scheduler ammette al massimo due chunk e non avvia
  un secondo job dopo 2 ms; un singolo bake atomico puo superare tale budget ed
  e quindi esposto dalle metriche. Il controller legge e riprioritizza prima la
  camera, poi esegue il commit: visible, regione corrente e direzione di
  movimento precedono il prefetch rimasto in coda. La classificazione visuale
  dell'intera regione alimenta una sola maschera RGBA8; ogni chunk ne campiona
  il sottorettangolo pertinente nel proprio `TerrainSurfaceCanvas`, senza mesh
  separate per ciascun materiale. `get_streaming_stats()` espone
  `visible_missing_chunks` e tempi last/max/average dei commit. Infinite Arena
  riusa lo stesso tipo di chunk, ma prepara l'intera regione all'avvio senza
  `WorldRuntime`.
  Nel bioma forestale le texture runtime `forest_grass`, `forest_path` e
  `forest_road` sono superfici full-bleed associate ai canali R, G e B. I tile
  semantici `grass_to_path`, `grass_to_road`, `path_to_road` e i passage
  `road`/entry/exit mantengono ID e section per debug, ma non richiedono piu
  core, edge o corner raster: la maschera seleziona le superfici sui due lati e
  il canale alpha applica `terrain_divider_dirt` sul confine. Tall grass e altre
  letture visuali restano separate dal contratto delle superfici principali.
  Le celle pure `void_depth`/`forest_void` e le transizioni `void_*` hanno RGB
  nullo e mostrano il colore uniforme condiviso dal `VoidBackdrop` fuori-mappa.
  Le mesh di cliff e lip restano un pass separato sopra il canvas terreno e
  definiscono il limite calpestabile senza usare il divisore di terra come
  sostituto della parete di caduta.
  I biomi avanzati riusano lo stesso shader tramite `BiomeGeneratedArtCatalog`:
  `toxic_wastes -> urban_ruins`, `burning_fields -> volcanic`,
  `frozen_outskirts -> frozen_tundra` e `drowned_marsh -> swamp`. Ogni regione
  sceglie un raster full-bleed stabile per i ruoli `ground`, `path` e `road`;
  `ROAD_STYLE_SURFACE` rende il ruolo road direttamente come asphalt, mentre
  le vecchie texture di transition/border/detail restano catalogate ma non
  vengono caricate nel set runtime della superficie. Il divisore di terra e la
  semantica dei canali della maschera sono comuni a tutti i temi.
  `frozen_tundra` conserva per il ground la quilt runtime `2x2` a periodo
  world-space `1024`, mentre path e road restano a `512`; `swamp` usa lo stesso
  periodo `1024` per il ground e `512` per path/road. `volcanic` mantiene il
  ground pieno sulla base variation 02, le altre variation come detail e repeat
  world-space `512`. Il nuovo significato dei dati superficie invalida la
  `TileBakeCache` tramite la format version corrente.
  `desert` e il set sostitutivo `forest` sono validati dal catalogo ma non
  hanno un consumer runtime.
  Le `mesa_rects` vengono raggruppate per `mesa_profile_ids`: `forest`,
  `urban_ruins`, `volcanic`, `frozen_tundra` e `swamp`. Il top usa il ruolo
  `ground` del tema e le pareti il ruolo `cliff_face`; la Pianura conserva i
  raster forestali dedicati. Il tile layer risolve e valida gli stessi profili,
  ma il volume visibile viene emesso una volta per ciascun nodo `large_rock`
  Y-sorted, non come batch di terreno.
  `TopDownCliffMeshBuilder` mantiene le 14 geometrie neighbor-aware per il
  fallback non forestale. Nel forestale `FallZoneBoundaryRuns` calcola il
  contorno esposto dell'unione di tutti i `fall_zone_rects`: lati condivisi fra
  rettangoli adiacenti o sovrapposti non vengono consegnati ai builder e quindi
  non possono produrre seam dentro un unico void. Ogni estremo di run espone
  inoltre la topologia locale `convex`, `concave`, `straight` o `diagonal`,
  derivata dalle quattro celle attorno al vertice. Su tale contorno,
  `RectilinearCliffFaceMeshBuilder` sostituisce le facce per-cell con pannelli
  continui: la parete lontana (nord) usa una profondita visuale canonica di
  `1,75` tile, limitata solo dallo spazio void realmente disponibile, e non
  cresce con la lunghezza del chasm. La parete vicina (sud) scende dritta mentre
  le pareti laterali (est/ovest) sono sghembate verso l'interno del void
  (`LATERAL_VOID_SLOPE`) per rendere il burrone in finta prospettiva, come le
  precedenti facce EDGE E/W. Tutte campionano `cliff_face_texture` e la
  dissolvono verso il void. Nei fall perimetrali da una tile la faccia puo
  estendersi oltre la fall strip, ma il bordo alto resta ancorato al confine
  terreno/caduta. `TopDownCliffBorderMeshBuilder` costruisce il lip con
  bordi raster distinti: due orizzontali, due verticali e quattro join
  geometrici. Le run orizzontali possiedono il quadrante diagonale dei corner
  convessi, mentre i raccordi concavi accorciano la run verticale: nessun
  corner e solo un contatore privo di mesh. La profondita world-space del lip
  usa circa due quinti del rim disponibile nel tema forestale e adegua lo span
  UV alla profondita world-space. Nella Pianura Infetta le mesh orizzontale e verticale campionano con
  un'unica proiezione planare il top mesa `large_rock`
  (`rock_plateau_top_generated.png`); solo la parete nel void usa la texture
  cliff direzionale. Una `terrain_transition_mesh` separata ripete
  `terrain_divider_dirt` e deriva lo spessore dagli stessi parametri della
  maschera stradale: `0,32` tile sul lato terreno, con `0,12` tile di nucleo dirt
  e `0,20` di feather esterno. Un feather interno corto sopra il margine della
  flat rock ammorbidisce anche lo stacco lato pietra; i corner convessi usano
  ventagli a quarto di cerchio con core pieno e feather radiale. Nei vertici
  `diagonal` a checkerboard la flat rock resta rettilinea; solo le quattro fasce
  dirt terminano prima del punto condiviso e due piccoli settori anulari
  (`0,42` tile) le raccordano. Una patch centrale `terrain_void_color` mantiene
  visibile la continuita della fall zone invece di suggerire terra calpestabile.
  Quando tre quadranti sono void e ne resta uno solo walkable, anche il dirt
  segue l'ownership del lip: la run orizzontale termina al vertice esterno della
  rock, la run verticale termina alla stessa profondita e un unico ventaglio a
  quarto di cerchio le unisce nel quadrante terreno, senza diramazioni a T.
  I fall perimetrali emettono solo il
  lato rivolto al terreno in base a `hazard_sides`. Le celle walkable
  `ground_to_void_cliff` mantengono il prato fino alla cresta; le celle
  `void_*` di transizione restano invece fondale void, cosi le texture terrain
  non continuano sotto la faccia cliff. La geometria rocciosa del lip viene
  sovrapposta esclusivamente sul lato walkable del confine: il primo pixel
  interno alla fall zone appartiene alla parete o al fondale void, mai a una
  cresta che sembri calpestabile. Il bordo orizzontale possiede le giunzioni
  concave del lip e quello verticale termina alla sua profondita rocciosa; nei
  corner convessi i due bordi restano completi perche occupano quadranti
  walkable distinti. Le facce usano invece un contratto unico di proiezione del
  contorno: prima della
  triangolazione ogni vertice ortogonale combina la componente di drop della
  run orizzontale con quella della run verticale. I due quad incidenti usano lo
  stesso vertice profondo e condividono quindi l'intera diagonale di giunzione.
  Anche la proiezione UV e unica: ogni vertice usa direttamente le proprie
  coordinate planari world-space `x, y`, indipendentemente dall'orientazione
  della run. Le due facce campionano quindi gli stessi texel lungo tutto il seam,
  non solo nei suoi estremi; il gradiente verso il void resta nei vertex color.
  In questo modo l'illuminazione baked della texture non cambia bruscamente al
  raccordo.
  Lo stesso algoritmo copre corner convessi e concavi, sagome L/T/croce e
  orientamenti specchiati; non esistono primitive corner aggiuntive, rettangoli
  sovrapposti o triangoli usati come patch. Nei corner convessi la parete
  orizzontale possiede l'intera profondita: le facce verticali vengono clippate
  fra il bordo profondo nord e quello sud, invece di attraversare e coprire le
  facce orizzontali. Nei concavi i versi sono opposti e resta il seam condiviso.
  Il lip verticale viene inoltre composto come underlay prima delle facce,
  mentre solo il lip orizzontale resta sopra la parete.
  Entrambe le mesh edge escludono la porzione erba dei propri raster e
  campionano solo roccia sopra il ground walkable; il ground resta unico owner
  del prato e la faccia resta unico owner della proiezione dentro il void,
  evitando cap scuri, croci, quadrati e doppio campionamento. Le linee e le
  facce inclinate legacy non vengono sovrapposte nel forestale. Collisioni e
  regole di caduta restano esclusivamente in `BiomeFallZone`/`HazardSystem`.
  Per i temi generati i pool cliff associano `01/02` alle facce, `03/04` ai
  lip orizzontale/verticale, `05-08` agli outer corner, `09/10` agli inner
  corner specchiabili e `11` al cap. Le facce e i lip selezionati alimentano
  gli stessi builder rettilinei del bioma base; tutti gli undici asset del
  tema sono caricati e validati come pool tipizzato.
- Ogni `wall_segment_rects` Survival usa `raised_cliff` alto due tile logiche.
  `WorldRegionStreamer` passa il bioma locale fino a
  `PerimeterCliffVisualProfile`, così faccia e corona seguono il tema del lato
  che le possiede. I varchi e gli intervalli void non generano segmenti; body
  fisico e Y-sort restano responsabilità degli ostacoli esistenti.
- Gli ostacoli runtime sono `StaticBody2D` sul layer `1`, quindi player e zombie
  li trattano come impedimento fisico.
- Gli ostacoli appartengono anche ai gruppi `environment_obstacles` e `spawn_blockers`.
- `ObstacleSystem` usa `EnvironmentObjectFactory` per preferire
  `EnvironmentObject`: normalmente uno sprite asset-backed costruito
  dal contratto `object_scenes`, ancorato al pavimento senza ombra runtime e
  ordinato tramite un nodo sort anchor. Il render mode `y_sorted_mesa` rende
  corona e facce sul
  singolo nodo `large_rock` tramite `RectilinearRockAreaMeshBuilder`; il vecchio
  ID `tile_layer_rock_area` resta solo un alias di lettura. `BiomeObstacle` resta adapter/fallback
  quando il contratto dichiara esplicitamente un fallback procedurale.
- Il loader accetta SVG, texture raster importate e, come estensione generica,
  risorse `Texture2D` `.tres` quali `AtlasTexture`; nessun prop attivo usa
  attualmente quest'ultimo formato. `forest_tree` mantiene il
  PNG trasparente originale e applica solo flip/tinta deterministici per ridurre
  la ripetizione; `large_rock` non usa piu una silhouette fissa e rende
  sull'intero `mesa_rect` un plateau rialzato con corona e pareti dedicate. La
  sorgente visuale non cambia gameplay, collisione o classificazione.
- `RectilinearRockAreaMeshBuilder` costruisce una mesa solida con geometria
  condivisa: la corona e sollevata di `RAISE_HEIGHT_CELLS`, mentre tre pareti
  continue (fronte sud a tutta larghezza + due fianchi
  obliqui in `LATERAL_LEAN_RATIO`) salgono dal prato fino al bordo; la parete
  nord guarda lontano dalla camera e non viene emessa. Le pareti sono disegnate
  per prime e la corona le copre, mascherando i triangoli alti. Il top usa
  `rock_plateau_top_generated.png`, le pareti `rock_cliff_face_upward_generated.png`
  con shading per lato e gradiente verso la base; nessuna fissure/lip disegnata a
  mano, quindi la superficie resta priva di linee procedurali. Corona e facce
  vengono disegnate una sola volta dal nodo oggetto Y-sorted; il tile layer
  genera sotto il footprint di ogni mesa un contorno `terrain_divider_dirt` con
  lo stesso spessore nominale dei bordi stradali, ma non duplica il volume e non
  aggiunge un cap a `z_index` fisso. Anche qui i corner convessi sono archi a
  quarto di cerchio, condivisi con il profilo dirt delle fall zone.
- `EnvironmentObject.is_world_position_behind_cliff()` classifica una
  posizione come dietro quando ricade nella larghezza della roccia e ha Y
  minore della linea centrale; Y maggiore/uguale significa davanti. Posizioni
  fuori dalla larghezza non vengono occluse. Non si cambia globalmente lo
  `z_index`: il Y-sort confronta lo stesso cliff con ciascun player, quindi il
  co-op supporta contemporaneamente attori davanti e dietro.
- In streaming multi-regione, `ObstacleSystem` registra e rimuove
  simmetricamente gli ostacoli creati da `WorldRegionStreamer`; le query
  `is_position_blocked` leggono tutti i nodi attivi nei gruppi
  `environment_obstacles`/`spawn_blockers`, inclusi i vicini.
- `EnvironmentTextureLoader` evita che il runtime dipenda dall'import editor:
  rasterizza direttamente il contenuto SVG quando mantiene corner trasparenti,
  accetta la texture SVG importata solo se non introduce un canvas opaco,
  carica le altre `Texture2D` tramite `ResourceLoader` e, in fallback, delega la
  silhouette top-down categoriale al builder dedicato. Le texture raster
  ad alta risoluzione vengono scalate al target del manifest senza il clamp
  minimo pensato per gli SVG gia rasterizzati vicino alla dimensione finale.
- `TopDownFallbackTextureBuilder` rasterizza i fallback per
  `object_scenes`, `void_tiles` e slot generici usando i metadata
  `data-section`/`data-id`; non legge manifest, non possiede path asset e non
  cambia collisioni o regole gameplay. Gli SVG ambiente interni restano
  trasparenti e hanno silhouette specifiche per case, recinti, muri, barili,
  relitti, tronchi, ponti e crate.
- `BiomeObstacle` legge `draw_mode` e `dedicated_draw` da
  `EnvironmentAssetManifest`; se un ID ricade su `generic_barrier`, deve
  essere una scelta esplicita del manifest e non un fallback implicito.
- `BiomeObstaclePainter` disegna i fallback procedurali piu pesanti
  (perimeter wall e boundary tematiche) dietro il dispatch di `BiomeObstacle`.
  Per `raised_cliff` costruisce facce e corona texture-mapped per orientamento,
  con UV world-space continui tra segmenti, usando il face/crown delle aree
  rocciose; se uno dei raster manca torna al muro procedurale. Il nodo ostacolo
  resta proprietario di collision layer, shape, footprint, Y-sort, metadata e
  gruppi runtime: il cliff arena non usa `BiomeFallZone` e non applica caduta.
- Il manifest v15 vieta fallback impliciti e valida anche ogni path dichiarato
  in `variant_asset_paths`: ogni ID generato da ostacoli,
  terrain, passaggi, bordi o fall zone deve avere un contratto asset-driven con
  `asset_path`, `status`, `biome_ids`, `anchor`, footprint/collisione, sorgente,
  licenza, attribution e `fallback_path` quando l'asset e ancora assente.
- La fallback policy M10 distingue fallback tecnici necessari da status
  temporanei. Il percorso survival standard non puo usare path
  `placeholder`/`generic`, `generic_barrier` implicito o `NeighborGround_*`; i
  vecchi renderer/ground procedurali (`BiomeRegionGround`, `BiomeTerrainPatch`,
  `MultiRegionRenderer`) e i portali `BiomeTransitionGate` sono stati rimossi dal
  codice. `tests/suites/assets/asset_fallback_test.gd` blocca queste regressioni
  insieme ai contratti della suite asset.
- `BiomeObstacle` costruisce la collisione dal manifest: `collision_shape`
  (`rectangle`/`circle`/`open`) guida lo shape runtime e `contains_global_position`,
  `collision_size_ratio`/`collision_offset_ratio` e le rispettive varianti
  contestuali separano il collider dal footprint di placement,
  `blocks_movement` e `blocks_projectiles` guidano i bit di `collision_layer`,
  `is_jumpable_gap_anchor` espone `is_jumpable_obstacle()`. Le query spaziali
  indicizzano la vera shape e il suo offset; spawn e casse conservano la
  clearance definita dal blocker.
- Il contratto v14 conserva gli slot legacy convertiti in tile logici:
  `footprint_slots` resta l'inventario di design, `footprint_tiles` del manifest
  conserva la misura legacy e `BiomeEnvironmentLayout.obstacle_rects` conserva
  le celle logiche realmente occupate. `ObstacleLayoutGenerator` normalizza ogni
  oggetto non-border al footprint convertito prima delle query di spazio;
  posizione e spazio riservato derivano dallo stesso rettangolo. Ogni ostacolo
  registra rotazione zero; lo stesso lock vale per hazard e fall zone. Un valore
  legacy non zero viene conservato solo come metadata diagnostico e non raggiunge
  visual o collider. `MapValidationSystem` rifiuta record ambiente non cardinali.
- `forest_tree` dichiara slot `3x3` (`12x12` celle legacy, `2x2` tile logici).
  Le `large_rock` void-first rappresentano le mesa e sono quadrati scalabili da
  `3x3` a `5x5` tile logici: `mesa_rect`, size collisione e sorgente del visual
  coincidono; la
  corona sollevata si estende oltre il footprint solo come overhang
  presentazionale per l'occlusione.
  Le rocce bloccano movimento e proiettili sull'intero rettangolo. `forest_tree`
  mantiene il placement `96x96`, applica `visual_scale = 2.0` al raster e usa
  un cerchio di raggio `48 px` a offset `(0, 24)`: due istanze adiacenti del
  bordo strada si toccano senza lasciare un varco attraversabile. `dead_tree`
  usa raggio `12 px` allo stesso offset dentro `48x96`.
  Il sort anchor coincide col centro delle radici e nessuna base quadrata viene
  disegnata sotto gli asset.
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
- `SupplyCrateVisual` usa il contratto `object_scenes/supply_crate` e seleziona
  il raster `common` o `medical` tramite `variant_asset_paths`; il manifest
  applica `visual_scale = 2.30` per raddoppiare la cassa senza stretch e senza
  aggiungere ombra o cerchio/glow intorno alla cassa. Collisione e apertura
  restano nel nodo `SupplyCrate`.
- I lati con regione adiacente ma senza edge e i segmenti chiusi dei lati
  collegati usano border ID tematici per bioma; il lato senza regione resta
  fall zone e non ostacolo. Le pareti dei lati non-fall vengono accorciate di
  `FALL_THICKNESS` quando un'estremita tocca un lato fall; inoltre i
  `full_void` adiacenti al perimetro attraversano la fascia border e il loro
  intervallo viene escluso dai wall segment, evitando bordi sopra il vuoto.
- Ogni layout conserva un corridoio centrale libero per l'AI diretta esistente.
- `assets/environment/top_down/manifest.json` contiene i draw mode oggetto
  legacy in `object_visuals`, i contratti asset per tile, terrain, edge, void,
  object scenes, passage tiles e asset set di bioma, inclusi i 14 tile cliff
  orientati, i materiali PNG `cliff_face_texture`/`cliff_lip_texture`,
  `void_depth`, prop SVG/raster con varianti contestuali, tile forestali, road
  connector e entry/exit passaggio, `abandoned_car`, `dense_vegetation`,
  `forest_tree` e `large_rock`; i preset
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
  rispettivo territorio e il re-stream non le ripristina. La rimozione della
  regione deregistra la crate; i contenuti encounter/runtime restano invece
  sotto il lifecycle del sistema che li ha creati.
- Casse comuni, mediche, militari e tematiche usano loot table dedicate ma continuano a generare pickup tramite `DropSystem`.
- I loot tematici aggiungono `resource_tag` presentazionali senza creare un secondo inventario.
- `HazardSystem` delega tossico, fuoco, gelo, acqua e fango a `BiomeStatusRuntime`, tramite danno periodico o `environment_speed_multiplier`.
- `BiomeHazardCatalog` centralizza valori runtime e colori, evitando tuning nascosto nel controller.
- La fall zone conserva il contratto speciale: 20 HP, respawn sicuro e invulnerabilita dedicata.
- `HazardSystem.get_terrain_at_world_position()` converte la posizione reale
  dell'entita nella cella della regione e legge la classificazione completa;
  `is_void_at_world_position()` considera void sia `void` sia `fall_zone`.
- `HazardSystem` registra posizioni sicure solo su terreno non-void. Per il
  player usa il baricentro del `CollisionShape2D` a terra impiegato anche contro
  gli ostacoli, conservandone l'offset ai piedi; il solo contatto di un bordo
  della hitbox con il void non basta. Gli zombie conservano la query puntuale.
  Il semplice attraversamento del bounding box di un border non causa caduta.
- L'overlay ambiente `F9` propaga lo stesso stato da `ObstacleSystem` a
  `HazardSystem`: mostra in azzurro le hitbox degli ostacoli e in rosa i
  rettangoli fisici delle fall zone, comprese quelle aggiunte dallo streaming.
  L'anchor delle fall zone deriva dal centro geometrico di `hazard_rects`, non
  dal centro intero di una cella: una dimensione pari resta quindi allineata ai
  confini del void anche nelle regioni da 75 tile. La risoluzione avviene anche
  al consumo, cosi gli snapshot cache precedenti non conservano l'offset F9.
- `HazardSystem.is_position_hazardous()` resta la query aggregata per spawn e
  sicurezza; `is_position_fall_zone()` identifica il vuoto/caduta, mentre
  `is_position_environment_hazard()` identifica lava, gas, acqua profonda e
  altri hazard ambientali.
- Il dodge usa la query fall zone per attraversare piccoli gap e rifiuta gli
  hazard ambientali come ostacoli di traiettoria/landing. Un punto finale nel
  void resta valido per completare l'intera distanza del roll; subito dopo il
  `PlayerController` rivaluta la hitzone a terra e transiziona direttamente da
  `dodging` a `falling`.
- `EnemySystem` registra i profili tematici sullo stesso `basic_enemy.tscn`.
- `BasicEnemy` applica status al contatto, resistenza, emersione o hazard alla morte solo se definiti dal profilo.
- `BasicEnemy.death_reason` distingue `combat` da `void`: le morti void
  disabilitano XP, drop, risorse e hazard on-death, poi notificano normalmente
  `EnemySystem` solo al termine dell'animazione.
- Terreno, ostacoli e casse ambientali vengono rimossi da `ZombieModeController.stop_run()`.
- L'arresto di survival rimuove i nemici e il boss della wave prima di attivare un'altra modalita.
- `WaveManager` e autoritativo per indice ondata, stato, spawn pendenti e nemici della wave.
- Gli stati runtime sono `idle`, `intermission`, `spawning`, `combat` e `reward`.
- `WaveCycle.process_state()` contiene il solo dispatch per-frame condiviso
  degli stati `intermission`, `spawning` e `combat`; `WaveManager` e
  `TowerDefenseWaveController` mantengono callback, spawn, reward e stati
  terminali specifici.
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
- La boss wave mantiene il normale conteggio progressivo dei minion, inclusi
  modificatori di bioma e pressione, e registra il boss come un combattente extra.
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
- `grave_colossus`, `gore_charger`, `plague_spitter`, `bone_mortar` e
  `carrion_shepherd` sono compatibili solo con Infinite Arena e survival.
- Il boss riceve un dizionario di configurazione prima di entrare nell'albero.
- `BasicBoss` usa `HealthComponent` e appartiene al gruppo `damageable_targets`.
- Il targeting seleziona il player vivo piu vicino e supporta join/leave.
- I pattern ranged usano `ProjectileSystem` con una scena proiettile ostile
  separata e profili `WeaponVisualData` per identita, trail e hit feedback.
- `ZombieBossBase` crea attacchi `MeleeAttack` configurati per il gruppo
  `players` e il layer body; gli swing non possono colpire zombie o boss e
  vengono cancellati alla morte del proprietario.
- I cinque profili coprono chase/short-stop, orbita con carica bloccata,
  kite/strafe, anchor/reposition e movimento ibrido a bande di distanza.
- Gli attacchi schedulati entrano prima in uno stato di telegraph.
- Archi melee, aree, corsie di carica, coni e raggi radiali sono visuali
  innocui: hitbox e proiettili nascono solo alla fine del warning.
- `attack_telegraph_started` e `attack_telegraph_finished` espongono il timing ai sistemi di presentazione.
- `BossTelegraphVisual` puo essere sostituito senza cambiare pattern, danno o targeting.
- `WaveWardenVisual` puo essere sostituito senza cambiare health, collisioni o timing.
- `ZombieBossVisual` carica il PNG canonico se disponibile e conserva una
  silhouette procedurale distinta per ogni profilo quando l'asset manca.
- Ogni quinta wave survival seleziona deterministicamente la rotazione
  `wave_warden`, `grave_colossus`, `gore_charger`, `plague_spitter`,
  `bone_mortar`, `carrion_shepherd`; i boss zombie usano uno spawn camera-edge
  validato, mentre il Warden conserva il punto storico delle arene compatte.
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
- `TowerDefenseTargetUtils.reach_base()` disabilita movimento/collisioni,
  applica il danno al core ed emette `base_reached` sia per
  `TowerDefenseEnemy` sia per il `BasicBoss` configurato con un percorso.
- Vita, morte, drop e collisione proiettile continuano a usare `HealthComponent`, `DropSystem` e `ProjectileSystem`.
- I crediti sono valuta di run separata dal denaro party e vengono azzerati all'avvio della modalita.
- `TowerBuildSlot` rileva player sovrapposti e richiede la costruzione con l'azione `interact`.
- `TowerDefenseManager` valida disponibilita e costo prima di creare la torre.
- `DefenseTower` considera solo nodi nel gruppo `tower_defense_targets`.
- `DefenseTower` calcola target e origine di fuoco; `DefenseTowerVisual` presenta orientamento, rinculo e flash.
- Il proiettile torre usa il profilo visuale `defense_tower` senza cambiare danno o collisioni.
- Le boss wave richiedono il `Wave Warden` tramite `GameModeManager` e `BossSystem`.
- Le boss wave mantengono il normale conteggio progressivo dei raider e
  aggiungono il boss separatamente al totale dell'ondata.
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
- Il QA visuale usa 25 entry point `SceneTree` sotto `tests/visual_qa/`; i due
  helper WVIS top-level vengono caricati solo dall'orchestratore e non sono
  eseguiti direttamente.
- `tests/visual_qa/helpers/visual_qa_runtime.gd` rende valida una cattura
  gameplay solo dopo la rimozione del loading overlay, la presenza del marker
  specifico, il completamento del terreno, area prefetch pronta, code regioni/
  contenuti drenate e `WorldRegionStreamer.visible_missing_chunks == 0` stabile
  per tre frame; prima di restituire attende inoltre due
  `RenderingServer.frame_post_draw`.
- Il review biomi disabilita temporaneamente il polling di `RegionSeamSystem`
  durante i teleport QA, prepara i chunk per il rettangolo camera target,
  richiede almeno il 30% di copertura world non-nera e verifica entrambe le
  risoluzioni prima di salvare sotto `build/qa/`.
- Ogni entry point aggiornato libera scena, cache mondo, manifest e texture
  condivise prima di terminare, mantenendo i log privi di leak.

## Estendibilita IA

Per mantenere il progetto gestibile:

- aggiungere sistemi piccoli con responsabilita chiara;
- documentare ogni nuovo contratto pubblico;
- lasciare esempi minimi giocabili;
- mantenere milestone e TODO aggiornati;
- preferire scene/test manuali ripetibili.

### Server MCP locale di progetto

Il repository include un server MCP locale in `tools/mcp-server/`, separato dal
runtime Godot. Il server usa Node.js/TypeScript, `@modelcontextprotocol/sdk` e
transport `stdio`; serve Codex e altri agenti con contesto strutturato sulla
repo senza introdurre dipendenze nel gioco.

Contratto operativo:

- il server lavora solo dentro la root del progetto, rilevata risalendo fino al
  marker `project.godot` (indipendente da posizione del clone e profondità di
  build) oppure tramite `PROJECT_MCP_ROOT`;
- i tool sono read-only salvo `run_safe_check`, che esegue solo comandi
  allowlisted e non accetta shell arbitraria;
- `read_project_context` valida path relativi, assoluti in-root e `res://`,
  blocca traversal e non legge file sensibili; supporta finestre per riga e un
  budget aggregato di risposta;
- `search_project` limita dimensione file, numero risultati e ignora cache,
  build output, vendor pesanti e lockfile non richiesti;
- l'indice file read-only e condiviso in memoria con TTL breve e bypass
  esplicito `refresh`; `list_project_files` filtra l'area prima della
  paginazione e restituisce per default solo i path;
- `git_context` espone solo status/log/diff read-only via sottocomandi git
  allowlisted, senza shell arbitraria, con path validato e output troncato;
- `find_symbol` indicizza a runtime le dichiarazioni GDScript (`class_name`,
  `extends`, `func`, `signal`, `const`, `enum`, classi interne) per nome e
  tipo, senza mantenere una cache persistente su disco;
- `read_symbol_context` combina lookup dichiarazioni e finestre sorgente
  bounded; `changed_context` collega working tree, sistemi impattati, safe
  check e documenti da riesaminare secondo i contratti del repository;
- `repo_overview`, `game_system_summary`, `roadmap_context`,
  `asset_inventory` e `codex_task_brief` ricavano il contesto dai file reali
  della repo, non da supposizioni hardcoded;
- i prompt MCP in `tools/mcp-server/src/prompts.ts` sono template operativi per
  audit top-down cardinale, zombie mode, milestone roadmap, refactor gameplay e asset
  quality pass.
- le risposte espongono sia JSON testuale compatibile sia `structuredContent`;
  lo smoke `stdio` chiama tool reali, verifica traversal e avvia `mcp:build`.

La documentazione, gli script e l'esempio di configurazione Codex vivono in
`tools/mcp-server/README.md` e `tools/mcp-server/codex.config.example.toml`.

## Contratto iterazione status biome survival

`BiomeStatusRuntime` e il runtime unico dei malus ambientali e tematici: espone `apply_status(status_id, duration, intensity, source)`, `clear_status(status_id)`, `has_status(status_id)` e snapshot per HUD. `HazardSystem` lo possiede e resta la facciata usata da hazard, nemici, encounter e HUD; alla chiusura run resetta moltiplicatori movimento e status temporanei.

Il flusso nemici e `WaveDirector -> EnemySystem -> BasicEnemy`: il director
risolve prima l'eventuale gate elite e poi un ID pesato dal `BiomeDefinition`,
`EnemySystem` inietta il `BiomeEnemyProfile`, `BasicEnemy` applica statistiche,
visual profile e status on-hit/on-death. `ZombieVisual` riceve archetipo, tema e
sprite raster opzionale; il PNG non possiede autorita gameplay e il disegno
procedurale resta il fallback.

`RandomEncounterSystem` e un sistema leggero seed-based per survival biome:
produce ambush, elite pack, cursed crate, hazard burst, survivor cache e i
mini-eventi `toxic_leak`, `fire_breakout`, `whiteout` e `marsh_emergence`,
annunciando l'evento via segnale e delegando spawn nemici/status/hazard/casse ai
sistemi esistenti. I telegraph temporizzati usano l'ID reale dell'evento,
`Timer` figli tracciati e cancellabili, cosi il cleanup della run non lascia
callback pendenti nello shutdown headless. Gli status da telegraph vengono
applicati solo ai player rimasti nell'area annunciata, mentre i mini-eventi
avanzati possono generare reward crate tematiche tramite `ResourceCrateSystem`.
