# Milestone 15 - Zombie Ranged e Pressione a Distanza

## Stato

Completata come primo pass gameplay e visuale.

## Obiettivo

Introdurre uno shooter leggibile che costringa il party a muoversi senza
duplicare health, drop, targeting o tracking delle wave.

## Implementato

- `RangedEnemy` con distanza preferita, ritirata e windup autoritativo;
- corsia world-space con countdown prima del colpo;
- direzione bloccata all'inizio del warning;
- proiettile ostile verde/ciano distinto dai pattern boss;
- silhouette alta con spine e nucleo tossico;
- scena, collisione e loot table dedicati;
- registrazione `survival_shooter` in `EnemySystem`;
- composizione deterministica dalla wave 4;
- smoke test e QA a quattro player.

## Statistiche

- 38 HP;
- velocita 78;
- distanza preferita 330;
- ritirata sotto 220;
- windup 0,85 secondi;
- proiettile da 11 danni a velocita 235;
- cooldown 2,2 secondi;
- 6 XP garantiti.

## Composizione survival

- wave 1: basic;
- wave 2: runner ogni terzo slot;
- wave 3: tank nell'ultimo slot pesante;
- dalla wave 4: shooter ogni quarto slot regolare;
- il tank mantiene priorita nell'ultimo slot.

Le boss wave con due scorte restano basic.

## Contratto tecnico

- `RangedEnemy` eredita `BasicEnemy` per target, health, scaling, morte e drop.
- Il controller sostituisce solo movimento e attacco.
- `EnemyShotTelegraphVisual` non possiede collisioni o danno.
- Nessun proiettile viene creato prima della fine del windup.
- `ProjectileSystem` resta l'unico punto di spawn del colpo.
- Dungeon e tower defense non cambiano roster.

## Verifica

```text
godot --headless --path . --script res://tests/milestone_15_ranged_enemy_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/ranged_enemy_visual_qa.gd
```

Output QA:

```text
build/qa/milestone_15_ranged_enemy.png
```

## Checklist manuale

- Raggiungere la wave 4 e riconoscere lo shooter senza testo.
- Verificare che mantenga distanza e arretri se avvicinato.
- Controllare che corsia e countdown precedano sempre il colpo.
- Cambiare posizione durante il warning e verificare la mira bloccata.
- Schivare il colpo entrando nello spazio fuori corsia.
- Verificare hit, morte, drop e conteggio wave.
- Ripetere con quattro player e HUD completo.
- Avviare dungeon e tower defense e verificare i roster invariati.
