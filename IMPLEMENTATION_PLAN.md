# IMPLEMENTATION_PLAN

## Revamp modalita zombie

Roadmap di riferimento: `roadmap_revamp_modalita_zombie.md`.

Stato corrente: roadmap Z1-Z12 completata e verificata.

## Ricognizione iniziale

- Modalita zombie: `game/modes/survival/survival_mode.gd` avvia e ferma la run, applica il profilo RPG, attiva arena/ammo director e inoltra le boss wave.
- Ondate: `game/modes/shared/wave_manager.gd` contiene stato wave, scaling, reward, composizione roster e spawn attuale da `spawn_points`.
- Spawn nemici: `game/enemies/enemy_system.gd` e il punto unico di creazione nemici; `WaveManager` decide oggi posizione e `enemy_id`.
- Nemici: `game/enemies/basic_enemy.gd`, `ranged_enemy.gd` e scene runner/tank/shooter riusano health, targeting, scaling e drop.
- Terreno/arena: `game/environment/survival_arena_manager.gd`, `survival_arena_profile.gd`, `biome_palette.gd` e `game/main/isometric_playground.gd` gestiscono palette, layout visuale, gate e props non bloccanti.
- Camera: `game/camera/isometric_camera_controller.gd` segue il gruppo `players` ed e la sorgente naturale per calcolare il rettangolo visibile.
- Collisioni/HP: player e nemici usano `CharacterBody2D`/`Area2D`; danni e cure passano da `game/health/health_system.gd` e `health_component.gd`.
- Loot/casse: `game/drops/supply_crate.gd`, `supply_crate_loot.tres`, `drop_system.gd` e `SurvivalAmmoDirector` sono gia riusabili per risorse ambientali.

## Strategia tecnica

Il revamp non deve sostituire in blocco la survival esistente. I nuovi sistemi verranno introdotti come componenti zombie dedicati che delegano ai controller gia stabili:

- `ZombieModeController`: ponte tra `SurvivalMode`, bioma corrente e lifecycle della run.
- `BiomeManager` + `BiomeDefinition`: punto unico per bioma iniziale, definizioni dati e query del bioma corrente.
- `WaveDirector`: composizione wave basata sul bioma, mantenendo reward/scaling nel `WaveManager`.
- `ZombieSpawner`: scelta spawn da bordo camera con fallback sui punti arena esistenti.
- `TerrainGenerator`, `ObstacleSystem`, `ResourceCrateSystem`, `HazardSystem`: sistemi ambientali incrementali, inizialmente conservativi.

## Milestone incrementali

1. Fondamenta modulari. Completata.
   - Aggiungere i sistemi dedicati e collegarli alla scena principale.
   - Spostare selezione enemy roster e spawn position dietro `WaveDirector` e `ZombieSpawner`.
   - Garantire che la run parta sempre dalla `Pianura Infetta`.
   - Verifica: survival smoke test e caricamento scena principale.

2. Spawn dai bordi camera. Completata.
   - Calcolare il rettangolo visibile dalla camera corrente.
   - Generare posizioni fuori dal bordo con margine, distanza minima dai player e fallback sicuro.
   - Mantenere compatibilita con test e profili arena esistenti.
   - Verifica: nuovo smoke test dedicato allo spawner.

3. Biomi dati e wave contestuali. Completata.
   - Definire Pianura Infetta, Tossico, Infuocato, Neve e Palude.
   - Collegare `WaveDirector` a pesi, moltiplicatori e regole per bioma.
   - Verifica: test che conferma bioma iniziale e roster base nella prima wave.

4. Terreno base, casse e ostacoli. Completata.
   - Aggiungere una risorsa `BiomeEnvironmentLayout` con placement
     deterministici per patch terreno, ostacoli e casse.
   - Generare decorazioni non collidenti tramite `TerrainGenerator`.
   - Generare rocce, recinti, barriere, un rudere e confini parziali tramite
     `ObstacleSystem`, usando `StaticBody2D` sul layer fisico condiviso.
   - Riutilizzare `SupplyCrate` e `DropSystem` per casse comuni e mediche
     gestite da `ResourceCrateSystem`.
   - Conservare corridoi centrali larghi e validare ogni cassa contro ostacoli
     e hazard per non bloccare il pathing.
   - Verifica: `tests/zombie_environment_milestone_smoke_test.gd`, regressione
     survival e caricamento della scena principale.

5. Zone caduta e danno ambientale. Completata.
   - Generare `BiomeFallZone` dal layout data-driven del bioma.
   - Salvare periodicamente l'ultima posizione sicura per ogni player.
   - Applicare esattamente 20 HP tramite `HealthSystem`, respawn alla posizione
     sicura e invulnerabilita dedicata di 1,25 secondi.
   - Conservare eventuali altre sorgenti di invulnerabilita attive.
   - Escludere le fall zone dagli spawn zombie e dalle posizioni sicure.
   - Generare feedback visuale, camera shake e cue audio ambientale.
   - Verifica: smoke test hazard, regressioni survival/RPG e QA visuale.

6. Espansione biomi e transizioni. Completata.
   - `BiomeTransitionSystem` collega in sequenza i cinque biomi.
   - Ogni area conserva gate attraversabili e almeno un confine fisico.
   - Il cambio bioma rigenera sistemi ambientali e influenza le wave successive.

7. Loot, ostacoli e hazard avanzati. Completata.
   - Quattro layout avanzati generano terreno, casse e blocker dedicati.
   - `HazardSystem` gestisce tossico, fuoco, gelo, acqua e fango.
   - Le casse tematiche espongono loot tag e visuali coerenti.

8. Zombie specifici per bioma. Completata.
   - Undici `BiomeEnemyProfile` riusano `BasicEnemy`.
   - Status al contatto, resistenze, emersione e hazard alla morte sono dati.
   - Ogni bioma avanzato dispone di almeno due varianti tematiche.

9. HUD, audio e feedback. Completata.
   - HUD con nome, icona compatta, pericoli, risorse e status.
   - Annunci e cue per transizione e danno ambientale.
   - QA visuale dei cinque biomi a 1280x720.

10. Bilanciamento e test. Completata.
   - Scaling per wave, party, tempo e distanza dal bioma iniziale.
   - Smoke test di dieci wave e soak da dieci minuti simulati.
   - Regressioni combat, drop, survival, boss, varianti, ranged, arena e RPG.

## Regole di sicurezza

- Ogni milestone deve lasciare avviabile `res://game/main/main.tscn`.
- Ogni commit deve contenere una sola milestone funzionale.
- Non rimuovere arena profile, gate, ammo director o varianti zombie esistenti: vanno adattati.
- Le modifiche a input, health, combat e player controller richiedono smoke test della survival.

## Verifiche completate

- Z1: `godot --headless --path . --script res://tests/zombie_revamp_foundation_smoke_test.gd`
- Z1 regressione: `godot --headless --path . --script res://tests/survival_wave_smoke_test.gd`
- Z1 regressione arena: `godot --headless --path . --script res://tests/milestone_20_arena_environment_smoke_test.gd`
- Z2: `godot --headless --path . --script res://tests/zombie_spawner_edge_smoke_test.gd`
- Z2 regressione: `godot --headless --path . --script res://tests/zombie_revamp_foundation_smoke_test.gd`
- Z2 regressione survival: `godot --headless --path . --script res://tests/survival_wave_smoke_test.gd`
- Z3: `godot --headless --path . --script res://tests/zombie_biome_wave_director_smoke_test.gd`
- Z4: `godot --headless --path . --script res://tests/zombie_environment_milestone_smoke_test.gd`
- Z4 regressione spawn: `godot --headless --path . --script res://tests/zombie_spawner_edge_smoke_test.gd`
- Z4 regressione survival: `godot --headless --path . --script res://tests/survival_wave_smoke_test.gd`
- Z4 regressione arena: `godot --headless --path . --script res://tests/milestone_20_arena_environment_smoke_test.gd`
- Z4 QA: `godot --path . --rendering-method gl_compatibility --script res://tests/arena_variants_visual_qa.gd`
- Z5: `godot --headless --path . --script res://tests/zombie_fall_hazard_smoke_test.gd`
- Z5 regressione foundation: `godot --headless --path . --script res://tests/zombie_revamp_foundation_smoke_test.gd`
- Z5 regressione survival: `godot --headless --path . --script res://tests/survival_wave_smoke_test.gd`
- Z5 regressione RPG: `godot --headless --path . --script res://tests/milestone_rpg_8_adrenaline_super_smoke_test.gd`
- Z5 QA: `godot --path . --rendering-method gl_compatibility --script res://tests/arena_variants_visual_qa.gd`
- Z6-Z10 transizioni/layout: `godot --headless --path . --script res://tests/zombie_biome_transition_smoke_test.gd`
- Z9 nemici/hazard: `godot --headless --path . --script res://tests/zombie_biome_enemy_smoke_test.gd`
- Z12 dieci wave: `godot --headless --path . --script res://tests/zombie_revamp_ten_wave_smoke_test.gd`
- Z12 soak dieci minuti: `godot --headless --path . --script res://tests/zombie_revamp_ten_minute_soak_test.gd`
- Z11 QA cinque biomi: `godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/zombie_biome_visual_qa.gd`
