# Manual Test Checklist

## Smoke test base

- Il progetto si apre in Godot 4.x.
- La scena principale parte senza errori.
- Il player viene spawnato.
- La griglia pseudo-isometrica e visibile.
- Il movimento tastiera funziona.
- Il joypad player 1 funziona se collegato.
- La camera segue il player.
- L'HUD mostra stato prototipo.

## Regressione input

- `WASD` produce movimento.
- Le frecce aggiornano la mira.
- Lo stick sinistro produce movimento.
- Lo stick destro aggiorna la mira.
- Il fire action non genera errori.
- Il fire action genera proiettili visibili.
- `R` ricarica l'arma del player 1.
- Il pulsante joypad `X` ricarica l'arma dello slot associato.

## Regressione multiplayer locale

- La scena parte con player 1 attivo.
- `F2`, `F3` e `F4` attivano rispettivamente player 2, 3 e 4.
- Premere di nuovo `F2`, `F3` o `F4` rimuove lo slot corrispondente senza rimuovere player 1.
- Con piu player attivi, l'HUD mostra conteggio e slot corretti.
- Con piu player attivi, la camera segue il centro del gruppo e modifica lo zoom.
- Con joypad multipli, `Start` attiva lo slot associato al controller e `Back/Select` lo disattiva se non e player 1.
- Ogni player mantiene input, mira e fire action del proprio slot.

## Regressione combat

- L'HUD mostra `HP 100/100` e `Ammo 12/36` per ogni player appena spawnato.
- Sparare riduce il caricatore di una unita per colpo valido.
- Le munizioni di un player non modificano quelle degli altri player.
- Tenere premuto fire rispetta il fire rate della pistola.
- `R` o pulsante `X` avvia la ricarica e l'HUD mostra il suffisso `R`.
- Dopo un secondo il caricatore viene riempito consumando la riserva.
- Un proiettile che colpisce un bersaglio rosso riduce la sua barra vita.
- Quattro colpi della pistola distruggono un bersaglio da 40 HP.
- I proiettili non collidono con il player che li ha sparati.

## Smoke test automatico

Eseguire con Godot 4.x disponibile nel PATH:

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
```

Il test verifica scena principale, due player locali, sparo, collisione, danno, munizioni indipendenti e ricarica.

## Regressione nemici

- La scena principale genera i `Basic Zombie` tramite `WaveManager`.
- Un nemico inattivo senza player valido resta in idle.
- Un nemico entro detection range insegue il player vivo piu vicino.
- Con due player separati, il nemico puo cambiare target verso quello piu vicino.
- Se il target lascia la sessione, il nemico seleziona un altro player vivo.
- A distanza melee il nemico entra in attack e infligge 8 danni tramite `HealthSystem`.
- Tre colpi della `Starter Pistol` uccidono un nemico da 30 HP.
- Alla morte il nemico sparisce dal registro di `EnemySystem`.
- Un player morto non puo muoversi o sparare e non viene selezionato come target.

## Regressione drop

- Ogni nemico morto genera sempre un pickup XP.
- I pickup denaro aggiornano il totale party nell'HUD.
- I pickup munizioni aggiornano solo la riserva del raccoglitore.
- I pickup vita curano solo il raccoglitore danneggiato.
- Un pickup vita non sparisce se raccolto a vita piena.
- Il pickup arma viola equipaggia il `Prototype Blaster`.
- Il cambio arma di un player non modifica l'arma degli altri player.
- I pickup restano separati dai nemici e dai proiettili.

## Smoke test enemy/drop

```text
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
```

Il test verifica spawn, chase, retarget, attack, danno da proiettile, morte, pickup XP e tutti i tipi di ricompensa con due player.

## Regressione zombie survival

- La scena mostra un countdown iniziale di 3 secondi.
- L'ondata 1 genera 3 zombie in modo scaglionato.
- L'HUD mostra indice ondata e nemici rimasti sul totale.
- L'ondata termina solo dopo la morte di tutti i nemici registrati.
- Alla fine dell'ondata il party riceve denaro.
- Ogni player vivo riceve munizioni e cura.
- La nuova ondata parte dopo 4 secondi.
- Ogni ondata aggiunge 2 zombie.
- Vita, velocita e danno degli zombie aumentano tra le ondate.
- Un player puo entrare o uscire senza interrompere la wave.
- Un player entrato durante la run riceve le ricompense delle ondate successive.
- Ogni quinta ondata mostra il marker `BOSS`.
- La quinta ondata genera due zombie di scorta e il `Wave Warden`.
- La wave non termina finche il boss e vivo.
- Se tutti i player attivi muoiono, la run si arresta.

## Smoke test survival

```text
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
```

Il test verifica tre ondate, spawn progressivo, scaling, ricompense, HUD, join player e richiesta boss.

## Regressione boss

- La quinta ondata genera un solo `Wave Warden`.
- La barra boss mostra nome, fase e vita.
- Il boss seleziona il player vivo piu vicino.
- Il boss mantiene distanza e movimento laterale.
- In fase 1 usa raffiche mirate da tre proiettili.
- I proiettili viola danneggiano i player e non il boss.
- Sotto il 50% il boss entra in fase 2.
- In fase 2 alterna raffiche radiali e mirate.
- Join/leave player non interrompe il targeting.
- La wave resta in combat finche il boss e vivo.
- Alla morte la barra boss scompare.
- `BossSystem` emette la sconfitta per la modalita survival.
- Il boss genera sempre XP, denaro e pickup `Wave Cannon`.
- Raccogliere `Wave Cannon` modifica solo l'arma del raccoglitore.
- Dopo il boss la run entra in intermissione e prosegue.

## Smoke test boss

```text
godot --headless --path . --script res://tests/boss_smoke_test.gd
```

Il test verifica quinta ondata, scaling, pattern, danno, fase 2, HUD, morte, drop speciale e prosecuzione.

## Regressione dungeon

- `F5` arresta survival e avvia una run dungeon.
- L'HUD mostra seed, indice stanza, tipo stanza, stato uscita e nemici rimasti.
- La start room mostra il portale verde e consente il passaggio.
- Entrando nel portale il party viene riposizionato nella stanza successiva.
- Le combat room mostrano il portale rosso finche rimangono nemici.
- Uccidere tutti i nemici rende verde il portale.
- Il numero e le statistiche dei nemici aumentano nelle combat room successive.
- La loot room genera XP, denaro, munizioni e vita.
- La boss room genera il `Wave Warden` tramite il sistema condiviso.
- Il portale finale resta bloccato finche il boss e vivo.
- Attraversare il portale finale completa la run.
- Se tutti i player attivi muoiono, la run dungeon si arresta.
- `F1` arresta dungeon, ripulisce stanza e pickup e riavvia survival.

## Smoke test dungeon

```text
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
```

Il test verifica seed deterministico, celle uniche, link, transizione fisica, combat, loot, boss, completamento e ritorno a survival.

## Regressione tower defense

- `F6` arresta la modalita corrente e apre l'arena tower defense.
- L'HUD mostra vita core, crediti, ondata e nemici rimasti.
- Il core parte da 250 HP e la run da 75 crediti.
- I nemici arancioni seguono l'intero percorso.
- Un nemico che arriva al core infligge 12 danni base.
- Entrare in uno slot azzurro e premere `E` costruisce una torre per 25 crediti.
- Con joypad, il pulsante `A` costruisce per lo slot player associato.
- Uno slot occupato non consente una seconda costruzione.
- Una torre acquisisce automaticamente i bersagli sul percorso e usa proiettili visibili.
- Eliminare un nemico assegna 4 crediti.
- Completare una wave assegna la ricompensa crediti mostrata nell'HUD.
- Conteggio e statistiche dei nemici aumentano nelle ondate successive.
- La quinta ondata genera tre scorte e il `Wave Warden`.
- La boss wave termina solo quando scorte e boss sono morti o hanno raggiunto il core.
- Se il core raggiunge 0 HP, la run entra in stato `DEFENSE FAILED`.
- `F1` ripulisce arena e torri e riavvia survival.

## Smoke test tower defense

```text
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
```

Il test verifica cambio modalita, percorso, danno core, crediti, costruzione, fuoco torre, boss wave, HUD, sconfitta e pulizia runtime.

## Regressione architettura

- I sistemi non sono duplicati in cartelle diverse.
- Ogni nuova modalita usa `GameModeManager`.
- Drop, XP, boss e wave restano sistemi separati.
