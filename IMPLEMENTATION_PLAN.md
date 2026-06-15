# IMPLEMENTATION_PLAN

## Revamp modalita zombie

Roadmap di riferimento: `roadmap_revamp_modalita_zombie.md`.

Stato corrente: Milestone Z3 completata con biomi dati e wave contestuali verificati.

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

4. Terreno base, casse e ostacoli.
   - Generare props fisici leggeri e casse nel bioma iniziale.
   - Evitare blocchi totali del pathing con posizioni deterministiche e validate.
   - Verifica: smoke test su spawn casse/ostacoli e avvio survival.

5. Zone caduta e danno ambientale.
   - Salvare ultima posizione sicura per player.
   - Applicare 20 HP, breve invulnerabilita e respawn alla posizione sicura.
   - Escludere le fall zone dagli spawn zombie.
   - Verifica: smoke test hazard e checklist manuale.

6. Espansione biomi e transizioni.
   - Aggiungere almeno un secondo bioma raggiungibile e confini bloccati/pericolosi.
   - Aggiornare HUD/feedback bioma.
   - Verifica: cambio bioma rilevato e wave successive modificate.

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
