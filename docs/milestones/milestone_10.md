# Milestone 10 - Visual Readability Foundation

## Stato

Completata come primo pass visuale modulare.

## Obiettivo

Portare la zombie survival oltre il prototipo tecnico senza modificare i
contratti gameplay condivisi con dungeon e tower defense.

## Implementato

- arena survival pseudo-isometrica desaturata con piastrelle, usura, corsie,
  marker di bordo e barricate decorative;
- visuale survivor modulare con colore player, camminata, mira, sparo,
  ricarica, danno e morte;
- visuale zombie modulare con silhouette curva, braccia protese, camminata,
  attacco e reazione al colpo;
- pickup XP, denaro, ammo, cura e arma rappresentati da icone grafiche;
- supply crate grafica senza etichetta testuale;
- schede HUD per-player con colore slot, vita, arma e munizioni;
- effetti procedurali leggeri per sparo, impatto valido, morte nemico e
  raccolta pickup;
- bersagli combat debug nascosti e senza collisione durante il normale gameplay;
- smoke test visuale headless e cattura QA survival a 1280x720.

## Contratto tecnico

- `PlayerVisual`, `ZombieVisual`, `DropPickupVisual` e `SupplyCrateVisual`
  ricevono stato dai sistemi esistenti e non possiedono logica gameplay.
- `GameplayEffects` ascolta segnali pubblici di proiettili, nemici e drop.
- collisioni, danni, movimento, wave, loot e input non dipendono dai visual.
- i placeholder procedurali possono essere sostituiti da sprite o animazioni
  future mantenendo le stesse scene e API.

## Verifica automatica

```text
godot --headless --path . --script res://tests/milestone_10_visual_smoke_test.gd
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
godot --headless --path . --script res://tests/milestone_9_smoke_test.gd
```

QA visuale:

```text
godot --path . --rendering-method gl_compatibility --script res://tests/survival_visual_qa.gd
```

Output:

```text
build/qa/milestone_10_survival.png
```

## Checklist manuale

- Avviare Zombie Survival dal menu a 1280x720.
- Verificare che i bersagli debug rossi non siano visibili.
- Muovere e mirare con almeno due player e controllare che colori e sagome
  restino distinguibili.
- Sparare, ricaricare e subire danno per verificare le animazioni survivor.
- Osservare inseguimento, attacco e hit reaction degli zombie.
- Raccogliere almeno un pickup per tipo e riconoscerlo senza leggere testo.
- Aprire una supply crate e verificare che sia distinta dai pickup.
- Controllare vita, arma e munizioni nelle schede HUD di tutti i player.
- Verificare muzzle flash, hit flash, effetto morte e anello pickup.
- Passare a dungeon e tower defense, poi tornare alla survival.

## Fuori scope

- sprite definitivi e pipeline di import artistica;
- animazioni scheletriche o frame-by-frame;
- telegraph del boss e restyling completo del `Wave Warden`;
- identita grafica completa di torri, armi speciali e varianti nemico;
- illuminazione, shader e post-processing avanzati.
