# Weapon Visual Identity Roadmap

Roadmap operativa derivata da `prompt.md` per completare il pass visuale delle
armi del catalogo: drop a terra, arma equipaggiata, HUD, proiettili, slash,
hit/impact e VFX devono comunicare la stessa identita.

## Audit iniziale

Stato al 2026-06-19:

- Il catalogo delle 30 nuove armi vive in `game/weapons/weapon_catalog.gd` come
  spec inline: 10 `firearm`, 10 `melee`, 10 `elemental`.
- `WeaponData.visual_data` usa `WeaponVisualData`, ma il contratto attuale
  contiene soprattutto colori, dimensioni base, projectile scale, trail e
  muzzle.
- Le 30 armi del catalogo condividono solo tre visual generici:
  `FIREARM_VISUAL`, `MELEE_VISUAL` ed `ELEMENTAL_VISUAL`.
- `DropPickupVisual` disegna tutti i drop arma con la stessa icona generica,
  quindi il pickup non mostra l'arma reale.
- `PlayerVisual`, `WeaponIcon` e `Projectile` hanno `match profile_id` separati
  con forme procedurali per poche armi storiche/RPG, non per tutto il catalogo.
- `MeleeAttack` usa il colore del profilo visuale, ma gli slash sono ancora
  guidati quasi solo dalla geometria melee e da pochi `trail_style`.
- `GameplayEffects` genera hit/impact generici; solo alcuni casi RPG cambiano
  size/shake per ID specifico.
- Esistono regressioni utili: `weapon_inventory_catalog_smoke_test.gd`,
  `milestone_13_weapon_tower_visual_smoke_test.gd` e `weapon_tower_visual_qa.gd`,
  ma non coprono pickup reali o identita distinta delle 30 armi.

File principali coinvolti:

- Dati arma: `game/weapons/weapon_data.gd`, `weapon_visual_data.gd`,
  `weapon_catalog.gd`, `.tres` storici in `game/weapons/`.
- Rendering in mano/HUD: `game/visuals/player_visual.gd`,
  `game/ui/weapon_icon.gd`, `game/ui/player_hud_card.gd`.
- Pickup: `game/drops/drop_pickup.gd`, `game/visuals/drop_pickup_visual.gd`,
  `game/drops/drop_system.gd`.
- Proiettili e impatti: `game/projectiles/projectile.gd`,
  `game/projectiles/projectile_system.gd`, `game/visuals/gameplay_effects.gd`,
  `game/visuals/gameplay_effect.gd`.
- Melee: `game/weapons/melee_attack.gd`, `game/weapons/weapon_system.gd`,
  `game/weapons/weapon_effect_resolver.gd`.
- Test/QA: `tests/weapon_inventory_catalog_smoke_test.gd`,
  `tests/milestone_13_weapon_tower_visual_smoke_test.gd`,
  `tests/weapon_tower_visual_qa.gd`, nuova copertura dedicata.

## Principi di implementazione

- Un solo contratto visuale per arma: pickup, held, HUD, projectile/melee e
  impact leggono la stessa `WeaponVisualData` o un suo successore compatibile.
- Le armi non devono distinguersi solo per colore: ogni `weapon_id` deve avere
  silhouette/profilo forma diverso o chiaramente riconoscibile nella famiglia.
- Il pass puo restare procedurale/SVG interno: nessun asset esterno obbligatorio.
  Gli sprite path devono essere opzionali e avere fallback esplicito.
- Evitare match sparsi duplicati: estrarre un renderer/helper condiviso per
  profili arma, poi farlo usare da pickup, HUD e player visual.
- Il colore slot player resta separato dall'identita dell'arma.
- Le modifiche gameplay devono essere nulle o minime: questo e un pass
  presentazionale, salvo piccoli campi dati necessari al renderer.

## Milestone W0 - Baseline e inventario visuale

Stato: completata.

Obiettivo:

- Trasformare `prompt.md` in una checklist tecnica verificabile.
- Censire ogni arma esistente e lo stato visuale attuale.
- Decidere quali visual storici vanno preservati come reference.

Attivita:

- Generare una tabella `weapon_id -> categoria -> comportamento -> visuale
  attuale -> gap`.
- Verificare quali armi sono `.tres` storiche e quali arrivano dal catalogo
  inline.
- Identificare profili gia buoni da mantenere: `starter_pistol`,
  `prototype_blaster`, `wave_cannon`, `rift_repeater`, armi RPG starter,
  torre e boss projectile.
- Aggiornare/creare una checklist manuale dedicata in `docs/testing/` con
  drop, held, projectile, melee, elemental e crowded-scene checks.

Implementato:

- Inventario visuale delle 30 armi inline del catalogo.
- Separazione tra armi catalogo, risorse `.tres` storiche e profili projectile
  di boss/torre/nemici.
- Identificazione dei tre profili generici attualmente riusati dal catalogo:
  `prototype_blaster_visual.tres` per firearm, `rpg_sword_visual.tres` per
  melee e `wave_cannon_visual.tres` per elemental.
- Conferma dei punti runtime che dovranno convergere sulla W1-W6:
  `DropPickupVisual`, `PlayerVisual`, `WeaponIcon`, `Projectile`,
  `MeleeAttack` e `GameplayEffects`.
- Aggiunta checklist manuale dedicata in
  `docs/testing/weapon_visual_identity_checklist.md`.

### Inventario catalogo W0

| Weapon ID | Categoria | Comportamento | Visuale attuale | Gap visuale |
| --- | --- | --- | --- | --- |
| `heavy_revolver` | firearm | Colpo lento, alto danno, knockback | `prototype_blaster` generico | Serve revolver corto con tamburo, bullet pesante e flash compatto. |
| `unstable_smg` | firearm | Fuoco rapidissimo con scatter | `prototype_blaster` generico | Serve corpo SMG, caricatore lungo e spray sottile. |
| `pump_shotgun` | firearm | 7 pallettoni in cono corto | `prototype_blaster` generico | Serve canna larga, pump e pellet/flash ampio. |
| `tactical_carbine` | firearm | Rifle medio preciso con critico | `prototype_blaster` generico | Serve carbine con stock, canna lunga e colpo pulito. |
| `improvised_sniper` | firearm | Piercing lungo raggio | `prototype_blaster` generico | Serve sniper lungo con scope e slug perforante. |
| `grenade_launcher` | firearm | Granata ad arco con AoE | `prototype_blaster` generico | Serve tubo grosso, granata rotonda e explosion identity. |
| `sawed_off_double` | firearm | Doppio burst shotgun corto | `prototype_blaster` generico | Serve doppia canna corta e due scariche leggibili. |
| `burst_pistol` | firearm | Raffica da 3 colpi | `prototype_blaster` generico | Serve pistola compatta con segni di burst. |
| `rusty_minigun` | firearm | Spin-up e fuoco molto rapido | `prototype_blaster` generico | Serve rotore multiplo, corpo pesante e muzzle ripetuto. |
| `scrap_railgun` | firearm | Charge, altissimo danno, piercing | `prototype_blaster` generico | Serve binario con bobine e beam/slug caricato. |
| `quick_knife` | melee | Stab corto rapidissimo | `rpg_sword` generico | Serve lama corta e slash/stab sottile. |
| `machete` | melee | Arco frontale medio | `rpg_sword` generico | Serve lama curva e cleave bilanciato. |
| `heavy_axe` | melee | Cleave lento, pesante, knockback | `rpg_sword` generico | Serve testa ascia larga e trail pesante. |
| `greatsword` | melee | Sweep enorme multi-hit | `rpg_sword` generico | Serve lama oversize e sweep a cuneo. |
| `demolition_hammer` | melee | Colpo pesante con stun | `rpg_sword` generico | Serve testa contundente e shockwave corta. |
| `spear` | melee | Affondo lineare lungo | `rpg_sword` generico | Serve asta lunga e thrust stretto. |
| `ruined_katana` | melee | Dash slash rapido | `rpg_sword` generico | Serve lama sottile e taglio pulito. |
| `spiked_mace` | melee | Impatto con bleed | `rpg_sword` generico | Serve mazza chiodata e hit spike/bleed. |
| `scythe` | melee | Arco larghissimo | `rpg_sword` generico | Serve mezzaluna ampia e crescent slash. |
| `offensive_shield` | melee | Bash corto con knockback | `rpg_sword` generico | Serve sagoma scudo e impatto difensivo. |
| `fire_wand` | elemental | Dardo burn | `wave_cannon` generico | Serve bacchetta/gemma fuoco e projectile caldo. |
| `fireball` | elemental | Sfera lenta con explosion/burn | `wave_cannon` generico | Serve fireball rotonda e AoE incendiaria. |
| `ice_lance` | elemental | Shard piercing con slow/freeze | `wave_cannon` generico | Serve lancia/cristallo azzurro penetrante. |
| `frost_nova` | elemental | Nova corta AoE freeze | `wave_cannon` generico | Serve burst radiale freddo vicino al player. |
| `chain_lightning` | elemental | Chain verso bersagli vicini | `wave_cannon` generico | Serve bolt elettrico e archi chain. |
| `arcane_taser` | elemental | Stun corto a bersaglio singolo | `wave_cannon` generico | Serve taser/focus corto con arco elettrico. |
| `acid_flask` | elemental | Ampolla con ground hazard poison | `wave_cannon` generico | Serve flask liquida, splash e pozza acida. |
| `toxic_spores` | elemental | Nube poison persistente | `wave_cannon` generico | Serve sacchetto/spore e particelle tossiche. |
| `seismic_crystal` | elemental | Onda d'urto AoE con knockback | `wave_cannon` generico | Serve cristallo pesante e shockwave/frammenti. |
| `unstable_void` | elemental | Implosione ritardata pull/AoE | `wave_cannon` generico | Serve orb scura, nucleo viola e implosione. |

### Reference preservate

- Armi `.tres` storiche con profilo proprio: `starter_pistol`,
  `prototype_blaster`, `wave_cannon`, `rift_repeater`.
- Armi RPG con profilo proprio: `rpg_bow`, `rpg_pistol`, `rpg_axe`,
  `rpg_sword`, `rpg_staff`, `rpg_slingshot`, `rpg_claws`.
- Profili non-player da non confondere con il catalogo drop:
  `defense_tower`, `enemy_shooter`, `boss_aimed`, `boss_radial`,
  `rift_lane`, `rift_cross`.
Sono reference di compatibilita per W1: il nuovo contratto deve mantenere
questi profili leggibili senza richiedere migrazione immediata.

Criterio di accettazione:

- Tutte le armi hanno uno stato visuale tracciato.
- La roadmap puo essere implementata senza scoprire nuovi scope nascosti nel
  mezzo del pass.

Test richiesto:

- Nessun test gameplay obbligatorio.
- Eseguito `rg "WeaponCatalog" game tests` per confermare entry point:
  `game/drops/drop_system.gd`, `game/weapons/weapon_catalog.gd` e
  `tests/weapon_inventory_catalog_smoke_test.gd`.

## Milestone W1 - Contratto visuale condiviso per arma

Stato: completata.

Obiettivo:

- Estendere il contratto visuale senza rompere i consumatori attuali.
- Preparare un renderer condiviso per silhouette procedurali o sprite opzionali.

Attivita:

- Estendere `WeaponVisualData` con campi opzionali:
  `held_shape_id`, `pickup_shape_id`, `hud_shape_id`, `projectile_shape_id`,
  `slash_shape_id`, `impact_shape_id`, `muzzle_shape_id`, `rarity_glow`,
  `family_id`, `outline_color`, `pickup_scale`, `held_scale`.
- Aggiungere campi asset opzionali, senza renderli obbligatori:
  `pickup_sprite_path`, `held_sprite_path`, `projectile_sprite_path`,
  `slash_sprite_path`, `impact_vfx_id`.
- Introdurre un helper condiviso, per esempio
  `game/weapons/weapon_visual_renderer.gd`, che riceve `WeaponVisualData`,
  una destinazione (`pickup`, `held`, `hud`, `projectile`, `slash`) e restituisce
  poligoni/colori/dimensioni o disegna su canvas.
- Mantenere compatibilita con i profili esistenti: se i nuovi campi sono vuoti,
  il renderer usa `profile_id` e i valori legacy.

Implementato:

- `WeaponVisualData` espone i nuovi ID opzionali per famiglia, target visuale,
  outline, glow, scale e percorsi sprite senza rendere obbligatori asset esterni.
- `WeaponVisualRenderer` centralizza fallback, lookup per target e poligoni
  proiettile legacy, mantenendo `profile_id` come compatibilita.
- `Projectile` delega silhouette e glow al renderer condiviso e non contiene
  piu match locali sui profili arma.

Criterio di accettazione:

- `WeaponData.visual_data` resta la fonte di verita.
- I consumer esistenti compilano senza cambiare comportamento per le armi
  storiche.
- Non esistono nuovi valori visuali hardcoded nei controller gameplay.

Test richiesto:

```text
godot --headless --path . --script res://tests/milestone_13_weapon_tower_visual_smoke_test.gd
godot --headless --path . --script res://tests/weapon_inventory_catalog_smoke_test.gd
```

Verifica eseguita:

- Eseguito `godot --headless --editor --quit --path .` per rigenerare la cache
  classi Godot richiesta dagli smoke headless.
- `milestone_13_weapon_tower_visual_smoke_test.gd`: PASS.
- `weapon_inventory_catalog_smoke_test.gd`: PASS.

## Milestone W2 - Pickup arma riconoscibile a terra

Stato: completata.

Obiettivo:

- Sostituire l'icona generica dei drop arma con la silhouette reale dell'arma.

Attivita:

- Far passare a `DropPickupVisual` il `WeaponData` o almeno il
  `WeaponVisualData` quando `drop_data.type == DROP_WEAPON`.
- Disegnare ombra, bobbing, outline/highlight e forma dell'arma con lo stesso
  profilo usato in mano.
- Mantenere icone attuali per XP, money, ammo e health.
- Gestire fallback esplicito: se un drop arma non ha profilo, usare un visual
  "missing weapon visual" evidente nei test, non un placeholder silenzioso.
- Aggiungere controllo high contrast/reduced motion anche sul nuovo visual.

Implementato:

- `WeaponCatalog` clona il profilo visuale di categoria per ogni arma catalogo
  e assegna `pickup_shape_id` stabile uguale a `weapon_id`, mantenendo i
  profili projectile legacy.
- `DropPickup` passa `WeaponData.visual_data` a `DropPickupVisual` per i drop
  arma; XP, money, ammo e health conservano le icone esistenti.
- `DropPickupVisual` usa `WeaponVisualRenderer` per silhouette, linee di
  dettaglio, outline, glow rarita e fallback `missing_weapon_visual`.
- Aggiunto `tests/weapon_pickup_visual_identity_smoke_test.gd` con i sette
  pickup richiesti e controllo high contrast/reduced motion.

Criterio di accettazione:

- Due armi diverse a terra sono distinguibili per silhouette e non solo colore.
- Nessun pickup arma gia implementato usa l'icona generica.
- Rarity/glow non copre la forma dell'arma.

Test richiesto:

- Nuovo smoke, per esempio
  `tests/weapon_pickup_visual_identity_smoke_test.gd`, che istanzia almeno:
  `heavy_revolver`, `pump_shotgun`, `quick_knife`, `heavy_axe`,
  `fireball`, `ice_lance`, `chain_lightning`.
- QA screenshot con griglia di pickup arma:

```text
godot --path . --rendering-method gl_compatibility --script res://tests/weapon_visual_identity_qa.gd
```

Verifica eseguita:

- `godot --headless --path . --script res://tests/weapon_pickup_visual_identity_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/weapon_inventory_catalog_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/milestone_13_weapon_tower_visual_smoke_test.gd`: PASS.
- `godot --rendering-method gl_compatibility --path . --script res://tests/weapon_visual_identity_qa.gd`: PASS,
  screenshot scritto in `build/qa/weapon_visual_identity_pickup_grid.png`.

## Milestone W3 - Held weapon e HUD allineati al pickup

Stato: completata.

Obiettivo:

- Far usare lo stesso linguaggio visuale a arma in mano, icona HUD e pickup.

Attivita:

- Portare `PlayerVisual._draw_weapon()` e `WeaponIcon._draw()` sul renderer
  condiviso.
- Aggiungere silhouette specifiche per famiglie:
  pistola/revolver, SMG, shotgun, carbine, sniper, launcher, minigun, railgun,
  coltello, machete, ascia, spadone, martello, lancia, katana, mazza, falce,
  scudo, focus arcani/cristalli/ampolle.
- Verificare che armi corte e pesanti cambino lunghezza, massa, impugnatura,
  canna/testa e dettagli iconici.
- Mantenere la separazione fra colore arma e colore slot.

Implementato:

- `WeaponCatalog` assegna `held_shape_id` e `hud_shape_id` stabili per ogni
  arma catalogo, oltre a dimensioni visuali specifiche per silhouette corte,
  lunghe, pesanti, melee ed elementali.
- `WeaponVisualRenderer` espone body/detail comuni per `held` e `hud`, con
  trasformazione orientata per l'arma in mano e fallback per le armi storiche.
- `PlayerVisual._draw_weapon()` e `WeaponIcon._draw()` leggono le geometrie dal
  renderer condiviso invece di mantenere `match profile_id` separati.
- Aggiunto `tests/weapon_held_hud_visual_identity_smoke_test.gd`.
- `tests/weapon_visual_identity_qa.gd` produce anche la griglia W3 held/HUD con
  12 armi rappresentative.

Criterio di accettazione:

- La stessa arma e riconoscibile come la stessa in pickup, mano e HUD.
- Due armi equipaggiate diverse si vedono diverse in mano al player anche a
  camera gameplay.
- Le armi storiche non regrediscono.

Test richiesto:

- Estendere `milestone_13_weapon_tower_visual_smoke_test.gd` oppure creare
  `weapon_held_hud_visual_identity_smoke_test.gd`.
- QA screenshot con player equipaggiati con almeno 12 armi rappresentative.

Verifica eseguita:

- `godot --headless --path . --script res://tests/weapon_held_hud_visual_identity_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/weapon_pickup_visual_identity_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/weapon_inventory_catalog_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/combat_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/milestone_13_weapon_tower_visual_smoke_test.gd`: PASS.
- `godot --rendering-method gl_compatibility --path . --script res://tests/weapon_visual_identity_qa.gd`: PASS,
  screenshot scritti in `build/qa/weapon_visual_identity_pickup_grid.png` e
  `build/qa/weapon_visual_identity_held_hud_grid.png`.

## Milestone W4 - Proiettili, muzzle e impact temizzati

Stato: completata.

Obiettivo:

- Rendere proiettili e impatti coerenti con ogni arma da fuoco/elementale.

Attivita:

- Portare `Projectile._projectile_polygon()` sul renderer condiviso o su una
  tabella dati dedicata.
- Aggiungere profili projectile distinti per:
  bullet pesante, spray SMG, pellet shotgun, round carbine, slug sniper,
  granata ad arco, doppietta, burst pistol, minigun stream, rail beam,
  dardo fuoco, fireball, ice lance, frost nova, lightning bolt, taser arc,
  acid flask, spore cloud, seismic pulse, void orb.
- Far leggere a `GameplayEffects._on_projectile_impacted()` colore, size,
  shape e shake dal profilo visuale o da `impact_shape_id`.
- Collegare muzzle flash coerente: shotgun ampio, revolver compatto, minigun
  ripetuto/rotore, railgun caricato, elemental glow/rune.
- Per AOE/ground hazard, assicurare che `WeaponEffectResolver` e
  `GameplayEffects` generino forme elementali leggibili.

Implementato:

- `WeaponCatalog` assegna alle armi firearm/elemental del catalogo
  `projectile_shape_id`, `muzzle_shape_id`, `impact_shape_id`,
  `impact_vfx_id`, palette projectile, trail, scale e muzzle size specifici
  senza cambiare statistiche, collisioni o timing.
- `WeaponVisualRenderer` contiene i profili projectile distinti per le 20 armi
  ranged del catalogo e helper condivisi per muzzle kind, impact kind, colore,
  size e shake.
- `Projectile` espone getter presentazionali per muzzle/impact e continua a
  delegare poligono/glow al renderer condiviso.
- `GameplayEffects` legge muzzle e impact dal proiettile invece di usare sempre
  `muzzle`/`hit` generici; `GameplayEffect` disegna varianti ballistic,
  explosive, fire, ice, lightning, toxic, seismic, void e rail.
- `WeaponEffectResolver.GroundHazardRuntime` differenzia il disegno di ampolla
  acida e spore tossiche mantenendo invariata l'applicazione dello status
  poison.
- Aggiunto `tests/weapon_projectile_vfx_identity_smoke_test.gd`.

Criterio di accettazione:

- I proiettili di armi diverse non sembrano tutti lo stesso triangolo colorato.
- Gli effetti elementali comunicano elemento e comportamento: fuoco, ghiaccio,
  fulmine, veleno/acido, sismico, vuoto.
- Muzzle/impact non cambiano danno o timing.

Test richiesto:

- Nuovo smoke `weapon_projectile_vfx_identity_smoke_test.gd` con profili
  projectile non nulli e shape distinti.
- Regressioni:

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/weapon_inventory_catalog_smoke_test.gd
godot --headless --path . --script res://tests/milestone_21_visual_settings_performance_smoke_test.gd
```

Verifica eseguita:

- `godot --headless --path . --script res://tests/weapon_projectile_vfx_identity_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/combat_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/weapon_inventory_catalog_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/milestone_21_visual_settings_performance_smoke_test.gd`: PASS,
  profilo affollato a 16,40 ms medi su budget 35 ms.

## Milestone W5 - Melee slash e hit effect per arma

Stato: completata.

Obiettivo:

- Differenziare slash, sweep, dash, impatti pesanti e hit feedback melee.

Attivita:

- Estendere `MeleeAttack` per usare `slash_shape_id`, `impact_shape_id` e
  `trail_style` specifici invece di basarsi quasi solo su `attack_shape`.
- Creare profili:
  quick stab, machete cleave, heavy axe cleave, greatsword broad sweep,
  hammer shockwave, spear thrust, katana dash cut, mace spiked impact,
  scythe crescent, shield bash.
- In `GameplayEffects._on_melee_attack_hit()` sostituire eccezioni per pochi ID
  con dati visuali: size, color, shake, hit sparks, shockwave.
- Garantire che hitbox e visual siano coerenti ma ancora separati: cambiare lo
  slash non deve cambiare area di danno.

Implementato:

- `WeaponCatalog` assegna alle 10 armi melee `slash_shape_id`,
  `impact_shape_id`, `impact_vfx_id`, palette slash, glow e trail width
  specifici.
- `WeaponVisualRenderer` risolve slash style e hit feedback melee da
  `WeaponVisualData`, con fallback legacy per `rpg_axe`, `rpg_sword` e
  `rpg_claws`.
- `MeleeAttack` espone `get_slash_shape_id()` e `get_slash_style_id()` e usa
  lo slash style visuale per disegnare stab, thrust, cleave, broad sweep,
  hammer shockwave, katana dash cut, spiked impact, crescent scythe, shield
  bash e claw arc senza cambiare la collisione.
- `GameplayEffects._on_melee_attack_hit()` legge kind, colore, size e shake
  dal renderer invece di usare eccezioni hardcoded per pochi ID.
- `GameplayEffect` disegna hit effect melee dedicati per i profili W5.
- Aggiunto `tests/weapon_melee_visual_identity_smoke_test.gd`.

Criterio di accettazione:

- Coltello, martello, katana, falce e scudo hanno feedback chiaramente diversi.
- Gli slash non sembrano identici per tutte le melee.
- Knockback/hitstop esistenti restano bilanciamento, non sorgente del visual.

Test richiesto:

```text
godot --headless --path . --script res://tests/rpg_melee_attack_resolution_smoke_test.gd
godot --headless --path . --script res://tests/weapon_inventory_catalog_smoke_test.gd
```

- Nuovo smoke `weapon_melee_visual_identity_smoke_test.gd`.

Verifica eseguita:

- `godot --headless --path . --script res://tests/weapon_melee_visual_identity_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/rpg_melee_attack_resolution_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/weapon_inventory_catalog_smoke_test.gd`: PASS.

## Milestone W6 - Pass completo sulle 30 armi del catalogo

Stato: completata.

Obiettivo:

- Assegnare un profilo visuale unico a ogni arma introdotta nel catalogo.

Attivita comuni:

- Ogni spec in `WeaponCatalog` deve assegnare `visual_data` specifico, non il
  profilo generico di categoria.
- Preferire risorse `.tres` in `game/weapons/visuals/` o una factory dati
  piccola e leggibile, evitando un mega-file ingestibile.
- Ogni `profile_id` deve coincidere con il `weapon_id` salvo eccezioni storiche
  documentate.
- Ogni arma deve dichiarare famiglia, silhouette, palette, pickup/held/projectile
  o slash/impact.

Piano identita firearm:

| Weapon ID | Identita visuale richiesta |
| --- | --- |
| `heavy_revolver` | Revolver corto, tamburo grande, canna spessa, flash compatto, bullet pesante. |
| `unstable_smg` | Corpo piccolo, caricatore lungo, doppie linee di rinculo, spray/trail sottile. |
| `pump_shotgun` | Canna larga, pump visibile, flash ampio, pellet multipli corti. |
| `tactical_carbine` | Rifle medio pulito, stock e barrel lunghi, projectile preciso. |
| `improvised_sniper` | Silhouette lunga, scope, colpo stretto perforante. |
| `grenade_launcher` | Tubo grosso, granata rotonda ad arco, esplosione riconoscibile. |
| `sawed_off_double` | Due canne corte parallele, doppio burst ravvicinato. |
| `burst_pistol` | Pistola compatta con tre tacche/flash a raffica. |
| `rusty_minigun` | Corpo pesante, rotore multiplo, stream rapido e muzzle ripetuto. |
| `scrap_railgun` | Binario lungo con bobine, carica luminosa, beam/slug perforante. |

Piano identita melee:

| Weapon ID | Identita visuale richiesta |
| --- | --- |
| `quick_knife` | Lama corta, stab sottile e rapido. |
| `machete` | Lama curva media, cleave frontale leggibile. |
| `heavy_axe` | Testa larga asimmetrica, trail pesante e knockback visuale. |
| `greatsword` | Lama enorme, sweep ampio a cuneo. |
| `demolition_hammer` | Testa contundente massiccia, shockwave corta. |
| `spear` | Asta lunga, affondo lineare stretto. |
| `ruined_katana` | Lama sottile, slash pulito e dash cut. |
| `spiked_mace` | Testa chiodata, hit spark/spike e bleed accent. |
| `scythe` | Lama a mezzaluna, arco larghissimo. |
| `offensive_shield` | Sagoma a scudo, bash rettangolare e impatto difensivo. |

Piano identita elemental:

| Weapon ID | Identita visuale richiesta |
| --- | --- |
| `fire_wand` | Bacchetta sottile con gemma rossa, dardo fuoco. |
| `fireball` | Focus caldo, sfera lenta e AoE incendiaria. |
| `ice_lance` | Cristallo/lancia azzurra, shard penetrante. |
| `frost_nova` | Focus circolare freddo, burst radiale vicino. |
| `chain_lightning` | Conduttore biforcato, bolt elettrico con chain arc. |
| `arcane_taser` | Taser/focus corto, arco elettrico ravvicinato. |
| `acid_flask` | Ampolla verde, parabola liquida e splash corrosivo. |
| `toxic_spores` | Sacchetto/nube organica, particelle/spore persistenti. |
| `seismic_crystal` | Cristallo pesante, onda d'urto con frammenti. |
| `unstable_void` | Focus scuro con nucleo viola, orb/implosione ritardata. |

Criterio di accettazione:

- Nessuna delle 30 armi usa il profilo generico di categoria.
- Ogni famiglia e riconoscibile a colpo d'occhio: metallo/canne per firearm,
  lame/aste/teste per melee, cristalli/rune/energia per elemental.
- Le differenze sono leggibili in gameplay affollato e a dimensioni piccole.

Implementato:

- `WeaponCatalog._make_visual_data()` assegna `profile_id = weapon_id` per ogni
  arma del catalogo, eliminando la dipendenza dal profilo generico di categoria.
- Aggiunto `weapon_catalog_visual_palette.gd`, tabella dati compatta separata
  dal catalogo con palette distinte per tutte le 30 armi: toni metallo/polimero
  per firearm, toni lama/materiale per melee, toni cristallo/energia/organico
  per elemental.
- Il contratto visuale `WeaponVisualData` è ora completamente weapon-specific:
  `profile_id`, `primary_color`, `secondary_color`, `glow_color`,
  `pickup_shape_id`, `held_shape_id`, `hud_shape_id` e i campi pertinenti tra
  `projectile_shape_id`/`slash_shape_id`, `impact_shape_id` e
  `muzzle_shape_id` coincidono col `weapon_id`.
- Aggiunto `tests/weapon_visual_catalog_smoke_test.gd` con 30 armi verificate
  per profilo unico, silhouette pickup/held/HUD distinte, palette esplicita e
  non generica e shape projectile/slash risolte.
- Aggiornate le asserzioni in `weapon_pickup_visual_identity_smoke_test.gd` e
  `weapon_held_hud_visual_identity_smoke_test.gd`: la verifica "stesso colore
  ma silhouette diversa" è stata aggiornata a "colore e silhouette entrambi
  distinti", riflettendo la garanzia palette W6.

Test richiesto:

```text
godot --headless --path . --script res://tests/weapon_visual_catalog_smoke_test.gd
godot --headless --path . --script res://tests/weapon_inventory_catalog_smoke_test.gd
```

Verifica eseguita:

- `godot --headless --path . --script res://tests/weapon_visual_catalog_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/weapon_inventory_catalog_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/weapon_pickup_visual_identity_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/weapon_held_hud_visual_identity_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/weapon_projectile_vfx_identity_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/weapon_melee_visual_identity_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/combat_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd`: PASS.
- `godot --headless --path . --script res://tests/milestone_13_weapon_tower_visual_smoke_test.gd`: PASS.

## Milestone W7 - QA visuale e regressioni end-to-end

Stato: completata.

Obiettivo:

- Dimostrare che il pass e leggibile davvero in gioco, non solo nei dati.

Attivita:

- Estendere `tests/weapon_visual_identity_qa.gd`, nato in W2 con pickup grid,
  con tavole screenshot: player held grid, projectile/effect grid, melee slash
  grid, elemental impact grid.
- Aggiungere controlli pixel/screenshot minimi dove possibile: frame non vuoto,
  armi separate nello spazio, differenze colore/shape tra profili.
- Eseguire una scena survival con piu player e armi diverse, piu uno scenario
  con zombie per verificare leggibilita in confusione.
- Verificare preset visuali: default, reduced motion, high contrast.

Criterio di accettazione:

- I sei controlli del prompt sono verificati:
  drop distinguibili, held distinguibili, projectile diversi, melee diversi,
  elemental leggibili, nessun placeholder generico per weapon pickup.
- La suite prioritaria resta verde.
- Il costo visuale non rompe il budget gia monitorato da Milestone 21.

Implementato:

- Estesa `tests/weapon_visual_identity_qa.gd` con cinque tavole isolate:
  pickup, held/HUD, projectile+muzzle+impact, slash+hit melee e projectile+
  impact elemental.
- Aggiunti `weapon_visual_identity_qa_board.gd` per il layout dei campioni e
  `weapon_visual_identity_survival_qa.gd` per lo scenario survival con quattro
  player, otto zombie, sei pickup arma e cinque proiettili simultanei.
- Ogni tavola verifica salvataggio, frame non vuoto, presenza di pixel foreground,
  separazione spaziale dei campioni e un numero minimo di firme colore/forma
  distinte.
- Lo scenario survival produce screenshot per `default`, `reduced_motion` e
  `high_contrast`, verifica la propagazione dei preset a held weapon e pickup e
  controlla che i frame dei preset siano misurabilmente diversi.
- Ispezionate manualmente le otto immagini in `build/qa/`: i sei controlli W7
  risultano leggibili e il placeholder missing resta esplicito, non usato dalle
  armi valide.

Test richiesto:

```text
godot --headless --path . --script res://tests/weapon_visual_catalog_smoke_test.gd
godot --headless --path . --script res://tests/weapon_pickup_visual_identity_smoke_test.gd
godot --headless --path . --script res://tests/weapon_projectile_vfx_identity_smoke_test.gd
godot --headless --path . --script res://tests/weapon_melee_visual_identity_smoke_test.gd
godot --headless --path . --script res://tests/weapon_inventory_catalog_smoke_test.gd
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/milestone_13_weapon_tower_visual_smoke_test.gd
godot --headless --path . --script res://tests/milestone_21_visual_settings_performance_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/weapon_visual_identity_qa.gd
```

Verifica eseguita:

- Tutti i nove smoke/regressioni funzionali elencati sopra: PASS.
- `milestone_21_visual_settings_performance_smoke_test.gd`: PASS sul budget
  affollato da 35 ms.
- `weapon_visual_identity_qa.gd`: PASS con otto PNG generati e controlli pixel
  superati.
- QA manuale: pickup firearm/melee/elemental distinguibili; held e HUD coerenti;
  proiettili, slash e impatti elementali separati; scena survival leggibile nei
  tre preset.

Manual QA minimo:

- Due firearm a terra: revolver vs shotgun.
- Due melee a terra: knife vs hammer.
- Due elemental a terra: fireball vs ice lance.
- Due player con armi equipaggiate diverse nella stessa schermata.
- Tre proiettili diversi in volo nello stesso frame.
- Tre slash melee diversi nello stesso scenario debug.
- Un effetto fuoco, uno ghiaccio, uno fulmine, uno veleno/acido e uno vuoto.

## Milestone W8 - Documentazione e chiusura backlog

Stato: completata.

Obiettivo:

- Lasciare il sistema estensibile per future armi e chiudere il pass principale.

Attivita:

- Documentare il contratto visuale in `ARCHITECTURE.md` solo quando il codice
  introduce il nuovo renderer/helper condiviso.
- Aggiornare `GAME_DESIGN.md` con identita visuale delle 30 armi quando le
  identita sono implementate.
- Aggiornare `README.md` solo se cambiano test o comandi consigliati.
- Aggiornare `TODO.md`, `CHANGELOG.md` e questa roadmap a ogni milestone chiusa.
- Salvare nel report di validazione screenshot, test eseguiti e debiti residui.

Criterio di accettazione:

- Il deliverable finale richiesto dal prompt e disponibile:
  codice implementato, file modificati, spiegazione sintetica del sistema,
  lista armi aggiornate, asset nuovi e TODO residui.
- I TODO residui non bloccano il pass principale: solo arte finale opzionale,
  tuning secondario o future armi.

Implementato:

- Consolidato in `ARCHITECTURE.md` il flusso `WeaponData.visual_data` verso
  pickup, held, HUD, projectile, effects e melee, inclusa la procedura per
  aggiungere armi future senza hardcode nei consumer.
- Aggiunta a `GAME_DESIGN.md` la lista delle 30 armi con una nota sintetica su
  silhouette, palette e linguaggio di attacco.
- Aggiornato `README.md` con sintesi WVIS, riferimenti normativi e comandi smoke
  e QA consigliati.
- Creato `docs/weapon_visual_identity_validation_report.md` con sistema,
  componenti coinvolti, lista armi, test, otto screenshot, asset e debiti
  residui non bloccanti.
- Spostato `WVIS-001` dal backlog aperto alle reference completate in `TODO.md`.

Verifica eseguita:

- Tutti i file runtime, i runner e i documenti del deliverable esistono nel
  repository; i percorsi futuri sono marcati come opzionali.
- `git diff --check`: PASS.
- W8 non modifica il runtime; eredita la suite W7 completa e la QA visuale PASS
  registrate nel report dedicato.

## Definition of done complessiva

Stato: soddisfatta il 2026-06-20.

- Tutte le 30 armi del catalogo hanno un profilo visuale unico.
- Pickup, held, HUD e projectile/melee leggono la stessa identita visuale.
- Le tre famiglie hanno linguaggi visivi distinti.
- Nessun drop arma usa un placeholder generico silenzioso.
- Le armi storiche e RPG non regrediscono.
- I nuovi test visual identity e le regressioni combat/drop/survival passano.
- La documentazione e il backlog riflettono lo stato reale.

## Rischi e decisioni

- Rischio file troppo grande: evitare di aggiungere altri `match` lunghi in
  `PlayerVisual`, `Projectile` o `WeaponIcon`; estrarre un helper condiviso.
- Rischio asset churn: usare prima profili procedurali/SVG interni, poi
  sostituire con asset finali tramite path opzionali.
- Rischio leggibilita finta: i test dati non bastano; servono screenshot e QA
  in scena affollata.
- Decisione consigliata: non convertire subito tutto il catalogo da inline a
  `.tres` se non serve al pass. Prima rendere data-driven la visual identity,
  poi valutare una migrazione dati separata.
