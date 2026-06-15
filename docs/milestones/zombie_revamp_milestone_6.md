# Revamp Zombie - Milestone Z6

## Stato

Completata: tutti i biomi sono attraversabili nella stessa run.

## Implementato

- `BiomeTransitionSystem` e `BiomeTransitionGate`.
- Percorso Pianura, Tossico, Infuocato, Neve e Palude con ritorno ovest.
- Rigenerazione atomica di terreno, ostacoli, casse, hazard e gate.
- Confini fisici dedicati in ogni layout.

## Verifica

`tests/zombie_biome_transition_smoke_test.gd`.
