# Revamp Zombie - Milestone Z8

## Stato

Completata: le wave reagiscono al bioma e alla progressione della run.

## Implementato

- Roster pesati letti da `BiomeDefinition`.
- Moltiplicatori per bioma, wave, player vivi, tempo e profondita.
- Modificatore drop inoltrato ai nemici senza mutare le loot table.
- Cambio roster applicato dalla wave successiva alla transizione.

## Verifica

`tests/zombie_biome_wave_director_smoke_test.gd` e
`tests/zombie_revamp_ten_wave_smoke_test.gd`.
