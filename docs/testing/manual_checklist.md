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

- L'HUD mostra `HP 100/100` e `Ammo 12/INF` per ogni player appena spawnato.
- Sparare riduce il caricatore di una unita per colpo valido.
- Le munizioni di un player non modificano quelle degli altri player.
- Tenere premuto fire rispetta il fire rate della pistola.
- `R` o pulsante `X` avvia la ricarica e l'HUD mostra `RELOAD`.
- Dopo un secondo il caricatore viene riempito senza consumare una riserva finita.
- Equipaggiare una speciale mantiene disponibile la `Starter Pistol`.
- Con speciale a 0/0, premere fire spara nello stesso input con la fallback.
- L'HUD mostra `FALLBACK` e il feedback audio dedicato.
- Un pickup ammo riattiva la speciale e avvia il reload.
- Un proiettile che colpisce un bersaglio rosso riduce la sua barra vita.
- Quattro colpi della pistola distruggono un bersaglio da 40 HP.
- I proiettili non collidono con il player che li ha sparati.

## Smoke test automatico

Eseguire con Godot 4.x disponibile nel PATH:

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
```

Il test verifica scena principale, due player locali, sparo, collisione, danno, reload infinito e fallback da speciale esaurita.

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
- I pickup munizioni aggiornano la speciale di tutti i player vivi.
- Un player morto non riceve ammo condivisa.
- Se nessun player vivo possiede una speciale, il pickup ammo resta a terra.
- L'HUD mostra temporaneamente `AMMO SHARED +N`.
- I pickup vita curano solo il raccoglitore danneggiato.
- Un pickup vita non sparisce se raccolto a vita piena.
- Il pickup arma viola equipaggia il `Prototype Blaster`.
- Il cambio arma di un player non modifica l'arma degli altri player.
- I pickup restano separati dai nemici e dai proiettili.

## Smoke test enemy/drop

```text
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
```

Il test verifica spawn, chase, retarget, attack, danno, morte, pickup XP, ammo condivisa e isolamento del cambio arma con due player.

## Regressione Milestone 12

- La wave 1 contiene solo `Basic Zombie`.
- Dalla wave 2 ogni terzo slot regolare usa un `Runner Zombie`.
- Il runner e piu stretto, veloce e fragile del basic.
- Il runner raggiunge player isolati prima del gruppo standard.
- Dalla wave 3, con almeno cinque zombie, l'ultimo slot usa un `Tank Zombie`.
- Il tank e largo, lento, resistente e marcato in arancione.
- Il tank infligge piu danno ma attacca meno spesso.
- Basic, runner e tank reagiscono a hit e morte tramite gli stessi sistemi.
- Runner e tank generano rispettivamente 4 e 8 XP garantiti.
- Il conteggio HUD include tutte le varianti senza differenze.
- Con quattro player, silhouette nemico e colori slot restano leggibili.
- Dungeon continua a generare il roster basic.
- Tower defense continua a generare i raider dedicati.

## Smoke test Milestone 12

```text
godot --headless --path . --script res://tests/milestone_12_enemy_variants_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/enemy_variants_visual_qa.gd
```

La cattura QA viene salvata in:

```text
build/qa/milestone_12_enemy_variants.png
```

## Regressione zombie survival

- La scena mostra un countdown iniziale di 3 secondi.
- L'ondata 1 genera 3 zombie in modo scaglionato.
- L'HUD mostra indice ondata e nemici rimasti sul totale.
- L'ondata termina solo dopo la morte di tutti i nemici registrati.
- Alla fine dell'ondata il party riceve denaro.
- Ogni player vivo riceve munizioni e cura.
- Le munizioni di reward alimentano solo le armi speciali.
- Portare una speciale a 8 colpi totali o meno genera una supply crate dopo la valutazione del director.
- La supply crate genera pickup ammo e vita.
- Durante l'intermissione prima di ogni boss wave compare almeno una fonte supply garantita.
- Se la boss wave parte senza intermissione, la fonte compare all'inizio della wave.
- Con tutte le speciali a 0/0, ogni player vivo puo ancora sparare con la fallback.
- Uscire dalla survival rimuove le supply crate non aperte.
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

Il test verifica tre ondate, scaling, reward, director low-ammo, supply crate boss, join multiplayer e fallback per tutti i player vivi.

## Regressione Milestone 13

- `Starter Pistol` ha silhouette compatta e accento arancio.
- `Prototype Blaster` ha doppia forcella e accento ciano.
- `Wave Cannon` ha silhouette pesante e accento magenta.
- Ogni arma resta leggibile contro l'arena desaturata.
- L'arma world-space segue la direzione di mira.
- L'icona HUD corrisponde all'arma equipaggiata dal relativo player.
- I tre proiettili differiscono per forma, scala, colore e trail.
- Il muzzle flash usa la famiglia cromatica dell'arma.
- Con quattro player, armi e colori slot non si confondono.
- La torre mostra base esagonale, nucleo e doppia canna.
- Senza target la torre esegue un idle scan leggero.
- Con target la canna segue la direzione corretta.
- Lo sparo torre mostra rinculo, flash e proiettile ciano.
- Costruzione, crediti, targeting e danno tower defense restano invariati.
- Dungeon e boss continuano a usare i proiettili condivisi senza errori.

## Smoke test Milestone 13

```text
godot --headless --path . --script res://tests/milestone_13_weapon_tower_visual_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/weapon_tower_visual_qa.gd
```

Le catture QA vengono salvate in:

```text
build/qa/milestone_13_player_weapons.png
build/qa/milestone_13_defense_towers.png
```

## Regressione Milestone 14

- `GET READY`, `WAVE` e `WAVE CLEAR` sono leggibili da divano.
- `WAVE CLEAR` non viene sostituito immediatamente dall'intermissione.
- Il pannello boss resta centrato e separato dal pannello party.
- Il `Wave Warden` non si confonde con zombie, player o torri.
- L'occhio arancio indica il target del boss.
- Le piastre viola e il nucleo ciano identificano la fase 1.
- Le spine, le piastre magenta e il nucleo arancio identificano la fase 2.
- Il flash da danno e breve e non nasconde permanentemente la fase.
- La carica aimed e distinta dalla carica radial.
- I proiettili aimed hanno glow/trail viola.
- I proiettili radial hanno glow/trail corallo.
- `OVERDRIVE` resta leggibile con quattro schede player.
- La morte genera anelli, frammenti e nucleo in dissolvenza.
- `WARDEN DOWN` resta visibile mentre compaiono i drop.
- Dungeon e tower defense continuano a usare il boss condiviso.

## Smoke test Milestone 14

```text
godot --headless --path . --script res://tests/milestone_14_final_polish_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/final_survival_visual_qa.gd
```

Le catture QA vengono salvate in:

```text
build/qa/milestone_14_wave_presentation.png
build/qa/milestone_14_boss_phase_one.png
build/qa/milestone_14_boss_phase_two.png
build/qa/milestone_14_boss_defeat.png
```

## Regressione boss

- La quinta ondata genera un solo `Wave Warden`.
- La boss wave dispone di una supply crate garantita.
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

## Regressione Milestone 11

- La raffica mirata mostra un cono e tre corsie prima del fuoco.
- Il countdown world-space resta leggibile sopra arena e attori.
- Nessun proiettile viene creato durante il warning mirato.
- Spostarsi durante il warning non cambia la direzione gia annunciata.
- La raffica radiale mostra dodici raggi e varchi leggibili.
- Nessun proiettile viene creato durante il warning radiale.
- L'HUD mostra `AIMED VOLLEY - MOVE` e `RADIAL BURST - FIND A GAP`.
- Spawn, warning e fase boss producono cue audio distinti.
- Sotto il 50% il boss mostra impulso e messaggio `PHASE 2 - OVERDRIVE`.
- Con 2-4 player i telegraph restano distinguibili dalle schede HUD e dai colori slot.
- Il boss dungeon mantiene telegraph, danno e drop condivisi.
- Il boss tower defense continua a seguire il percorso senza pattern action.

## Smoke test Milestone 11

```text
godot --headless --path . --script res://tests/milestone_11_boss_telegraph_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/boss_telegraph_visual_qa.gd
```

Le catture QA vengono salvate in:

```text
build/qa/milestone_11_boss_aimed.png
build/qa/milestone_11_boss_radial.png
```

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

## Regressione Milestone 9

- Il progetto parte con il menu visibile e nessuna modalita attiva.
- Il menu mostra livello, XP, denaro e ultima modalita.
- Tastiera e joypad possono selezionare survival, dungeon e tower defense.
- Il gameplay HUD appare dopo la selezione.
- `Esc` arresta la modalita corrente e torna al menu.
- `Continue` avvia l'ultima modalita salvata.
- Una variazione di XP o denaro aggiorna `user://savegame.json`.
- Riavviando il progetto, livello, XP, denaro e ultima modalita vengono ripristinati.
- Un save v1 viene caricato e riscritto come v2 senza perdere progressione.
- Raggiungere il livello party 2 sblocca `Field Kit`.
- Il menu mostra lo stato di `Field Kit`.
- Con `Field Kit`, ogni nuova run parte a 120/120 HP.
- Cambiare modalita non accumula il bonus oltre 120 HP.
- Un player che entra durante la run riceve lo stesso bonus.
- Un save con versione non supportata viene ignorato senza azzerare la sessione.
- Focus e conferma dei pulsanti producono feedback audio.
- Sparo, impatto con danno e pickup producono feedback audio gameplay.
- `Starter Pistol` usa 6 colpi/s e `Prototype Blaster` 4,5 colpi/s.
- Con i template Godot `4.6.3` installati, il preset `Windows Desktop` genera `build/iso_local_sandbox.exe`.
- Il pacchetto release non contiene file da `tests/` o `build/`.

## Smoke test Milestone 9

```text
godot --headless --path . --script res://tests/milestone_9_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/menu_visual_qa.gd
build/iso_local_sandbox.exe --rendering-method gl_compatibility -- --build-smoke
```

Esito QA del 15 giugno 2026:

- build smoke exit `0`;
- menu, focus, survival e ritorno al menu verificati visualmente a 1280x720;
- controller `XInput Controller` rilevato;
- D-pad e joypad `A` verificati tramite eventi joypad;
- driver audio `WASAPI` rilevato;
- feedback focus: 771 frame audio;
- feedback conferma: 1543 frame audio.

## Regressione Milestone 10

- L'arena survival usa una palette desaturata e non compete con gli attori.
- I tre bersagli combat debug rossi non sono visibili durante una run.
- I proiettili attraversano le vecchie posizioni dei bersagli debug invisibili.
- Ogni player mostra sagoma, arma e colore slot distinti.
- Camminata, mira, sparo, reload, danno e morte modificano il visual survivor.
- Lo zombie e riconoscibile da pelle, posa curva e braccia protese.
- Chase, attack e hit reaction dello zombie sono leggibili.
- XP, denaro, ammo, cura e arma hanno icone world-space diverse.
- Nessun pickup usa label `XP`, `$`, `A`, `+` o `W`.
- La supply crate e riconoscibile senza la label `SUP`.
- Le schede HUD mostrano vita, arma e munizioni di ogni player attivo.
- Sparo, hit valido, morte nemico e raccolta generano effetti visuali.
- Con 2-4 player, schede e colori restano distinguibili a 1280x720.
- Dungeon e tower defense continuano ad avviarsi e a tornare alla survival.

## Smoke test Milestone 10

```text
godot --headless --path . --script res://tests/milestone_10_visual_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/survival_visual_qa.gd
```

La cattura QA viene salvata in:

```text
build/qa/milestone_10_survival.png
```
