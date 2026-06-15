# Revamp Zombie - Milestone Z3

## Stato

Completata come verifica dati bioma e wave contestuali.

## Obiettivo

Assicurare che i biomi siano definiti come dati e che le ondate possano leggere
il bioma corrente per cambiare roster, ritmo e difficolta.

## Implementato

- Verifica automatica dei cinque biomi: Pianura Infetta, Tossico, Infuocato,
  Neve e Palude.
- Controlli su display name, palette, terreno, ostacoli, casse, zombie ammessi,
  risorse e difficolta.
- Test del bioma iniziale con prima wave a zombie base.
- Test del bioma tossico con aumento dimensione wave, ritmo spawn, scaling e
  risoluzione di uno zombie tematico.
- Test che `WaveManager` registra il bioma corrente e delega il roster a
  `WaveDirector`.

## Contratto

- `BiomeManager.get_current_biome_id()` espone il bioma corrente.
- `WaveDirector.configure_wave()` restituisce almeno bioma, totale regolare e
  moltiplicatore spawn.
- `WaveDirector.get_wave_scaling_multipliers()` fornisce moltiplicatori bioma
  separati dallo scaling per numero ondata.
- La `Pianura Infetta` conserva il roster legacy per non rompere il bilanciamento
  survival esistente.

## Verifica

```text
godot --headless --path . --script res://tests/zombie_biome_wave_director_smoke_test.gd
```

Nota: un primo lancio ha stampato `PASS` completo ma restituito exit code `1`;
il rilancio immediato e passato con exit code `0`, coerente con lo shutdown
headless intermittente gia tracciato.

## Prossimo step

Milestone Z4: generare terreno/casse/ostacoli nel bioma iniziale con
validazione delle posizioni e senza bloccare il pathing degli zombie.
