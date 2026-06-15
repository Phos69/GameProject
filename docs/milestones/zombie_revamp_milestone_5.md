# Revamp Zombie - Milestone Z5

## Stato

Completata con una prima zona di caduta funzionante nella `Pianura Infetta`.

## Obiettivo

Introdurre danno ambientale recuperabile senza bloccare il player, interferire
con altre invulnerabilita o permettere spawn zombie dentro l'hazard.

## Implementato

- `BiomeEnvironmentLayout` descrive posizione, dimensione e rotazione hazard.
- `BiomeFallZone` fornisce collisione `Area2D`, query geometriche e visuale
  procedurale.
- `HazardSystem` genera le zone, registra le posizioni sicure e gestisce il
  lifecycle completo della caduta.
- Ogni caduta applica esattamente 20 HP tramite `HealthSystem`.
- Il player viene riportato all'ultima posizione sicura con velocita azzerata.
- Il recupero concede 1,25 secondi di invulnerabilita con sorgente nominata.
- Le altre sorgenti di invulnerabilita restano indipendenti.
- `ZombieSpawner` rifiuta la fall zone tramite la query hazard condivisa.
- `GameplayEffects` e `AudioEventRouter` presentano danno e respawn.

## Contratto

- Solo `HazardSystem` decide se una posizione e sicura e applica la caduta.
- Il danno che ignora l'invulnerabilita deve richiederlo esplicitamente a
  `HealthSystem`; il comportamento predefinito non cambia.
- Le protezioni temporanee usano un ID sorgente e vengono rimosse alla scadenza
  o allo stop della modalita.
- Il layout resta data-driven e non richiede asset esterni.

## Verifica

```text
godot --headless --path . --script res://tests/zombie_fall_hazard_smoke_test.gd
godot --headless --path . --script res://tests/zombie_revamp_foundation_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_8_adrenaline_super_smoke_test.gd
godot --headless --path . --script res://tests/milestone_16_downed_revive_smoke_test.gd
godot --headless --path . --script res://tests/milestone_18_audio_mix_smoke_test.gd
godot --headless --path . --script res://tests/milestone_20_arena_environment_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/arena_variants_visual_qa.gd
```

QA visuale verificata a 1280x720 su `Industrial Crossroads`: la fall zone e
leggibile, non copre HUD o player start e lascia libere le corsie principali.

## Prossimo step

Milestone Z6: rendere raggiungibile un secondo bioma, rilevare la transizione e
usare il nuovo bioma per terreno, risorse, ostacoli, hazard e wave successive.
