# Revamp Zombie - Milestone Z2

## Stato

Completata come validazione dello spawn camera-edge.

## Obiettivo

Fare in modo che gli zombie possano spawnare fuori o appena oltre i bordi
della camera attuale invece che dipendere dai punti fissi arena.

## Implementato

- `ZombieSpawner` calcola il rettangolo visibile della camera corrente.
- Supporto configurabile per bordi nord, sud, est e ovest tramite pesi.
- Parametri esposti per margine, distanza minima dal player, tentativi, raggio
  gruppo, massimo per tick e ritardo fra gruppi.
- Validazione contro posizioni dentro camera, troppo vicine ai player, fall
  zone, spawn blocker e ostacoli ambientali.
- Fallback configurato dai profili arena esistenti.
- `ObstacleSystem` e `HazardSystem` supportano zone leggere `Node2D` con
  metadata `zone_radius` per i test e i prossimi generatori.

## Contratto

- `WaveManager` chiede la posizione reale a `ZombieSpawner`.
- I punti arena restano fallback e riferimento visuale per i gate.
- Lo spawner conserva `last_spawn_edge` per debug e test.
- Se non c'e camera valida, il fallback resta disponibile.

## Verifica

```text
godot --headless --path . --script res://tests/zombie_spawner_edge_smoke_test.gd
godot --headless --path . --script res://tests/zombie_revamp_foundation_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
```

Nota: il warning `ObjectDB instances leaked at exit` resta il problema headless
gia tracciato nel TODO manutentivo e non ha prodotto fallimenti funzionali.

## Prossimo step

Milestone Z3: rendere le ondate pienamente contestuali al bioma corrente e
preparare il primo cambio bioma senza duplicare `WaveManager`.
