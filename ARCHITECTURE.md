# ARCHITECTURE

## Visione tecnica

Il progetto e un sandbox Godot 4.x 2D con resa pseudo-isometrica. La scena principale avvia un playground minimo e registra i sistemi base. Le modalita future devono usare sistemi comuni invece di duplicare gameplay.

## Flusso runtime attuale

1. `main.tscn` carica manager, world e `MainMenu`.
2. `GameModeManager` entra nello stato `menu` senza avviare gameplay.
3. `SaveManager` carica progressione party, unlock e ultima modalita da JSON.
4. `MainMenu` seleziona una modalita registrata; per survival apre prima
   `Character Select` e passa `character_ids_by_slot` nel context, con
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
11. `WeaponSystem` gestisce fallback permanente, speciale, cooldown,
    caricatori, riserve, ricarica e risoluzione `attack_type` per il singolo
    player.
12. `WeaponData` inoltra l'eventuale `WeaponVisualData` a player, HUD,
    proiettile o hitbox melee temporanea.
13. `ProjectileSystem` spawna proiettili ranged; `MeleeAttack` copre i colpi
    melee temporanei. Entrambi applicano danno tramite `HealthSystem`.
14. `EnemySystem` spawna basic, runner, tank e shooter; gli archetipi riusano targeting, health, scaling, morte e drop condivisi.
15. Alla morte, il nemico chiede a `DropSystem` di generare pickup dalla propria `LootTable`.
16. `DropPickup` delega l'applicazione della ricompensa a `DropSystem`.
17. `GameModeManager` avvia `SurvivalMode`, che applica il profilo RPG scelto e seleziona un profilo arena tramite `SurvivalArenaManager`.
18. `ZombieModeController` avvia i componenti revamp zombie e forza il bioma iniziale tramite `BiomeManager`.
19. `BiomeManager` genera una megamappa seed-based tramite `BiomeWorldGenerator`, con territori `200x200`, grafo connesso, passaggi condivisi, fall boundary, layout validati e regione corrente.
20. `WorldRuntime` mantiene grafo, stato esplorazione, regione corrente e stato persistente sovrapposto al layout rigenerato dal seed.
21. `BiomeTransitionSystem` crea passaggi fisici aperti tra regioni confinanti e aggiorna la regione corrente senza teletrasporto nel flusso standard.
22. `SurvivalArenaManager` configura playground, player, crate, gate e fallback spawn per lo spawner.
23. `HazardSystem` genera fall zone e hazard ambientali, aggiorna posizioni sicure, status e modificatori movimento.
24. `WaveManager` interroga `WaveDirector` per roster/scaling bioma e `ZombieSpawner` per spawn dai bordi camera, poi crea zombie tramite `EnemySystem`.
25. `SurvivalMode` usa `GameModeManager` e `BossSystem` per creare il boss della quinta ondata.
26. `WaveManager` conta scorte e boss prima di assegnare la ricompensa.
27. `DungeonMode` genera un layout da seed, istanzia una `DungeonRoom` alla volta e usa nemici, drop e boss condivisi.
28. `DungeonRoom` controlla pareti, portale e stato locked/unlocked della stanza corrente.
29. `TowerDefenseMode` gestisce lifecycle, arena, player e richieste costruzione.
30. `TowerDefenseWaveController` governa ondate e usa `EnemySystem` per i nemici da percorso.
31. `TowerDefenseManager` mantiene vita core e crediti, mentre gli slot delegano lo spawn delle torri.
32. `DefenseTower` seleziona target e inoltra direzione e fuoco a `DefenseTowerVisual`.
33. `ProgressionManager` prepara i player a ogni nuova run applicando gli unlock persistenti.
34. `ReviveSystem` coordina prossimita, interact tenuto e progresso per i player downed.
35. `SurvivalAmmoDirector` osserva l'ammo speciale dei player vivi e genera supply crate configurabili.
36. `AudioEventRouter` traduce eventi gameplay in cue richiesti ad `AudioManager`.
37. `AudioManager` gestisce bus, fallback, stream opzionali, priorita e volumi.
38. `VideoSettingsManager` applica fullscreen, borderless, risoluzione, VSync
   e limite framerate.
39. `VisualSettingsManager` distribuisce solo impostazioni presentazionali e le persiste nel save.
40. `IsometricCameraController` segue il gruppo e applica shake solo tramite offset.
41. `HUDManager` mostra slot, progressione, vita, munizioni, stato modalita, boss e mappa esplorazione.
42. I componenti visuali ricevono stato e profilo senza possedere logica gameplay.
43. `BossTelegraphVisual` riceve pattern, direzione e durata senza possedere danno.
44. `WaveWardenVisual` e `RiftArchitectVisual` ricevono solo stato presentazionale.
45. `CombatAnnouncement` presenta segnali wave e boss tradotti da `HUDManager`.
46. `GameplayEffects` ascolta segnali pubblici e genera effetti temporanei.
47. `RunSessionTracker` misura durata e delta progressione tra start e fine run.
48. `RunResultsScreen` presenta il risultato e delega retry/menu/cambio.

## Sistemi principali

- `InputManager`: crea e legge azioni per slot player e globali. Ogni slot usa azioni `p{slot}_{azione}`, incluso `dodge`; `world_map` e una azione globale; `ui_cancel` mappa `Esc` e joypad `B` per tornare dai pannelli menu; `ui_up/down/left/right` includono frecce, D-pad e stick sinistro per la navigazione UI.
- `MenuNavigationController`: helper UI riusabile per liste focus circolari,
  Back/B, input D-pad/stick con cooldown e cambio tab LB/RB.
- `LocalMultiplayerManager`: mantiene gli slot locali attivi, gestisce join/leave e usa mapping deterministico `device joypad + 1 = player_slot`.
- `PlayerManager`: spawna/despawna player in base agli slot attivi e tiene il registro degli slot.
- `PlayerController`: movimento, mira, fire action, dodge/roll e colore visuale per slot.
- `PlayerDodgeComponent`: roll con cooldown, invulnerabilita breve, blocco
  del fuoco durante la schivata e validazione di landing/gap/ostacoli; solo le
  fall zone sono trattate come gap attraversabili, mentre gli hazard
  ambientali bloccano traiettoria e landing.
- `ReviveSystem`: progresso cooperativo centralizzato per target downed e reviver vicino.
- `GameModeManager`: registra, arresta e avvia le modalita.
- `RunSessionTracker`: traduce i segnali terminali in dati risultato runtime.
- `RunResultsScreen`: overlay condiviso con focus e azioni di fine run.
- `MainMenu`: UI iniziale, selezione modalita, `Character Select` survival per slot player, continue e ritorno con `Esc`/joypad `B`; usa `MenuNavigationController` per focus circolare e back coerente.
- `CharacterSelectCard`: card RPG selezionabile con portrait menu dedicato,
  fallback gameplay/procedurale, icone classe/arma, stat bar compatte e
  indicatori slot.
- `CharacterDetailPanel`: dossier laterale della Character Select con descrizione stile, stat leggibili, range arma e preview.
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
  timing melee opzionale e riferimento visuale opzionale.
- `WeaponVisualData`: palette, dimensioni e profilo condivisi da arma, HUD, proiettile e flash.
- `WeaponSystem`: stato runtime per-player di fallback, speciale, cooldown,
  munizioni, ricarica e dispatch tra projectile e melee.
- `MeleeAttack`: hitbox temporanea world-space per swing melee con wind-up,
  active time, recovery tramite cooldown, anti-multihit per bersaglio e
  feedback trail; applica anche knockback e hitstop configurati in
  `WeaponData`.
- `ProjectileSystem` e `Projectile`: spawn, movimento, collisione e consegna del danno.
- `HealthSystem` e `HealthComponent`: richieste globali di danno/cura, stato vita locale e invulnerabilita componibile per sorgente; il danno ambientale puo ignorarla esplicitamente.
- `EnemySystem`: registro di scene nemico per ID, spawn, contenitore, registro runtime e notifica morte.
- `BasicEnemy`: AI melee condivisa con stati idle, chase, attack e dead.
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
- `WorldRegion`: dati stabili di un territorio `200x200`, inclusi biome ID, coordinate, origine mondo, vicini, connessioni e layout generato.
- `WorldRegionConnection`: edge navigazionale tra due regioni confinanti, con lato, direzione opposta, centro/larghezza del passaggio e coordinate globali.
- `WorldExplorationState`: stato unknown/discovered/visited/cleared per regione e marker della regione corrente.
- `PersistentWorldState`: payload serializzabile del mondo, seed, regione corrente, posizione party e stato esplorazione.
- `WorldRuntime`: runtime del grafo persistente; sincronizza `BiomeManager`, exploration state e save/load, con spazio per streaming regioni.
- `WorldGenerationSeed`: seed globale di run e derivazione deterministica degli stream RNG per mappa, terreno, ostacoli, bordi, loot e spawn.
- `BiomeWorldGenerator`: orchestratore della pipeline procedurale globale per mappa biomi, layout per cella e debug seed.
- `BiomeMapGenerator`: costruisce la griglia di `BiomeCell` `200x200`, assegna tipi bioma, coordinate globali, vicini, seed locali e grafo connesso con loop.
- `BorderGenerator`: calcola lati connessi e lati esterni di caduta per ogni cella bioma.
- `BiomePassageGenerator`: crea passaggi condivisi e allineati tra celle confinanti.
- `BiomeTerrainGenerator`: genera il layout interno del bioma attivo e collega ostacoli, casse, hazard e report di validazione.
- `IsometricEnvironmentManifest`: legge `assets/environment/isometric/manifest.json`
  come inventario di ostacoli, draw mode oggetto, border tematici, fall zone
  procedurali e tag terrain isometrici generati.
- `ObstacleLayoutGenerator`: produce strade, corridoi, case grandi, ostacoli
  secondari e muri/bordi tematici sui lati connessi o bloccati.
- `FallBoundaryGenerator`: trasforma i lati senza vicino in `fall_zone` data-driven con il contratto di danno ambientale esistente.
- `MapValidationSystem`: valida con flood-fill spawn, corridoi, passaggi, casse raggiungibili, grafo connesso, passaggi non ostruiti e classificazione completa del `200x200`.
- `BiomeMapDebugOverlay`: espone seed corrente, riepilogo celle/passaggi,
  classi terrain aggregate e richieste di rigenerazione per debug.
- `BiomeDefinition`: risorsa dati con terreno, ostacoli, casse, zombie ammessi, pesi, palette e moltiplicatori.
- `BiomeTransitionSystem`: passaggi fisici aperti tra regioni confinanti, cambio regione/bioma e fallback legacy di spostamento party solo se esplicitamente abilitato.
- `BiomeTransitionGate`: area non bloccante e leggibile che rappresenta un'apertura fisica e richiede il cambio regione.
- `BiomeEnvironmentLayout`: placement deterministico di patch terreno, ostacoli fisici, casse e hazard per un bioma, con classificazione completa del `200x200`.
- `WaveDirector`: composizione wave e scaling basati sul bioma corrente.
- `ZombieSpawner`: spawn dai bordi della camera con distanza minima dai player, validazione hazard/ostacoli e fallback arena.
- `TerrainGenerator`: applica la palette del bioma, genera il piano visuale
  `200x200`, legge gli stili terrain dal manifest e crea decorazioni non
  collidenti dal layout.
- `BiomeRegionGround`: base visuale estesa dell'intero territorio, separata
  dalle patch decorative puntuali, con `sample_step` guidato dai preset del
  manifest.
- `BiomeTerrainPatch`: patch decorativa procedurale che usa draw mode
  data-driven per strade, passaggi e dettagli bioma senza possedere collisioni.
- `ObstacleSystem`: genera e registra `BiomeObstacle` fisici usati anche come spawn blocker.
- `BiomeObstacle`: usa draw mode procedurali data-driven dal manifest per
  distinguere gli ostacoli dei biomi senza cambiare collisioni o placement.
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
- `HUDManager`: UI prototipo per HUD gameplay, boss, annunci e mappa esplorazione.
- `ExplorationMapPanel`: pannello consultabile che disegna grafo, fog/unknown, regioni discovered/visited/cleared, connessioni note e regione corrente.
- `PlayerVisual`: presentazione procedurale data-driven del player, con silhouette e palette derivate dal profilo RPG.
- `ZombieVisual`: presentazione animata procedurale degli zombie.
- `DropPickupVisual` e `SupplyCrateVisual`: icone world-space sostituibili.
- `BossTelegraphVisual`: warning world-space per pattern aimed, radial e cambio fase.
- `WaveWardenVisual`: silhouette, animazione e stato visuale delle due fasi del boss.
- `PlayerHudCard`: scheda HUD riusabile per ogni slot locale, inclusa indicazione minimale del cooldown roll.
- `CharacterSelectCard`, `CharacterDetailPanel` e `CharacterGameplayPreview`: controlli presentazionali della selezione RPG, senza autorita su context survival o applicazione profili.
- `RpgHudIcon`: icona procedurale leggera per ritratto classe, passive e super RPG.
- `BriciolaCompanion`: companion alleato leggero della Domatrice con follow,
  target acquire, dash attack, recover e frenzy super bounded; e `Node2D`
  visuale/assistivo, senza collisione fisica con Nina.
- `ReviveIndicatorVisual`: anello world-space con colore slot e progresso.
- `WeaponIcon`: icona HUD generata dal profilo dell'arma attiva.
- `CombatAnnouncement`: banner temporaneo e riusabile per transizioni gameplay.
- `GameplayEffects`: feedback visuale event-driven, inclusi level-up e super
  RPG tipizzate per starter e classi avanzate, senza dipendenze dai controller.

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
- I telegraph boss mostrano direzione, area e durata prima del danno e non possiedono collisioni.
- `WaveWardenVisual` riceve solo stato presentazionale da `BasicBoss`.
- Gli annunci HUD reagiscono ai segnali pubblici e non pilotano wave o boss.
- Arma world-space, icona HUD, proiettile e muzzle flash leggono lo stesso `WeaponVisualData`.
- Ritratto classe e icona super RPG sono disegnati da `RpgHudIcon` e non alterano stats, input o cooldown.
- `DefenseTowerVisual` riceve mira e feedback ma non sceglie target, range, danno o fire rate.
- `GameplayEffects` reagisce a segnali pubblici e non applica danno, cura o ricompense.
- Level-up e super RPG emettono segnali dal `RpgPlayerComponent`; feedback visuale e audio li consumano senza modificare stats o cooldown.
- I bersagli combat debug restano istanziati ma invisibili e senza collisione nel gameplay normale; lo smoke test combat abilita la fixture usata.

## Contratto combat

- Ogni istanza player possiede il proprio `WeaponSystem`; caricatore, riserva e cooldown non sono condivisi.
- Ogni `WeaponSystem` conserva sempre una fallback infinita e al massimo una speciale finita.
- Esaurire caricatore e riserva della speciale attiva la fallback e tenta lo sparo nello stesso input.
- La fallback infinita conserva caricatore e reload; solo la riserva e virtualmente infinita.
- Un nuovo rifornimento della speciale la riattiva e avvia il reload.
- Le statistiche di bilanciamento vivono in risorse `WeaponData`, non nel controller player.
- Le armi RPG di base sono `WeaponData` dedicate e vengono equipaggiate dal profilo `RpgPlayerComponent`.
- `WeaponData.max_range` limita la vita del proiettile o definisce la portata
  leggibile delle armi melee.
- `WeaponData.scatter_degrees` viene applicato da `WeaponSystem` alla direzione di sparo.
- `WeaponData.attack_type` decide il runtime: `projectile` usa
  `ProjectileSystem`, mentre `melee_arc`, `melee_rect`, `melee_sweep` e
  `dash_slash` usano `MeleeAttack`.
- `WeaponData.hitbox_type`, `hitbox_size` e `max_hit_count` configurano la
  collisione runtime separatamente dal visual; i campi `melee_*`,
  `windup_time`, `active_time`, `recovery_time`, `knockback`, `hitstop`,
  `trail_style`, `effect_key` e `sound_key` rifiniscono i colpi melee senza
  duplicare il sistema danni.
- `WeaponSystem.get_reload_ratio()` espone il progresso reload; il moltiplicatore `reload_speed` RPG riduce la durata.
- `WeaponSystem` legge il moltiplicatore fire rate RPG solo dal componente del proprio player, usato dalla passiva `Mano Veloce`.
- Le passive RPG modificano danno, cadenza o mitigazione attraverso `RpgPlayerComponent`, senza duplicare collisioni o logica proiettile.
- Le super RPG consumano 100 adrenalina e delegano proiettili/danni ai sistemi condivisi, senza creare un combat path separato.
- L'adrenalina arriva da danno applicato, danno subito, kill confermate e reward wave survival.
- Palette, silhouette e trail vivono in `WeaponVisualData` e non modificano il bilanciamento.
- `ProjectileSystem` riceve i dati dello sparo e configura il proiettile prima di aggiungerlo alla scena.
- Il parametro visuale di `ProjectileSystem` e opzionale per mantenere compatibili boss e chiamanti esistenti.
- Il proiettile non conosce classi nemico specifiche: colpisce body o area damageable e inoltra il danno a `HealthSystem`.
- `Projectile` emette l'impatto risolto e `ProjectileSystem` lo espone ai sistemi di feedback.
- `HealthSystem` cerca un figlio `HealthComponent` sul target; player, nemici, boss e bersagli debug possono condividere lo stesso contratto.
- `HealthSystem.apply_damage()` accetta una sorgente opzionale per applicare attacco/difesa RPG senza cambiare collisioni o AI.
- `HealthSystem` conserva la sorgente dell'ultimo danno valido per assegnare XP al killer.
- Collision layer `1`: player e corpi generici.
- Collision layer `2`: bersagli damageable.
- Collision layer `4`: proiettili; la mask attuale colpisce il layer `2`.
- Collision layer `8`: pickup; la mask attuale rileva i player sul layer `1`.
- Collision layer `16`: proiettili ostili; la mask colpisce i player sul layer `1`.
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
- Cura e arma vengono applicate al player che raccoglie.
- Un pickup non viene consumato se la ricompensa non puo essere applicata, per esempio cura su vita piena.
- Un pickup ammo non viene consumato se nessun player vivo possiede una speciale.
- Il drop arma equipaggia immediatamente il relativo `WeaponData`; inventario e scelta arma restano futuri.
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
- `InputManager` espone la rimappatura joypad di movimento, mira, fire,
  reload, super, interact, dodge, pause e world map.
- `active_slots_changed` e il segnale autoritativo: i sistemi interessati devono ascoltare questo segnale invece di duplicare lo stato multiplayer.

## Contratti per modalita

Ogni modalita deriva da `BaseGameMode` e fornisce:

- `mode_id`;
- start/stop;
- condizione di vittoria/sconfitta;
- richiesta boss;
- collegamento a spawn nemici, drop e progressione.

Lo stato `menu` non e una modalita gameplay registrata. Entrare in `menu` arresta la modalita corrente; i player restano istanziati ma il loro input gameplay viene sospeso.

## Contratto salvataggi

- Il file predefinito e `user://savegame.json`.
- Il formato v6 contiene progressione, ultima modalita, audio, impostazioni
  visuali, video, controlli joypad e stato mondo/esplorazione.
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
- `BiomeMapGenerator` produce una griglia di territori `200x200` con grafo connesso: uno spanning tree garantisce raggiungibilita e edge extra aggiungono loop.
- Ogni `WorldRegionConnection` deve corrispondere a un passaggio fisico aperto su entrambi i lati confinanti.
- Due regioni adiacenti senza edge navigazionale hanno bordo bloccato; un lato senza regione vicina diventa fall boundary.
- `BiomeEnvironmentLayout` deve classificare tutto il `200x200` come walkable, obstacle, hazard, border, void o fall zone.
- `MapValidationSystem` rifiuta grafi non connessi, passaggi ostruiti, passaggi non fisici e classificazione incompleta.
- `WorldRuntime` mantiene `current_region_id` e marca visited/discovered senza possedere regole combat.
- `WorldRuntime.stop_run()` rilascia riferimenti a grafo e `BiomeManager`; i
  generatori di supporto procedurale senza lifecycle di scena sono `RefCounted`.
- `ExplorationMapPanel` mostra solo regioni note; unknown/fog non rivela la topologia completa.
- `SaveManager` sovrappone `PersistentWorldState` alla prossima generazione con lo stesso seed.
- Streaming/istanza selettiva delle regioni lontane e un follow-up: il primo pass mantiene il contratto runtime e i dati persistenti pronti.

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
- `WeaponSystem` genera feedback per low ammo, reload e fallback.
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
- Ogni run survival genera o rigenera una megamappa persistente seed-based; in assenza di seed manuale usa un seed default stabile, mentre un context `world_seed` permette riproduzione e debug.
- La megamappa contiene territori `200x200`, seed locali, vicini, bordi, grafo connesso, passaggi fisici, fall boundary e layout ambientali validati prima di essere assegnati alle `BiomeDefinition`.
- Ogni nuova run survival riparte dalla `Pianura Infetta`.
- `WorldRuntime` marca la regione iniziale come visited, scopre i vicini collegati e conserva lo stato esplorazione.
- `BiomeTransitionSystem` collega territori confinanti tramite passaggi aperti; il party condivide una sola regione corrente.
- Quando e disponibile una cella procedurale corrente, `BiomeTransitionSystem` genera aperture dai `BiomePassage`; il fallback `previous_biome_id`/`next_biome_id` resta per compatibilita.
- Il cambio regione applica terreno, ostacoli, casse, hazard e passaggi della nuova regione senza riavviare `WaveManager`.
- `WaveDirector` legge il bioma corrente per risolvere roster, moltiplicatori, ritmo spawn e drop.
- Lo scaling contestuale considera wave, player vivi, tempo sopravvissuto e profondita del bioma.
- Ogni bioma legge `BiomeEnvironmentLayout` per terreno, ostacoli, casse e hazard senza placement hardcoded nei controller.
- Ogni `BiomeEnvironmentLayout` espone una classificazione completa del `200x200` usata da validazione, dodge/gap e debug.
- `TerrainGenerator` modifica solo palette e decorazioni; non possiede collisioni o regole combat.
- `BiomeObstacle` usa `StaticBody2D` sul layer `1`, quindi player e zombie lo trattano come impedimento fisico.
- Gli ostacoli appartengono anche ai gruppi `environment_obstacles` e `spawn_blockers`.
- `BiomeObstacle` legge `draw_mode` e `dedicated_draw` da
  `IsometricEnvironmentManifest`; se un ID ricade su `generic_barrier`, deve
  essere una scelta esplicita del manifest e non un fallback implicito.
- I lati con regione adiacente ma senza edge e i segmenti chiusi dei lati
  collegati usano border ID tematici per bioma; il lato senza regione resta
  fall zone e non ostacolo.
- Ogni layout conserva un corridoio centrale libero per l'AI diretta esistente.
- `assets/environment/isometric/manifest.json` v6 contiene i draw mode oggetto
  in `object_visuals`, i border tematici generati, lo stato procedurale
  dedicato della `fall_zone` e i tag terrain generati per strade e passaggi,
  il relativo `draw_mode` procedurale e i preset
  `performance`/`balanced`/`quality` per il campionamento del ground.
- I tag terrain generati da `ObstacleLayoutGenerator` e
  `BiomePassageGenerator` devono essere presenti nel manifest o avere fallback
  documentato; gli smoke falliscono se un nuovo tag strada/passaggio ricade su
  `dirt` generico.
- Cambiare draw mode oggetto/terrain o `sample_step` e un cambio
  presentazionale: non modifica classificazione, collisioni, pathfinding,
  hazard o regole di movimento.
- `ResourceCrateSystem` valida le posizioni contro `ObstacleSystem`, `HazardSystem` e la distanza minima tra casse.
- Casse comuni, mediche, militari e tematiche usano loot table dedicate ma continuano a generare pickup tramite `DropSystem`.
- I loot tematici aggiungono `resource_tag` presentazionali senza creare un secondo inventario.
- `HazardSystem` delega tossico, fuoco, gelo, acqua e fango a `BiomeStatusRuntime`, tramite danno periodico o `environment_speed_multiplier`.
- `BiomeHazardCatalog` centralizza valori runtime e colori, evitando tuning nascosto nel controller.
- La fall zone conserva il contratto speciale: 20 HP, respawn sicuro e invulnerabilita dedicata.
- `HazardSystem.is_position_hazardous()` resta la query aggregata per spawn e
  sicurezza; `is_position_fall_zone()` identifica il vuoto/caduta, mentre
  `is_position_environment_hazard()` identifica lava, gas, acqua profonda e
  altri hazard ambientali.
- Il dodge usa la query fall zone per attraversare piccoli gap e rifiuta gli
  hazard ambientali come ostacoli di traiettoria/landing.
- `EnemySystem` registra i profili tematici sullo stesso `basic_enemy.tscn`.
- `BasicEnemy` applica status al contatto, resistenza, emersione o hazard alla morte solo se definiti dal profilo.
- Terreno, ostacoli e casse ambientali vengono rimossi da `ZombieModeController.stop_run()`.
- L'arresto di survival rimuove i nemici e il boss della wave prima di attivare un'altra modalita.
- `WaveManager` e autoritativo per indice ondata, stato, spawn pendenti e nemici della wave.
- Gli stati runtime sono `idle`, `intermission`, `spawning`, `combat` e `reward`.
- Gli zombie vengono creati esclusivamente tramite `EnemySystem.spawn_enemy()`.
- `WaveManager.get_enemy_id_for_spawn()` delega a `WaveDirector` quando presente, con fallback deterministico legacy.
- Le posizioni spawn reali vengono richieste a `ZombieSpawner`; `spawn_points` resta fallback e contratto visuale per i gate arena.
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
- Le ricompense ammo alimentano solo lo slot speciale; la fallback non necessita drop.
- `SurvivalAmmoDirector` valuta ogni secondo i player vivi con speciale.
- Sotto la soglia configurata di 8 colpi totali puo generare una supply crate, con cooldown di 12 secondi.
- Ogni boss wave riceve una supply crate garantita prima dell'avvio o all'inizio della wave.
- Le crate attive non aperte vengono rimosse quando survival si arresta.
- Join e leave non modificano il conteggio nemici; i nuovi player partecipano alle ricompense successive.
- Ogni quinta ondata emette `boss_wave_requested` e `SurvivalMode` la inoltra a `BossSystem`.
- La boss wave usa due zombie di scorta e un boss registrato separatamente.
- `WaveManager` include il boss nel conteggio e aspetta il suo segnale `died`.
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
- Il menu principale seleziona dungeon; `F5` e `F1` restano scorciatoie debug.
- Diramazioni, shop, biomi e persistenza della run non fanno parte del prototipo minimo.

## Contratto tower defense

- `F6` seleziona `TowerDefenseMode`; il cambio modalita arresta e ripulisce survival o dungeon.
- La modalita istanzia una `TowerDefenseArena` e nasconde il playground prototipo.
- `TowerDefenseWaveController` e autoritativo per stato, indice wave, spawn e bersagli tracciati.
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
