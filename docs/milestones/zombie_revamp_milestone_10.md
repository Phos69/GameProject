# Revamp Zombie - Milestone Z10

## Stato

Completata: hazard ambientali avanzati e transizioni contestuali.

## Implementato

- `BiomeHazardZone` per danno periodico e modifica movimento.
- `BiomeHazardCatalog` per configurazione e palette degli hazard.
- `BiomeStatusRuntime` per status temporanei, tick danno e modificatori movimento.
- Tossico, gas, fuoco, lava, ghiaccio, neve, acqua e fango.
- Hazard runtime generati dagli zombie speciali.
- Fall zone da 20 HP preservata come contratto separato.

## Verifica

`tests/zombie_biome_enemy_smoke_test.gd` e
`tests/zombie_fall_hazard_smoke_test.gd`.
