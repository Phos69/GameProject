# ROADMAP

## Milestone 0 - Setup repository e documentazione

Stato: completata.

- Repository Git inizializzato.
- Progetto Godot 4.x creato.
- Struttura cartelle creata.
- Documentazione iniziale creata.
- Regole IA definite in `AGENTS.md`.

## Milestone 1 - Movimento, joypad e camera

Stato: completata come prototipo minimo.

- Scena principale pseudo-isometrica.
- Player controllabile.
- Movimento fluido.
- Input joypad player 1.
- Fallback tastiera.
- Camera che segue il gruppo player.
- Struttura predisposta per multiplayer locale.

## Milestone 2 - Multiplayer locale

Stato: completata come prototipo minimo.

- Assegnazione deterministica device/slot per 1-4 player locali.
- Spawn e despawn dinamico dei player locali.
- Camera di gruppo con zoom dinamico gia condivisa tra i player attivi.
- HUD con conteggio player e slot attivi.
- Join/leave locale: `Start`/`Back` su joypad e `F2`-`F4` come fallback debug per slot 2-4.

## Milestone 3 - Sparo, armi, danni e vita

Stato: completata come prototipo minimo.

- Proiettili visibili con collisione su bersagli damageable.
- Danno applicato tramite `HealthSystem` e `HealthComponent`.
- Statistiche arma configurabili tramite `WeaponData`.
- Pistola base con caricatore, riserva munizioni e ricarica.
- Stato vita e munizioni per-player nell'HUD.
- Bersagli statici per verifica combat nella scena principale.
- Smoke test headless con due player locali.

## Milestone 4 - Nemici base e drop

Stato: completata come prototipo minimo.

- Nemico melee con stati idle, chase, attack e dead.
- Targeting del player vivo piu vicino con retarget dinamico.
- Attacco integrato con `HealthSystem`.
- Spawn, registro e segnali morte tramite `EnemySystem`.
- Loot table tipizzate e configurabili.
- Pickup in scena per XP, denaro, armi, munizioni e vita.
- XP e denaro condivisi; ricompense combat applicate al raccoglitore.
- Seconda arma prototipo equipaggiabile tramite drop.
- Smoke test headless con join/leave di due player.

## Milestone 5 - Zombie survival

Stato: completata come prototipo minimo.

- `SurvivalMode` registrata e avviata tramite `GameModeManager`.
- `WaveManager` con stati intermission, spawning, combat e reward.
- Spawn progressivo e aumento del numero di zombie.
- Scaling per ondata di vita, velocita e danno.
- Ricompense party di denaro, munizioni e cura.
- HUD con ondata, countdown, nemici rimasti e ricompensa.
- Compatibilita join/leave durante la run.
- Sconfitta quando tutti i player attivi sono morti.
- Boss wave ogni cinque ondate con richiesta al `BossSystem`.
- Smoke test headless su tre ondate.

## Milestone 6 - Boss system

Stato: completata come prototipo minimo.

- `Wave Warden` con targeting multiplayer e movimento a distanza.
- Fase 1 con raffiche mirate.
- Fase 2 sotto il 50% con raffiche mirate e radiali alternate.
- Proiettili ostili integrati con `HealthSystem`.
- Barra vita boss con nome, fase e valori.
- `BossSystem` con boss attivo, spawn centralizzato e notifica sconfitta.
- Drop speciale garantito `Wave Cannon`.
- Quinta ondata survival con due scorte e boss reale.
- Wave completata solo alla morte di scorte e boss.
- Smoke test headless boss con due player.

## Milestone 7 - Dungeon procedurale

Stato: completata come prototipo minimo.

- Layout deterministico da seed con celle uniche.
- Link sequenziali attraversabili tra le stanze.
- Start room, combat room, loot room e boss room.
- Scena stanza modulare con pareti e portale bloccabile.
- Spawn nemici e scaling crescente nelle stanze combat.
- Loot room con ricompense fisiche.
- Boss finale richiesto tramite `BossSystem`.
- HUD con seed, indice stanza, stato uscita e nemici rimasti.
- Hotkey debug per passare tra survival e dungeon.
- Smoke test headless su una run completa.

## Milestone 8 - Tower defense

Stato: completata come prototipo minimo.

- Arena tower defense dedicata e avviabile con `F6`.
- Macchina a stati delle ondate separata in `TowerDefenseWaveController`.
- Percorso fisso a waypoint condiviso da nemici e boss.
- Core da difendere con vita e condizione di sconfitta.
- Crediti di run, tre slot costruzione e costo torre.
- Input costruzione `E`/joypad `A` per ogni player locale.
- Torre automatica con targeting, range e proiettili condivisi.
- Ondate con spawn progressivo, scaling e ricompense crediti.
- Boss ogni cinque ondate tramite `BossSystem`.
- HUD con core, crediti, ondata e nemici rimasti.
- Smoke test headless su percorso, costruzione, torre, boss e sconfitta.

## Milestone 9 - Polish, salvataggi e packaging

Stato: completata come prototipo minimo.

- Save/load JSON versionato completato per progressione party e ultima modalita.
- Autosave progressione e validazione dei dati completati.
- Menu principale e selezione modalita completati.
- Ritorno al menu con arresto della modalita attiva completato.
- Feedback audio UI procedurale completato come placeholder minimo.
- Preset export Windows completato.
- Pacchetto PCK generato e avviato headless con successo.
- Template Windows Godot `4.6.3` installati e verificati tramite checksum ufficiale.
- Build Windows release generata e avviata con successo.
- Smoke test interno della build completato con exit code `0`.
- QA visuale completato su menu, focus joypad, avvio survival e ritorno al menu.
- Controller XInput reale e driver audio WASAPI rilevati durante il QA.
- Corretto `ui_accept` per confermare il menu con joypad `A`.
- `tests/` e `build/` esclusi dal pacchetto release.
- Smoke test Milestone 9 completato.
- Save v2 con unlock persistenti e migrazione automatica dei save v1.
- Unlock `Field Kit` ottenuto al livello party 2 e applicato a ogni nuova run.
- Reset salute idempotente per player presenti e join durante una run.
- Feedback audio procedurale per sparo, impatto valido e pickup.
- Primo pass di bilanciamento: `Starter Pistol` a 6 colpi/s e `Prototype Blaster` a 4,5 colpi/s.
- Stato unlock mostrato nel menu principale.

## Milestone 10 - Visual Readability Foundation

Stato: completata come primo pass visuale modulare.

- Arena survival desaturata e pseudo-isometrica con dettagli post-apocalittici.
- Survivor leggibili per slot con animazioni procedurali di movimento e combat.
- Zombie riconoscibili con silhouette e feedback di stato.
- Pickup e supply crate grafici senza etichette testuali.
- HUD per-player con schede, barre vita, arma e munizioni.
- Effetti leggeri per sparo, hit, morte e raccolta.
- Bersagli debug nascosti dal gameplay normale.
- Smoke test visuale e QA a 1280x720.

## Milestone 11 - Boss Telegraph e Combat Danger Feedback

Stato: completata come primo pass modulare.

- Raffica mirata preceduta da cono, corsie e countdown world-space.
- Direzione mirata bloccata al momento del warning.
- Raffica radiale preceduta da raggi, area e countdown leggibili.
- Nessun proiettile generato durante la finestra di telegraph.
- HUD con messaggi distinti per aimed, radial e fase 2.
- Cue audio procedurali per spawn boss, warning e cambio fase.
- Impulso visuale world-space al passaggio in fase 2.
- Smoke test dedicato e QA visuale a 1280x720.

## Milestone 12 - Varianti Zombie Runner e Tank

Stato: completata come primo pass gameplay e visuale.

- Runner rapido, fragile e dalla silhouette sottile.
- Tank lento, resistente e dalla silhouette larga.
- AI melee condivisa tramite `BasicEnemy`.
- Scene, collisioni, health bar e loot configurati per archetipo.
- Composizione wave deterministica: runner dalla wave 2 e tank dalla wave 3.
- Conteggio, scaling, morte e drop continuano a usare i sistemi condivisi.
- Dungeon e tower defense non modificati.
- Smoke test dedicato e QA con quattro player a 1280x720.

## Milestone 13 - Identita Grafica di Armi e Torri

Stato: completata come primo pass visuale modulare.

- `WeaponVisualData` condiviso tra arma world-space, icona HUD e proiettile.
- `Starter Pistol` compatta con accento arancio.
- `Prototype Blaster` a doppia forcella con energia ciano.
- `Wave Cannon` pesante con nucleo e proiettile magenta.
- Forma, scala, glow e trail dei proiettili configurati per profilo.
- Torre con base esagonale, nucleo pulsante e doppia canna orientabile.
- Tracking, idle scan, rinculo e muzzle flash senza autorita gameplay nel visual.
- Smoke test dedicato e due QA visuali a 1280x720.

## Milestone 14 - Polish Finale e Presentabilita

Stato: completata come chiusura del visual gameplay pass.

- `WaveWardenVisual` segmentato con nucleo, piastre e direzione leggibile.
- Palette, spine e animazione dedicate alla fase 2.
- Feedback visuale di spawn, hit e carica pattern.
- Proiettili aimed e radial con profili, glow e trail distinti.
- Effetto morte boss con drop speciale leggibile.
- Pannello boss centrato e responsive.
- Annunci centrali per wave, reward, boss, overdrive e sconfitta.
- Precedenza degli annunci per evitare sovrascritture immediate.
- Smoke test dedicato e QA completa a quattro player a 1280x720.

## Milestone 15 - Zombie Ranged e Pressione a Distanza

Stato: completata come primo pass gameplay e visuale.

- Shooter alto e tossico, distinto dagli archetipi melee.
- Distanza preferita e ritirata quando il player si avvicina.
- Windup con direzione bloccata, corsia e countdown world-space.
- Nessun proiettile creato durante il warning.
- Proiettile ostile verde/ciano distinto dai pattern boss.
- Health, scaling, drop e registro condivisi con i sistemi esistenti.
- Composizione deterministica dalla wave 4.
- Smoke test dedicato e QA con quattro player.

## Milestone 16 - Downed e Revive Multiplayer

Stato: completata come primo pass cooperativo.

- Stato downed separato dalla morte per i player.
- Movimento, fuoco, targeting e reward disattivati durante il downed.
- Revive vicino con interact tenuto e progresso interrompibile.
- Anello world-space e stato dedicato nelle schede HUD.
- Ripristino al 35% senza accumulo del bonus `Field Kit`.
- Join e leave ripuliscono il progresso senza completamenti tardivi.
- Sconfitta party all-downed nelle tre modalita.
- Smoke test e QA con quattro player.

## Milestone 17 - Fine Run, Risultati e Menu

Stato: completata come primo flusso UI condiviso.

- Tracker sessione per durata, XP, denaro e unlock.
- Risultati espliciti per survival, dungeon e tower defense.
- Retry sul nodo modalita esistente e ultimo context.
- Cambio modalita ciclico e ritorno al menu.
- Focus joypad iniziale e input gameplay bloccato sotto l'overlay.
- Salvataggio sincrono prima del menu.
- Smoke test dei tre flussi e QA a 1280x720.

## Milestone 18 - Audio Mix e SFX Sostituibili

Stato: completata come infrastruttura audio modulare.

- Bus separati per musica, UI, armi, nemici, boss e ambiente.
- Cue con stream opzionale e fallback procedurale.
- Limite voci, priorita e variazione leggera di pitch.
- Hook per armi, archetipi nemico, wave, downed, revive e risultati.
- Slider Master, Music e SFX nel tab Audio della pagina Settings.
- Save v3 con round-trip delle impostazioni audio.
- Smoke test hook/bus e QA menu a 1280x720.

## Milestone 19 - Secondo Boss e Registro Boss

Stato: completata come primo registro boss configurabile.

- `BossSystem` registra scene, ID e compatibilita per modalita.
- `Wave Warden` resta disponibile in tutte le modalita.
- `Rift Architect` viene usato come boss finale dungeon.
- Pattern `lane_sweep` e `cross_burst` con warning world-space distinti.
- Fase 2, visual dedicato e drop garantito `Rift Repeater`.
- HUD boss reso generico per nome, fase e warning.
- Richieste incompatibili rifiutate con segnale tipizzato.
- Smoke test registry/pattern/drop e due QA visuali a 1280x720.

## Milestone 20 - Arena, Biomi e Props Interattivi

Stato: completata come primo sistema arena survival data-driven.

- `BiomePalette` e `SurvivalArenaProfile` separano dati e controller.
- Layout `Industrial Crossroads` e `Rift Foundry` selezionabili via context.
- `SurvivalArenaManager` configura playground, wave, player e supply crate.
- Gate visibili e non collidenti collegati allo spawn reale.
- Barili esplosivi colpibili senza bloccare il pathing.
- Warning temporizzato e area leggibile prima del danno.
- Danno ad area tramite `HealthSystem` ed effetto condiviso.
- Smoke test, stress a quattro player e QA di entrambi i layout.

## Milestone 21 - Accessibilita, Performance e Asset Pipeline

Stato: completata come primo pass configurabile e misurabile.

- `VisualSettingsManager` separato dai sistemi gameplay.
- Preset default, reduced motion e high contrast.
- Slider per flash, glow, trail, shake e scala testo HUD.
- Marker geometrici per i quattro player e icone pickup non basate sul colore.
- Save v4 con impostazioni visuali persistenti.
- Camera shake e motion reduction applicati solo alla presentazione.
- Convenzioni import, fallback e registro licenze in `assets/`.
- Profiling con quattro player, 28 nemici e boss a 16,58 ms medi.
- Smoke test round-trip/performance e quattro QA a 1280x720.

Attivita post-roadmap:

- roadmap motore generazione mappe e biomi completata come primo pass storico; il rewrite corrente usa seed globale, mappa biomi default `3x3`, chunk `500x500`, confini, passaggi, fall zone, layout interni, validazione flood-fill e integrazione zombie;
- roadmap megamappa persistente isometrica completata come primo pass storico; il rewrite corrente mantiene grafo seed-based connesso, territori `500x500`, passaggi fisici aperti, fall boundary sui lati esterni, terreno classificato su tutta la regione, mappa esplorazione persistente, dodge/roll e manifest asset isometrici;
- roadmap revamp modalita zombie completata fino alla Milestone Z12: cinque biomi attraversabili, spawn camera-edge, wave contestuali, layout, loot, hazard, zombie tematici, HUD e test di durata;
- sistema ammo survival robusto con arma base infinita separata, pickup
  condivisi, supply crate e director anti-frustrazione completato;
- visual gameplay pass della zombie survival completato;
- zombie ranged con telegraph e pressione a distanza completato;
- downed e revive multiplayer completati;
- risultati, retry e cambio modalita completati;
- audio mix, cue sostituibili e persistenza completati;
- secondo boss e registro configurabile completati;
- arena survival, biomi e props interattivi completati;
- accessibilita, profiling e pipeline asset completati;
- roadmap RPG Mode M1-M12 completata fino al polish feedback RPG;
- roadmap identita visuale armi completata fino alla Milestone W1: contratto
  condiviso esteso in `WeaponVisualData`, helper `WeaponVisualRenderer` e
  proiettili collegati al renderer con fallback legacy;
- roadmap identita visuale armi completata fino alla Milestone W2: pickup arma
  alimentati da `WeaponData.visual_data`, shape specifiche per le 30 armi
  catalogo e fallback `missing_weapon_visual` esplicito;
- roadmap identita visuale armi completata fino alla Milestone W3: held weapon
  e icone HUD leggono le stesse shape del renderer condiviso, con 12 armi
  rappresentative coperte da smoke e QA screenshot;
- roadmap identita visuale armi completata fino alla Milestone W4: proiettili,
  muzzle flash, impact e ground hazard delle armi firearm/elemental leggono
  profili visuali specifici senza cambiare danno, collisioni o timing;
- roadmap identita visuale armi completata fino alla Milestone W5: le armi
  melee del catalogo hanno slash, hit effect, size e shake specifici separati
  da hitbox, danno, knockback e hitstop;
- roadmap identita visuale armi completata fino alla Milestone W6: tutte le 30
  armi catalogo hanno `profile_id`, palette e shape target specifici per
  `weapon_id`, coperti dallo smoke catalogo completo;
- roadmap identita visuale armi completata fino alla Milestone W7: cinque
  tavole isolate e tre screenshot survival verificano leggibilita, preset
  visuali e budget performance in uno scenario affollato;
- roadmap identita visuale armi W0-W8 completata: contratto estensibile,
  catalogo visuale arma-per-arma, report finale e backlog `WVIS-001` chiuso;
- pass RPG leggibilita combat completato: `WeaponData.attack_type`,
  hitbox melee temporanee per ascia/spada/artigli, feedback slash e Character
  Select con indicazione projectile/melee;
- pass faceplate world-space completato dentro UIUX-001: livello/EXP circolare
  al posto di P1-P4, vita cromatica sulle due righe superiori, super verticale
  blu con glow e testi HP/ammo ingranditi; la milestone UI/UX resta aperta per il polish
  trasversale e la QA multi-risoluzione;
- polish Character Select RPG completato come pass post-roadmap: card grafiche,
  dossier aggiornato dal focus, preview gameplay procedurale, stat bar,
  selezione indipendente per-player con cursori/commit per slot e supporto
  `Esc`/joypad `B`;
- menu pausa e pagina Settings condivisa completati come feature post-roadmap:
  tab Audio, Video e Controls, save v5 e rimappatura joypad persistente;
- navigazione menu gamepad completata come polish post-roadmap: focus
  circolare, Back coerente, D-pad/stick con cooldown, LB/RB nei Settings e
  Character Select responsive con fallback asset coerente; la validazione
  repo-fix del 2026-06-20 copre anche navigazione tastiera, selezione
  indipendente da pad aggiuntivi e guardrail timeout dello smoke Character
  Select;
- Milestone 6 di `repo_fix_roadmap.md` completata: `ZombieSpawner` mantiene
  spawn preview e spawn effettivi fuori camera, espone motivi di scarto per
  test/debug, valida walkable/hazard/blocker in regioni streamate e chiude la
  regressione survival 10 wave su tutti e cinque i biomi;
- Milestone 7 di `repo_fix_roadmap.md` completata: `HUDManager` mostra il
  pannello status persistente solo in Tower Defense, nascondendolo in
  Survival/Infinite Arena, e il profilo Infinite Arena murato non genera piu
  fall zone interne dal void-first starter;
- Milestone 1 di `todo_roadmap.md` completata: shutdown headless stabilizzato,
  loop da 100 avvii della scena principale e smoke prioritari senza cleanup
  warning noti; i QA visuali screenshot restano fuori scope per limite del
  renderer dummy headless.
- Milestone 2 di `todo_roadmap.md` completata: mini-eventi bioma validati e
  tarati con telegraph specifici, reward crate tematiche, cooldown/frequenza
  coperti da smoke, status `whiteout` evitabile e checklist manuale aggiornata.
- Milestone 7 di `todo_roadmap.md` completata: hitstop melee applicato,
  rischio/beneficio starter coperto da smoke, Briciola bounded, recovery di
  Notte Bestiale leggibile e super RPG tipizzate nei VFX.
- Milestone 1 di `docs/isometric_generation_audit_roadmap.md` completata:
  manifest ambiente v3, mapping `obstacle_id -> categoria` nel generatore e
  smoke manifest esteso alla generazione `5x5`.
- Milestone 2 di `docs/isometric_generation_audit_roadmap.md` completata:
  manifest ambiente v4 con tag terrain, draw mode dedicati per strade/passaggi,
  preset `sample_step` del ground e smoke terrain esteso.
- Milestone 3 di `docs/isometric_generation_audit_roadmap.md` completata:
  manifest ambiente v5 con `object_visuals`, draw mode dedicati per ostacoli
  generati e smoke manifest/biome obstacle estesi.
- Milestone 5 di `docs/isometric_generation_audit_roadmap.md` completata:
  manifest ambiente v6 con border tematici, fall zone cliff/depth procedurale,
  query fall/hazard separate e dodge che attraversa solo piccoli gap/fall zone.
- Milestone 4 di `docs/isometric_generation_audit_roadmap.md` completata:
  collisione `BiomeObstacle` costruita dal manifest, `blocks_projectiles` su
  collision layer `32` con muri che fermano i proiettili, query
  jumpable/non-jumpable per il dodge e chiavi stabili per ostacoli.
- Milestone 6 di `docs/isometric_generation_audit_roadmap.md` completata:
  `BiomeTransitionGate` dimensionato/orientato dal passaggio e tematizzato per
  `passage_type`, span propagato da `BiomeTransitionSystem` e smoke gate/passaggio
  sui quattro lati.
- Milestone 8 di `docs/isometric_generation_audit_roadmap.md` completata:
  decisione per la continuita fisica multi-regione e prototipo
  `MultiRegionRenderer` (corrente + vicini con offset `world_origin`, vicini solo
  ground visuale, lontane non istanziate), ora mantenuto come fallback/debug
  storico dopo l'introduzione di `WorldRegionStreamer`.
- Milestone 7 di `docs/isometric_generation_audit_roadmap.md` completata:
  `WorldGraph.get_connectivity_report()`, report grafo/active regions nel
  `BiomeMapDebugOverlay` (toggle `F8`) e smoke connettivita su 100 seed.
- Milestone 9 di `docs/isometric_generation_audit_roadmap.md` completata:
  `ExplorationMapPanel` con marker active/loaded regions, passaggi tematizzati per
  `passage_type` e supporto high contrast via `apply_visual_settings`.
- Milestone 10.1 di `milestone_10_isometric_asset_rewrite_roadmap.md`
  completata: manifest ambiente v7 con sezioni asset-driven, fallback policy
  esplicita e smoke di copertura per ID generati da terrain, oggetti, passaggi,
  bordi e fall zone.
- Milestone 10.2 di `milestone_10_isometric_asset_rewrite_roadmap.md`
  completata: struttura cartelle ambiente isometrico, generatore SVG headless
  con dry-run/check/write, 74 asset SVG interni e smoke pipeline.
- Milestone 10.3 di `milestone_10_isometric_asset_rewrite_roadmap.md`
  completata: `BiomeTileLayer` chunked come ground primario, resolver
  deterministico per tile base/road/hazard/border/void su tutto il `200x200`,
  `void_edge_near` in manifest e patch terreno legacy disattivati in modalita
  asset.
- Milestone 10.4 di `milestone_10_isometric_asset_rewrite_roadmap.md`
  completata: strade, curve/edge/intersezioni, entry/exit e connector di
  passaggio asset-driven; polish successivo con `road_cell_tags` diagonali per
  far diramare le strade lungo assi isometrici; `WorldRegionConnection`
  conserva rettangoli globali e tile entry/exit per continuita tra regioni.
- Milestone 10.5 di `milestone_10_isometric_asset_rewrite_roadmap.md`
  completata: `ObstacleSystem` usa una factory per istanziare oggetti
  isometrici slot-based, `IsometricEnvironmentObject` carica sprite/texture dal
  contratto `object_scenes`, `BiomeObstacle` resta fallback tecnico e la supply
  crate usa il proprio asset manifest; polish successivo con SVG trasparenti e
  silhouette dedicate per gli oggetti principali al posto del placeholder unico;
  il loader runtime rasterizza SVG trasparenti o fallback isometrici per
  categoria quando l'import editor non e affidabile.
- Milestone 10.6 di `milestone_10_isometric_asset_rewrite_roadmap.md`
  completata: `BiomeFallZone` usa `IsometricCliffRenderer`, asset v7 per
  void/cliff/lip orientati e linee verticali deterministiche, mantenendo danno
  da caduta, respawn sicuro e query fall/hazard separate.
- Milestone 10.7 di `milestone_10_isometric_asset_rewrite_roadmap.md`
  completata: `RegionSeamSystem` aggiorna la regione corrente dalla posizione
  world-space del party e dai `WorldRegionConnection` aperti; la survival non
  istanzia piu `BiomeTransitionGate` o trigger visibili per cambiare bioma.
- Milestone 10.8 di `milestone_10_isometric_asset_rewrite_roadmap.md`
  completata: `WorldRegionStreamer` istanzia regione corrente e vicini connessi
  come contenuto gameplay `FULL` con tile, ostacoli, hazard/fall zone e crate;
  le query dei sistemi vedono i vicini prima dell'attraversamento e le crate
  aperte restano persistenti per `region_id`.
- Milestone 10.9 di `milestone_10_isometric_asset_rewrite_roadmap.md`
  completata: gli zombie restano world-space durante il chase cross-bioma,
  tracciano `spawn_region_id`, `current_region_id` e
  `last_seen_player_region_id`, attraversano i varchi aperti senza despawn,
  reset di health o perdita del target.
- Milestone 10.10 di `milestone_10_isometric_asset_rewrite_roadmap.md`
  completata: la survival standard non istanzia piu visual legacy
  (`BiomeTransitionGate`, `BiomeRegionGround`, `BiomeTerrainPatch`,
  `NeighborGround_` o renderer vicini storico); `MultiRegionRenderer` resta
  fallback lazy-only e `tests/milestone_10_legacy_cleanup_smoke_test.gd`
  blocca regressioni sul percorso asset-driven.
- Milestone 10.11 di `milestone_10_isometric_asset_rewrite_roadmap.md`
  completata: QA visuale finale con sette screenshot `1280x720`, performance
  smoke su mappa `7x7` in preset `balanced` a `16,54 ms` medi, suite smoke
  asset/terrain/passaggi/oggetti/cliff/no-portal/streaming/chase/legacy verde e
  `ISO-001` spostato tra le reference completate.
- Milestone R1 di `isometric_biome_generation_rewrite_roadmap.md` completata:
  chunk bioma `500x500`, megamappa default `3x3`, base void con floor/strade/
  blocchi scavati, strade principali larghe 40, sentieri medi larghi 20,
  passaggi larghi 40, cache terrain, validazione void/spawn e smoke dedicato.
- Milestone R2/forest pass di `isometric_biome_generation_rewrite_roadmap.md`
  completata: pareti perimetrali isometriche, bordo void/cliff leggibile,
  varchi fisici senza portali e primo set texture forestale asset-driven per il
  bioma base `infected_plains`, con grass, tall grass, path, road, void, cliff,
  mountain wall e transizioni neighbor-aware.
- Milestone R3.2 di `isometric_biome_generation_rewrite_roadmap.md`
  completata come vertical slice starter: road network edge-to-edge, sentieri
  `broken_street`, `ruined_house`, vegetazione densa impassabile, dettagli
  strada, fiume/bridge validato, summary seed/debug e asset manifest dedicati
  per `abandoned_car` e `dense_vegetation`.
- Milestone 8 di `repo_fix_roadmap.md` completata e ripresa con hotspot
  aggiuntivi: `WeaponVisualShapeLibrary` e stato estratto da
  `WeaponVisualRenderer`, `IsometricSvgFallbackTextureBuilder` da
  `IsometricSvgTextureLoader`, `IsometricTileCatalog` e
  `IsometricTileResolverUtils` da `IsometricTileResolver`, e
  `BiomeObstaclePainter` da `BiomeObstacle`; gli entry point restano
  compatibili e i nuovi confini sono coperti da smoke mirati.
- Milestone 9 di `repo_fix_roadmap.md` completata come prima passata:
  dependency lookup ridotti da 216 a 184 in `game/`, con NodePath/cache locali
  in `HUDManager`, injection `PlayerManager -> PlayerController` e injection
  `ZombieModeController -> ZombieSpawner`, senza introdurre service locator
  generici.
- Milestone 10 di `repo_fix_roadmap.md` completata: asset/fallback policy
  classificata in una nota QA dedicata, manifest standard senza status
  temporanei, nuovo smoke contro placeholder/generic e survival standard
  verificata su tile layer asset-driven, streamer `FULL`, ostacoli
  asset-backed e assenza di visual legacy.
- Milestone W0 di `weapon_visual_identity_roadmap.md` completata: baseline
  visuale delle 30 armi catalogo, conferma dei tre profili generici correnti,
  reference da preservare e checklist manuale per pickup, held, HUD,
  projectile, melee, elemental e scene affollate.
- Pass ISO-OBS-001 completato: manifest ambiente v9 con footprint slot-based,
  nove formati piccoli `1x1`-`3x3`, case `4x4`/`5x3`/`6x6`, SVG nativi
  footprint-specific, base visiva coincidente con collisione, record ostacolo
  completo e overlay `F9`. Lo smoke dedicato valida anche assenza di collisioni
  invisibili e distinzione fra ostacoli solidi e void/cliff.
- Pass ISO-OBS-002 completato: `forest_tree` e `large_rock` introducono art PNG
  trasparente per due ostacoli singoli `3x3`, piazzamento garantito nella
  Pianura Infetta, collisione rettangolare su tutti i nove slot e screenshot QA
  gameplay/footprint in `build/qa/obstacle_3x3/`.
- asset definitivi e ulteriori pass di bilanciamento;
- firma digitale della build pubblica.

## Milestone RPG Advanced Classes - primo pass

Stato: completata come prototipo data-driven.

- Aggiunte tre classi giocabili al roster RPG/Zombie Survival senza sostituire i quattro starter.
- `Mago` / Elio Braciastella con Bastone arcano, Risonanza Arcana e Stella Cadente.
- `Domatrice` / Nina Bullone con Fionda magnetica, companion Briciola e Branco di Rottami.
- `Licantropo` / Rocco Lunastorta con Artigli, Odore del Sangue e Notte Bestiale.
- Character Select esteso con icone personaggio e slot player per selezioni RPG distinte nella stessa run survival.
- Placeholder procedurali, palette HUD e path asset definitivi restano data-driven nei profili.
- Smoke test dedicato previsto in `tests/milestone_rpg_13_new_classes_smoke_test.gd`.
- Pass Milestone 7 completato: Briciola resta supporto non bloccante, il frenzy
  ha limiti testati e Notte Bestiale espone recovery visuale/testabile.

## Milestone Megamappa Persistente Isometrica - primo pass

Stato: completata come prototipo integrato.

- Aggiunto `game/world/` con `WorldGraph`, `WorldRegion`, `WorldRegionConnection`, `WorldExplorationState`, `PersistentWorldState` e `WorldRuntime`.
- La survival genera una griglia default `3x3` di territori `500x500` tramite seed, spanning tree e edge extra per avere connessione garantita e loop.
- Il controller zombie lascia il `3x3` come default runtime della survival
  standard; il profilo `1x1` resta disponibile solo con context
  `single_biome_arena` per quick test/debug.
- Dopo il riallineamento repo-fix del 2026-06-20, questo contratto `3x3`
  appartiene a `Zombie Survival`; il default/quick play e `Infinite Arena`, una
  singola cella `500x500` con muri perimetrali e senza runtime esplorazione.
- I passaggi tra regioni confinanti sono aperture fisiche aperte e non teletrasporti; i lati senza regione vicina restano fall boundary validati.
- Il layout di ogni territorio produce classificazione completa del `500x500` per walkable, obstacle, hazard, border, void e fall zone.
- Il save v6 conserva stato mondo/esplorazione e posizione di riferimento del party.
- L'HUD espone una mappa consultabile con unknown/fog, discovered, visited, cleared e marker della regione corrente.
- Aggiunto `PlayerDodgeComponent` con input tastiera/joypad, cooldown, invulnerabilita breve e validazione gap/landing.
- Aggiunto manifest iniziale per censire asset ambientali isometrici e sostituzioni future.
- Smoke test dedicati coprono connettivita grafo, persistenza, passaggi aperti, classificazione terreno, fall boundary, mappa esplorazione e dodge/gap.

## Milestone Inventario Armi e Catalogo - primo pass

Stato: completata come prototipo integrato.

- Separati dati statici `WeaponData` e stato runtime `WeaponInstance`.
- Aggiunto inventario ordinato per ogni player; il pass input del 2026-06-20
  separa l'istanza base dalla collezione, assegna `RB` alla base e `LB` all'arma
  equipaggiata e limita lo switch circolare D-pad alle sole armi raccolte.
- Pickup non distruttivi, duplicati convertiti e stato ammo/reload/cooldown persistente.
- Registry globale di run impedisce allo stesso `weapon_id` di apparire due volte; fallback ammo a pool esaurito.
- Aggiunte 30 armi data-driven: 10 firearm, 10 melee e 10 elemental.
- Generalizzati AOE, explosion, status, knockback, chain, pierce, cone, charge, delayed explosion e ground hazard.
- HUD esteso con arma selezionata, lista inventario, reload, ammo ed effetto principale.
- Dopo la ripulitura repo-fix del 2026-06-20, reload, caricatore, EXP e super
  sono owner del `PlayerWorldHudVisual`; `PlayerHudCard` resta riepilogo slot
  con ritratto, arma, riserva, inventario, statistiche, passive e status.
- Smoke dedicato e regressioni combat/drop/RPG/survival verdi.

## Pass Caduta Void e Dodge - completato

- Query terrain world-space unica per celle `walkable`, `hazard`, `fall_zone`
  e `void`, compatibile con regioni streamate e fallback mono-regione.
- Stati player `normal/dodging/falling/dead`, verifica void differita a fine
  dodge e danno singolo dopo l'animazione di caduta.
- Caduta zombie condivisa con `death_reason = void` e reward completamente
  disabilitate prima della notifica di morte alla wave.
- Copertura automatica in `tests/zombie_fall_hazard_smoke_test.gd` e
  regressioni combat, drop, wave, ranged enemy e terrain coverage verdi.

## Milestone Mercato Zombie Ricorrente - primo pass

Stato: completata come feature integrata.

- Boss wave confermate ogni cinque ondate.
- Fase mercato separata da spawn/combat dopo le wave 5, 10, 15 e successive.
- Wallet denaro party condiviso con spesa atomica e feedback di rifiuto.
- Cura, refill arma attiva, refill tutte le armi e quattro offerte casuali dal
  catalogo con prezzi configurabili per rarita.
- Acquisto arma per-player non distruttivo sull'inventario a istanze.
- Navigazione indipendente P1-P4, indicatori slot e ready unanime dei player
  vivi prima della wave successiva.
- Reset stato/offerte su nuova run e protezione da riaperture duplicate.
- Contratto in `docs/zombie_market.md`, checklist manuale e smoke dedicato.
