# Weapon Visual Identity Checklist

Checklist manuale per il pass WVIS-001.

## Scope

- Validare le 30 armi del catalogo drop in `WeaponCatalog`.
- Separare le regressioni delle armi storiche/RPG/tower/boss dal pass sulle
  nuove armi.
- Verificare che pickup, held weapon, HUD, projectile/melee e impact comunichino
  la stessa identita visuale.

## Baseline W0

- Catalogo inline: `game/weapons/weapon_catalog.gd`.
- Profili generici attuali del catalogo:
  - firearm -> `prototype_blaster_visual.tres`;
  - melee -> `rpg_sword_visual.tres`;
  - elemental -> `wave_cannon_visual.tres`.
- Reference da preservare:
  `starter_pistol`, `prototype_blaster`, `wave_cannon`, `rift_repeater`,
  `rpg_bow`, `rpg_pistol`, `rpg_axe`, `rpg_sword`, `rpg_staff`,
  `rpg_slingshot`, `rpg_claws`, `defense_tower`, `enemy_shooter`,
  `boss_aimed`, `boss_radial`, `rift_lane`, `rift_cross`.

## Pickup

- W2 implementa `pickup_shape_id` per tutte le 30 armi catalogo e smoke
  `tests/weapon_pickup_visual_identity_smoke_test.gd`.
- Ogni pickup arma mostra la sagoma dell'arma, non l'icona weapon generica.
- Due firearm a terra sono distinguibili per forma: `heavy_revolver` e
  `pump_shotgun`.
- Due melee a terra sono distinguibili per forma: `quick_knife` e
  `demolition_hammer`.
- Due elemental a terra sono distinguibili per forma/energia: `fireball` e
  `ice_lance`.
- Outline, bobbing e glow non coprono la silhouette.
- Reduced motion ferma bob/pulse senza rendere il pickup illeggibile.
- High contrast mantiene il bordo leggibile senza annullare la famiglia arma.

## Held Weapon e HUD

- W3 implementa `held_shape_id` e `hud_shape_id` per tutte le 30 armi catalogo
  e smoke `tests/weapon_held_hud_visual_identity_smoke_test.gd`.
- La stessa arma e riconoscibile in mano e a terra.
- `WeaponIcon` usa lo stesso linguaggio visuale del player.
- Il colore slot del player resta separato dal colore dell'arma.
- Armi corte e pesanti hanno massa/lunghezza visibilmente diverse.
- Player con due armi diverse nella stessa schermata non sembrano equipaggiati
  con lo stesso oggetto ricolorato.

## Projectile e Impact

- W4 implementa profili projectile/muzzle/impact per firearm ed elemental e
  smoke `tests/weapon_projectile_vfx_identity_smoke_test.gd`.
- `heavy_revolver`, `unstable_smg`, `pump_shotgun`, `grenade_launcher`,
  `rusty_minigun` e `scrap_railgun` hanno projectile/muzzle distinguibili.
- `fire_wand`, `fireball`, `ice_lance`, `chain_lightning`, `acid_flask` e
  `unstable_void` comunicano il proprio elemento.
- Impact e muzzle usano colore/forma coerenti con l'arma.
- AOE, chain, ground hazard e delayed explosion sono leggibili senza cambiare
  danno o timing.

## Melee

- W5 implementa `slash_shape_id`, `impact_shape_id` e hit effect melee
  specifici per le 10 armi catalogo e smoke
  `tests/weapon_melee_visual_identity_smoke_test.gd`.
- `quick_knife` usa stab corto e sottile.
- `heavy_axe` e `greatsword` non condividono lo stesso sweep.
- `demolition_hammer` comunica impatto pesante e shockwave.
- `spear` comunica affondo lineare.
- `ruined_katana` comunica slash pulito/dash.
- `scythe` comunica arco largo a mezzaluna.
- `offensive_shield` comunica bash difensivo.
- Visual e hitbox restano coerenti ma separati: cambiare trail non cambia area
  di danno.

## Scene Affollate

- W7 verificata con quattro player equipaggiati con firearm, shotgun, melee ed
  elemental nello stesso scenario survival.
- Sei pickup arma restano separati sul background isometrico e il placeholder
  missing compare solo nel campione negativo dedicato.
- Cinque proiettili diversi restano leggibili nello stesso frame con otto zombie.
- La tavola melee mostra sei slash/hit profile distinti nello stesso scenario.
- Default, reduced motion e high contrast producono frame validi e raggiungono
  held weapon e pickup senza cambiare il gameplay.

## Comandi di Regressione Previsti

```text
godot --headless --path . --script res://tests/weapon_inventory_catalog_smoke_test.gd
godot --headless --path . --script res://tests/weapon_pickup_visual_identity_smoke_test.gd
godot --headless --path . --script res://tests/weapon_held_hud_visual_identity_smoke_test.gd
godot --headless --path . --script res://tests/weapon_projectile_vfx_identity_smoke_test.gd
godot --headless --path . --script res://tests/weapon_melee_visual_identity_smoke_test.gd
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/milestone_13_weapon_tower_visual_smoke_test.gd
godot --headless --path . --script res://tests/milestone_21_visual_settings_performance_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/weapon_visual_identity_qa.gd
```

## Evidenza Finale Richiesta

- Screenshot pickup grid.
- Screenshot held weapon grid.
- Screenshot projectile/effect grid.
- Screenshot melee slash grid.
- Screenshot elemental impact grid.
- Tre screenshot survival: default, reduced motion e high contrast.
- Note sui preset default, reduced motion e high contrast.
- Lista delle armi ancora da rifinire, se restano solo debiti opzionali.
