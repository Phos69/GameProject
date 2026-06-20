# Weapon Visual Identity - Validation Report

Data: 2026-06-20

Scope: `WVIS-001`, Milestone W0-W8

Esito: PASS, pass principale completato

## Risultato

Tutte le 30 armi drop di `WeaponCatalog` hanno un `profile_id` uguale al
proprio `weapon_id`, una palette esplicita e ID visuali specifici per pickup,
held, HUD e projectile oppure slash/impact. Le tre famiglie mantengono linguaggi
distinti e nessuna arma valida usa il placeholder pickup generico.

La lista completa arma-per-arma e la relativa identita sono in
`GAME_DESIGN.md`, sezione `Catalogo visuale completo`.

## Sistema implementato

```text
WeaponData.visual_data
  -> WeaponVisualRenderer
     -> DropPickupVisual
     -> PlayerVisual / WeaponIcon
     -> Projectile / GameplayEffects
     -> MeleeAttack
```

- `WeaponVisualData` conserva profilo, famiglia, palette, scale, sprite path
  opzionali e ID target.
- `WeaponVisualRenderer` centralizza geometrie procedurali, fallback legacy e
  risoluzione di projectile, muzzle, impact e slash.
- `weapon_catalog_visual_palette.gd` separa i colori delle 30 armi dai dati di
  combat e fallisce esplicitamente in sviluppo se manca una palette.
- `DropPickupVisual`, `PlayerVisual`, `WeaponIcon`, `Projectile`,
  `GameplayEffects` e `MeleeAttack` consumano lo stesso profilo.
- Danno, hitbox, timing, status, knockback e ammo non dipendono dai dati visuali.

## File e sistemi del pass

Runtime principale:

- `game/weapons/weapon_visual_data.gd`
- `game/weapons/weapon_visual_renderer.gd`
- `game/weapons/weapon_catalog.gd`
- `game/weapons/weapon_catalog_visual_palette.gd`
- `game/weapons/melee_attack.gd`
- `game/weapons/weapon_effect_resolver.gd`
- `game/projectiles/projectile.gd`
- `game/drops/drop_pickup.gd`
- `game/visuals/drop_pickup_visual.gd`
- `game/visuals/player_visual.gd`
- `game/visuals/gameplay_effects.gd`
- `game/ui/weapon_icon.gd`

Validazione dedicata:

- `tests/weapon_visual_catalog_smoke_test.gd`
- `tests/weapon_pickup_visual_identity_smoke_test.gd`
- `tests/weapon_held_hud_visual_identity_smoke_test.gd`
- `tests/weapon_projectile_vfx_identity_smoke_test.gd`
- `tests/weapon_melee_visual_identity_smoke_test.gd`
- `tests/weapon_visual_identity_qa.gd`
- `tests/weapon_visual_identity_qa_board.gd`
- `tests/weapon_visual_identity_survival_qa.gd`

Documentazione aggiornata: `README.md`, `ROADMAP.md`, `TODO.md`,
`ARCHITECTURE.md`, `GAME_DESIGN.md`, `CHANGELOG.md`,
`weapon_visual_identity_roadmap.md` e
`docs/testing/weapon_visual_identity_checklist.md`.

## Armi aggiornate

- Firearm: `heavy_revolver`, `unstable_smg`, `pump_shotgun`,
  `tactical_carbine`, `improvised_sniper`, `grenade_launcher`,
  `sawed_off_double`, `burst_pistol`, `rusty_minigun`, `scrap_railgun`.
- Melee: `quick_knife`, `machete`, `heavy_axe`, `greatsword`,
  `demolition_hammer`, `spear`, `ruined_katana`, `spiked_mace`, `scythe`,
  `offensive_shield`.
- Elemental: `fire_wand`, `fireball`, `ice_lance`, `frost_nova`,
  `chain_lightning`, `arcane_taser`, `acid_flask`, `toxic_spores`,
  `seismic_crystal`, `unstable_void`.

Le note sintetiche su silhouette, palette e VFX di ogni ID sono mantenute in
`GAME_DESIGN.md` per evitare due fonti normative divergenti.

## Test eseguiti

| Test | Esito |
| --- | --- |
| `weapon_visual_catalog_smoke_test.gd` | PASS |
| `weapon_pickup_visual_identity_smoke_test.gd` | PASS |
| `weapon_held_hud_visual_identity_smoke_test.gd` | PASS |
| `weapon_projectile_vfx_identity_smoke_test.gd` | PASS |
| `weapon_melee_visual_identity_smoke_test.gd` | PASS |
| `weapon_inventory_catalog_smoke_test.gd` | PASS |
| `combat_smoke_test.gd` | PASS |
| `enemy_drop_smoke_test.gd` | PASS |
| `survival_wave_smoke_test.gd` | PASS |
| `milestone_13_weapon_tower_visual_smoke_test.gd` | PASS |
| `milestone_21_visual_settings_performance_smoke_test.gd` | PASS, sotto il budget di 35 ms |
| `weapon_visual_identity_qa.gd` | PASS |

Le regressioni legacy held/HUD, RPG melee, boss e torre restano coperte dagli
smoke dedicati. `git diff --check` non segnala errori whitespace.

## Evidenza visuale

La QA genera otto PNG locali in `build/qa/`:

- `weapon_visual_identity_pickup_grid.png`
- `weapon_visual_identity_held_hud_grid.png`
- `weapon_visual_identity_projectile_effect_grid.png`
- `weapon_visual_identity_melee_slash_grid.png`
- `weapon_visual_identity_elemental_impact_grid.png`
- `weapon_visual_identity_crowded_default.png`
- `weapon_visual_identity_crowded_reduced_motion.png`
- `weapon_visual_identity_crowded_high_contrast.png`

Le immagini sono output di build ignorati da Git. Sono state ispezionate a
1280x720: pickup e held sono coerenti, projectile/slash/impact sono distinti e
lo scenario con quattro player, otto zombie, sei pickup e cinque proiettili
resta leggibile nei tre preset.

## Asset nuovi

Non sono stati introdotti asset esterni obbligatori. Il pass usa geometrie
procedurali game-ready, palette dati e sprite path opzionali. Gli unici output
raster nuovi sono gli screenshot QA generati localmente; la sostituzione futura
con sprite finali non richiede modifiche al combat o ai consumer.

## Debiti residui non bloccanti

### Arte finale opzionale

- Obiettivo: sostituire selettivamente le geometrie procedurali con sprite o
  animazioni finali senza perdere l'identita validata.
- Milestone collegata: `UIUX-001` / pass asset futuro.
- File e sistemi: `assets/weapons/`, sprite path di `WeaponVisualData`,
  `WeaponVisualRenderer` solo per eventuali animation profile condivisi.
- Criterio di accettazione: stessa arma riconoscibile in pickup, held, HUD e
  attacco; nessun asset esterno obbligatorio per il prototipo minimo.
- Test richiesto: suite WVIS completa e rigenerazione degli otto screenshot QA.

### Tuning visuale secondario

- Obiettivo: rifinire scale, saturazione, glow e trail dopo playtest prolungati.
- Milestone collegata: `BAL-001`.
- File e sistemi: `weapon_catalog_visual_palette.gd`, `WeaponVisualData`,
  `WeaponVisualRenderer`, preset di `VisualSettingsManager`.
- Criterio di accettazione: nessuna sovrapposizione critica a 1280x720 e budget
  M21 ancora sotto 35 ms.
- Test richiesto: QA WVIS sui tre preset, survival multi-player e smoke M21.

Nuove armi future devono seguire la procedura descritta in `ARCHITECTURE.md` e
non riaprono `WVIS-001` salvo un nuovo goal esplicito.
