# Milestone 13 - Identita Grafica di Armi e Torri

## Stato

Completata come primo pass visuale modulare.

## Obiettivo

Rendere arma attiva, proiettili e torre riconoscibili dalla silhouette e dal
colore senza duplicare weapon system, targeting, danno o logica HUD.

## Implementato

- `WeaponVisualData` come risorsa condivisa e sostituibile;
- profilo compatto arancio per `Starter Pistol`;
- profilo a doppia forcella ciano per `Prototype Blaster`;
- profilo pesante magenta per `Wave Cannon`;
- arma world-space orientata con la mira del player;
- icona HUD generata dallo stesso profilo dell'arma equipaggiata;
- proiettili con forma, scala, colore, glow e trail per profilo;
- muzzle flash coerente con il proiettile generato;
- torre con base esagonale, nucleo energetico e doppia canna orientabile;
- idle scan, tracking, rinculo e flash di fuoco della torre;
- smoke test dedicato e due catture QA a 1280x720.

## Linguaggio visuale

### Starter Pistol

- silhouette corta e sottile;
- corpo scuro con accento arancio;
- proiettile piccolo con trail breve;
- ruolo percepito: fallback affidabile.

### Prototype Blaster

- silhouette media con doppia forcella;
- corpo blu con energia ciano;
- proiettile piu largo e trail energetico;
- ruolo percepito: arma speciale tecnologica.

### Wave Cannon

- silhouette lunga e pesante con nucleo circolare;
- corpo viola con energia magenta;
- proiettile grande e trail marcato;
- ruolo percepito: ricompensa boss ad alto impatto.

### Defense Tower

- base esagonale scura;
- nucleo ciano pulsante;
- doppia canna leggibile nella direzione del target;
- rinculo e flash quando spara;
- profilo proiettile ciano dedicato.

## Contratto tecnico

- `WeaponData` referenzia opzionalmente `WeaponVisualData`.
- `WeaponSystem` passa il profilo a `ProjectileSystem`.
- `Projectile` applica il profilo solo alla presentazione.
- `PlayerVisual` e `WeaponIcon` leggono lo stesso dato dell'arma attiva.
- `DefenseTower` resta autoritativa per target, rateo, danno e range.
- `DefenseTowerVisual` riceve direzione e richieste di feedback senza
  selezionare target o applicare danno.
- Le chiamate esistenti a `ProjectileSystem` restano compatibili grazie al
  parametro visuale opzionale.

## Verifica automatica

```text
godot --headless --path . --script res://tests/milestone_13_weapon_tower_visual_smoke_test.gd
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
```

QA visuale:

```text
godot --path . --rendering-method gl_compatibility --script res://tests/weapon_tower_visual_qa.gd
```

Output:

```text
build/qa/milestone_13_player_weapons.png
build/qa/milestone_13_defense_towers.png
```

## Checklist manuale

- Equipaggiare le tre armi su player diversi e distinguerle senza leggere il
  nome HUD.
- Verificare che arma world-space e icona HUD mostrino lo stesso profilo.
- Sparare con ogni arma e confrontare colore, dimensione e trail.
- Controllare che la direzione dell'arma segua la mira.
- Verificare flash di volata e rinculo del player.
- Costruire tre torri in tower defense.
- Verificare idle scan prima dell'arrivo dei nemici.
- Verificare rotazione della canna verso un bersaglio.
- Verificare rinculo, flash e proiettile ciano durante il fuoco.
- Passare tra survival, dungeon e tower defense senza errori.

## Fuori scope

- nuove statistiche o nuovi tipi arma;
- upgrade e varianti della torre;
- sprite o animazioni definitive;
- effetti camera avanzati;
- identita visuale finale del boss;
- polish complessivo di menu e schermate fine run.
