# Milestone 3 - Sparo, armi, danni e vita

## Stato

Completata come prototipo minimo.

## Deliverable

- `WeaponData` per statistiche arma configurabili.
- `Starter Pistol` con danno, fire rate e velocita proiettile.
- Caricatore, riserva munizioni e ricarica per-player.
- Input ricarica tastiera e joypad.
- Proiettili con collisione su target damageable.
- Danno inoltrato tramite `HealthSystem`.
- `HealthComponent` condiviso da player e bersagli.
- HUD per-player con vita e munizioni.
- Bersagli statici con barra vita nella scena principale.
- Smoke test headless con due player locali.

## Verifica automatica

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
```

Risultato atteso: `COMBAT_SMOKE_TEST: PASS`.

## Verifica manuale

1. Aprire il progetto in Godot 4.x.
2. Avviare `res://game/main/main.tscn`.
3. Mirare verso un bersaglio rosso e sparare.
4. Verificare riduzione di barra vita e munizioni nell'HUD.
5. Premere `R` o il pulsante joypad `X` e verificare la ricarica.
6. Attivare player 2 con `F2` o `Start` e verificare munizioni indipendenti.
7. Colpire quattro volte lo stesso bersaglio e verificarne la distruzione.

## Limiti noti

- I bersagli sono statici e servono solo alla verifica del combat.
- Non esistono ancora AI nemica, attacchi contro i player o drop.
- Non esistono ancora cambio arma, pickup munizioni o feedback audio.
- Le collisioni gameplay complete con nemici mobili saranno integrate nella Milestone 4.
