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
- `P` apre e chiude il menu pausa durante una run.
- Lo stick sinistro produce movimento.
- Lo stick destro aggiorna la mira.
- `Start` apre e chiude il menu pausa durante una run.
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
- Con joypad multipli, `Start` attiva lo slot associato al controller dal menu e `Back/Select` lo disattiva se non e player 1.
- Ogni player mantiene input, mira e fire action del proprio slot.

## Regressione pausa e settings

- Il main menu mostra un pulsante Settings.
- Settings contiene i tab Audio, Video e Controls.
- D-pad, frecce e stick sinistro navigano le voci menu in modo circolare.
- `Esc`, joypad `B` o `Back` tornano al menu precedente da Character Select,
  Settings e pausa; nel menu principale non rompono lo stato.
- In Settings, `LB` seleziona la tab precedente e `RB` quella successiva,
  entrambe con wrapping e focus su un controllo valido della tab corrente.
- Master, Music e SFX sono nel tab Audio e non nella pagina principale.
- Il tab Video permette di selezionare finestra/fullscreen, borderless, risoluzione, VSync e limite framerate.
- Il tab Video conserva anche preset e slider visual/accessibilita.
- Il tab Controls permette di riassegnare movimento, mira, fire, reload, super, interact, pause, join e leave joypad.
- Un binding gameplay joypad modificato viene applicato a tutti gli slot locali.
- Salvare e riavviare ripristina audio, video e controlli joypad.
- Durante una run, `Start` apre la pausa senza attivare nuovi slot.
- Dal menu pausa Resume torna alla partita congelata, Settings apre gli stessi tab del main menu e Main Menu arresta la run.

```text
godot --headless --path . --script res://tests/pause_settings_smoke_test.gd
```

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

## Regressione RPG Milestone 7

- A 1280x720 e 960x540, provare Ranger, Pistoliere, Berserker e Spadaccino in
  survival: ascia rischiosa/potente, spada controllata/difensiva, arco leggibile
  a distanza e pistola leggibile in cadenza ravvicinata.
- Verificare che `Pioggia di Frecce`, `Scarica Finale`, `Terremoto di Sangue` e
  `Lama Fantasma` siano distinguibili a colpo d'occhio tra zombie, pickup e
  ostacoli.
- Provare Mago, Domatrice e Licantropo per almeno cinque wave ciascuno:
  `Stella Cadente` radiale, `Branco di Rottami` burst e `Notte Bestiale` dash/
  trasformazione devono restare leggibili.
- Con due player attivi, verificare che Briciola aiuti Nina senza bloccarla,
  resti vicino dopo gli attacchi e non pulisca la wave da sola.
- Verificare che `Notte Bestiale` torni sempre alla forma umana con recovery
  breve visibile prima di riprendere il profilo normale.

```text
godot --headless --path . --script res://tests/rpg_melee_attack_resolution_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_8_adrenaline_super_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_10_balance_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_12_feedback_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_13_new_classes_smoke_test.gd
```

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

- Gli zombie survival non generano pickup XP; il killer riceve XP RPG diretta.
- I pickup XP fisici restano supportati per loot room, boss e fixture legacy.
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

Il test verifica spawn, chase, retarget, attack, danno, morte, pickup XP legacy, ammo condivisa e isolamento del cambio arma con due player.

## Regressione Milestone 12

- La wave 1 contiene solo `Basic Zombie`.
- Dalla wave 2 ogni terzo slot regolare usa un `Runner Zombie`.
- Il runner e piu stretto, veloce e fragile del basic.
- Il runner raggiunge player isolati prima del gruppo standard.
- Dalla wave 3, con almeno cinque zombie, l'ultimo slot usa un `Tank Zombie`.
- Il tank e largo, lento, resistente e marcato in arancione.
- Il tank infligge piu danno ma attacca meno spesso.
- Basic, runner e tank reagiscono a hit e morte tramite gli stessi sistemi.
- Runner e tank assegnano rispettivamente 7 e 12 XP RPG al killer.
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

## Regressione Revamp Zombie Z4

- La survival parte con la palette della `Pianura Infetta`.
- Patch di erba secca, terra e detriti rendono il terreno meno vuoto.
- Sono visibili rocce, recinto rotto, barriera, rudere e confine parziale.
- Player e zombie collidono con gli ostacoli fisici.
- Le corsie centrali nord/sud/est/ovest restano attraversabili.
- Gli zombie non spawnano dentro gli ostacoli.
- La cassa comune e la cassa medica sono raggiungibili dal party.
- Le casse ambientali non sostituiscono le crate del director ammo.
- Uscire dalla survival rimuove patch, ostacoli e casse ambientali.
- Cambiare arena non duplica i contenuti runtime.

```text
godot --headless --path . --script res://tests/zombie_environment_milestone_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/arena_variants_visual_qa.gd
```

## Regressione Revamp Zombie Z5

- La Pianura Infetta mostra una fall zone leggibile come vuoto/caduta con
  bordo cliff/depth fuori dalle corsie centrali.
- Entrare nella zona sottrae esattamente 20 HP.
- Il player riappare all'ultima posizione sicura e non conserva velocita.
- La breve invulnerabilita evita una seconda caduta immediata.
- Super e altre invulnerabilita non vengono cancellate dal recupero.
- Danno e respawn mostrano effetti distinti e un cue audio ambientale.
- Gli zombie non spawnano dentro o troppo vicino alla fall zone.
- Uscire dalla survival rimuove hazard e protezioni temporanee.
- Industrial Crossroads e Rift Foundry restano avviabili senza duplicazioni.

```text
godot --headless --path . --script res://tests/zombie_fall_hazard_smoke_test.gd
godot --headless --path . --script res://tests/zombie_revamp_foundation_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_8_adrenaline_super_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/arena_variants_visual_qa.gd
```

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

## Regressione Milestone 16

- Un danno letale porta il player in stato downed senza rimuovere il colore slot.
- Il player downed non si muove, non spara e non viene targettato.
- Tenere `E` o joypad `A` vicino al target avanza l'anello.
- Lasciare interact o uscire dal raggio azzera il progresso.
- Il revive ripristina il 35% degli HP massimi.
- `Field Kit` resta a 120 HP massimi dopo revive e nuove run.
- Il leave del reviver interrompe senza completamenti tardivi.
- Survival, dungeon e tower defense risolvono un party interamente downed.

```text
godot --headless --path . --script res://tests/milestone_16_downed_revive_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/downed_revive_visual_qa.gd
```

## Regressione Milestone 17

- Survival, dungeon e tower defense mostrano un titolo terminale esplicito.
- Tempo, XP, denaro e unlock derivano dalla sessione reale.
- Retry riusa la modalita senza duplicare nodi o bonus.
- Il focus iniziale resta visibile da joypad.
- Cambio modalita avvia il modo successivo.
- Il ritorno al menu salva prima del cambio stato.

```text
godot --headless --path . --script res://tests/milestone_17_run_results_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/run_results_visual_qa.gd
```

## Regressione Milestone 18

- Tutti i bus richiesti esistono e le categorie inviano a SFX.
- Asset opzionali assenti usano fallback senza errori.
- Le tre armi hanno fallback distinti.
- Shooter, wave, downed, revive e risultati generano cue.
- Il limite voci non viene superato nelle situazioni affollate.
- Master, Music e SFX persistono dopo il riavvio.

```text
godot --headless --path . --script res://tests/milestone_18_audio_mix_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/audio_mix_visual_qa.gd
```

## Regressione Milestone 19

- Survival e tower defense continuano a generare il `Wave Warden`.
- Il dungeon genera il `Rift Architect`.
- Lane sweep mostra sempre il varco sicuro prima dei proiettili.
- Cross burst mostra gli assi e il countdown prima del fuoco.
- L'HUD usa nome e fase del boss attivo.
- Il Rift Architect genera il `Rift Repeater`.
- Una richiesta incompatibile viene rifiutata senza spawn.

```text
godot --headless --path . --script res://tests/milestone_19_boss_registry_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/rift_architect_visual_qa.gd
```

## Regressione Milestone 20

- `Industrial Crossroads` e `Rift Foundry` usano lo stesso controller survival.
- Ogni punto spawn ha un gate visibile ma non collidente.
- Quattro player restano distinguibili in entrambi i layout.
- Basic, runner, tank e shooter attraversano gate e props senza blocchi.
- Un proiettile player puo armare il barile.
- Nessun danno viene applicato durante il warning.
- Il cerchio di esplosione e leggibile prima della detonazione.
- Cambio modalita e stop survival rimuovono gate e props runtime.

```text
godot --headless --path . --script res://tests/milestone_20_arena_environment_smoke_test.gd
godot --headless --path . --script res://tests/milestone_20_arena_stress_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/arena_variants_visual_qa.gd
```

## Regressione Milestone 21

- Ogni controllo visuale aggiorna la scena senza riavvio.
- Save/load ripristina flash, glow, trail, shake, testo e toggle.
- Glow e trail a zero non cambiano danno o velocita del proiettile.
- Reduced motion rimuove shake, bob e pulse senza cambiare i countdown.
- P1-P4 restano distinguibili tramite marker geometrici.
- Pickup e crate restano identificabili senza affidarsi al colore.
- High contrast rinforza HUD, marker e warning.
- Il menu visuale resta interamente visibile a 1280x720.
- Il profilo con 4 player, roster misto e boss resta sotto il budget registrato.
- Ogni asset esterno aggiunto compare in `assets/ATTRIBUTION.md`.

```text
godot --headless --path . --script res://tests/milestone_21_visual_settings_performance_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/visual_accessibility_qa.gd
```

## Regressione architettura

- I sistemi non sono duplicati in cartelle diverse.
- Ogni nuova modalita usa `GameModeManager`.
- Drop, XP, boss e wave restano sistemi separati.

## Revamp zombie Z6-Z12

- Avviare survival e confermare la partenza nella `Pianura Infetta`.
- Attraversare il gate est fino a Tossico, Infuocato, Neve e Palude.
- Tornare indietro almeno una volta usando il gate ovest.
- Verificare che ogni bioma cambi palette, terreno, ostacoli, casse e hazard.
- Verificare che almeno un bordo resti bloccato fisicamente in ogni area.
- Restare dentro ogni hazard e confermare danno o modifica movimento coerente.
- Entrare nella fall zone e confermare `-20 HP`, respawn sicuro e invulnerabilita.
- Aprire casse comuni, mediche, militari e tematiche.
- Confermare feedback HUD per antidoto, ammo tematica e materiali.
- Completare almeno una wave in ogni bioma e verificare il roster contestuale.
- Confermare almeno due zombie tematici per bioma avanzato.
- Verificare poison, burning, chilled, mudded/soaked e hazard alla morte.
- Muoversi continuamente durante gli spawn e controllare i quattro bordi camera.
- Verificare che nessuno zombie appaia in ostacoli, acqua profonda o fall zone.
- Controllare HUD: nome bioma, pericolo, risorse, status e annuncio transizione.
- Eseguire una run reale di almeno 10 minuti senza bug bloccanti.

```text
godot --headless --path . --script res://tests/zombie_biome_transition_smoke_test.gd
godot --headless --path . --script res://tests/zombie_biome_enemy_smoke_test.gd
godot --headless --path . --script res://tests/zombie_revamp_ten_wave_smoke_test.gd
godot --headless --path . --script res://tests/zombie_revamp_ten_minute_soak_test.gd
godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/zombie_biome_visual_qa.gd
```

## Regressione todo_roadmap Milestone 2 - mini-eventi bioma

- Avviare una run survival con seed fisso `2026` quando il contesto debug lo
  consente; in alternativa usare gli smoke sotto per forzare gli eventi.
- Completare o simulare 10 wave attraversando i biomi avanzati.
- Verificare `toxic_leak`: telegraph verde tossico, almeno tre hazard
  evitabili, nessun blocco di passaggi/casse/spawn e reward crate tossica.
- Verificare `fire_breakout`: telegraph arancio, hazard fuoco evitabili,
  corridoio di fuga leggibile e reward crate fuoco.
- Verificare `whiteout`: warning gelo leggibile, `freeze` applicato solo ai
  player rimasti nell'area e reward crate frost.
- Verificare `marsh_emergence`: warning palude, emergenza zombie leggibile,
  spazio di reazione sufficiente e reward crate palude.
- Ripetere almeno un evento con preset `high_contrast` e uno con
  `reduced_motion`; il warning deve restare visibile e non dipendere dal pulse.
- Con almeno due player locali, confermare che un player fuori dal warning non
  riceve lo status mentre uno dentro lo riceve.
- Confermare che HUD/status non coprono HP, ammo, XP o annuncio wave durante
  gli eventi.
- Salvare screenshot o video dei quattro eventi durante il playtest end-to-end
  di bilanciamento.

```text
godot --headless --path . --script res://tests/random_encounter_smoke_test.gd
godot --headless --path . --script res://tests/biome_mini_events_smoke_test.gd
godot --headless --path . --script res://tests/biome_status_effects_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/milestone_rpg_13_new_classes_smoke_test.gd
```

## Regressione todo_roadmap Milestone 3 - attraversamento megamappa e streaming regioni

QA da eseguire con una run survival e seed fisso (es. `world_seed` debug `2026`).
Durata indicativa: 20 minuti continui.

- Partire dalla regione iniziale e attraversare almeno otto regioni distinte
  usando i passaggi fisici aperti, senza interruzioni o cambi modalita.
- Confermare che ogni transizione resti continua: nessun teletrasporto percepito,
  la camera e il party restano vicino al varco attraversato.
- Verificare che almeno un bordo per regione resti bloccato fisicamente e che le
  corsie centrali restino attraversabili.
- Provare il dodge su un gap piccolo in almeno tre regioni diverse e confermare
  che l'attraversamento del varco resti affidabile.
- Aprire alcune casse ambientali in una regione, attraversare verso i vicini e
  poi rientrare: le casse gia aperte non devono ricomparire.
- Confermare che gli encounter gia risolti non vengano riproposti rientrando in
  una regione (gli encounter casuali restano legati alle wave, non alla regione).
- Aprire la mappa esplorazione in `default` e `high_contrast`: regione corrente,
  visitate, scoperte e fog devono restare leggibili; salvare screenshot della
  mappa e dei passaggi aperti in entrambe le modalita.
- Salvare ed uscire dopo aver aperto alcune casse, ricaricare e confermare che
  lo stato runtime per regione (casse aperte e regioni visitate) sia ripristinato
  dal save v6.
- Monitorare il frame time durante la traversata con griglia almeno `7x7` e wave
  affollate; annotare eventuale debito di performance.

Screenshot/video reali della traversata e della mappa restano da acquisire
durante il prossimo playtest end-to-end di bilanciamento (Milestone 11), come
gia previsto per i mini-eventi bioma.

```text
godot --headless --path . --script res://tests/region_streaming_smoke_test.gd
godot --headless --path . --script res://tests/world_graph_connectivity_smoke_test.gd
godot --headless --path . --script res://tests/persistent_world_generation_smoke_test.gd
godot --headless --path . --script res://tests/open_passage_transition_smoke_test.gd
godot --headless --path . --script res://tests/exploration_map_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
```

## Regressione todo_roadmap Milestone 4 - asset isometrici ambiente e ostacoli

QA visuale da eseguire a `1280x720` e `960x540`, in `default`, `reduced_motion`
e `high_contrast`.

- Avviare survival e confermare che ogni ostacolo (rocce, recinti, muretti,
  case/rovine, barili, relitti, tronchi, ponti e bordi) abbia un'ombra a terra
  coerente e una silhouette leggibile contro il terreno.
- Verificare il Y-sort: uno zombie o un pickup davanti (piu in basso) a un
  ostacolo deve disegnarsi sopra l'ostacolo; dietro (piu in alto) deve essere
  coperto. I player restano sempre visibili sopra gli ostacoli (scelta di
  leggibilita per il co-op locale).
- Confermare che gli ostacoli grandi (case, bordi) lascino corridoi
  attraversabili e non muri casuali; le corsie centrali restano percorribili.
- Attraversare almeno tre biomi e confermare che ogni categoria di ostacolo
  converta mantenendo collisione e footprint coerenti con il visual.
- Verificare che nessun asset esterno sia richiesto: il bootstrap parte e gli
  ostacoli si disegnano con draw procedurali.
- In `high_contrast` confermare che ombre e props non riducano la leggibilita di
  HUD, telegraph e pickup.
- Salvare screenshot per bioma (default e high contrast) durante il prossimo
  playtest end-to-end (Milestone 11).

```text
godot --headless --path . --script res://tests/isometric_environment_manifest_smoke_test.gd
godot --headless --path . --script res://tests/biome_obstacle_generation_smoke_test.gd
godot --headless --path . --script res://tests/zombie_environment_milestone_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
```

## Regressione ISO-001 Milestone 2 - terrain isometrico 200x200

QA visuale da eseguire con seed fisso a `1280x720` e `960x540`, in `default`
e `high_contrast`.

- Avviare survival con una megamappa `5x5` e attraversare almeno una regione
  per ciascuno dei cinque biomi.
- Confermare che `main_road`, `road`, `broken_street`, `service_lane`,
  `ash_lane`, `packed_snow_path`, `wooden_walkway`, `bridge`, `snow_pass`,
  `broken_gate` e `burned_road` siano leggibili come strade, passaggi, ponti o
  cancelli, non come dirt generico.
- Verificare che la base `200x200` resti continua e che passaggi e fall zone
  non si sovrappongano visivamente in modo confuso.
- Attivare l'overlay debug e controllare che i conteggi terrain mostrino
  `walkable`, `obstacle`, `hazard`, `border`, `void` e `fall_zone`.
- Salvare screenshot per terreno/passaggi dei cinque biomi durante il prossimo
  playtest end-to-end (Milestone 11); gli smoke headless non sostituiscono
  questa verifica visuale.

```text
godot --headless --path . --script res://tests/isometric_biome_terrain_coverage_smoke_test.gd
godot --headless --path . --script res://tests/biome_debug_overlay_smoke_test.gd
godot --headless --path . --script res://tests/biome_world_generation_smoke_test.gd
godot --headless --path . --script res://tests/open_passage_transition_smoke_test.gd
```

## Regressione ISO-001 Milestone 3 - oggetti e ostacoli isometrici

QA visuale da eseguire con seed fisso a `1280x720` e `960x540`, in `default`
e `high_contrast`.

- Attraversare almeno una regione per ciascuno dei cinque biomi e verificare
  che ogni bioma abbia almeno due categorie di ostacolo distinguibili.
- Confermare che `pipe_stack`, `burned_car`, `ice_block`, `dead_tree`,
  `lab_block`, `snow_cabin`, `sunken_house` e `toxic_barrel` non sembrino
  barriere generiche.
- Verificare che muri/barriere tematiche (`lab_wall`, `charred_wall`,
  `ash_barrier`, `snow_wall`, `reed_wall`, `broken_walkway`) restino leggibili
  senza coprire pickup, telegraph o zombie in modo ambiguo.
- Controllare ombra/base per ostacoli grandi e sorting con player/zombie
  davanti e dietro; i player restano sopra per leggibilita co-op.
- Confermare che collisioni e spawn blocker siano invariati: niente spawn dentro
  ostacoli, corridoi centrali attraversabili, casse raggiungibili.
- Salvare screenshot per bioma durante il prossimo playtest end-to-end
  (Milestone 11).

```text
godot --headless --path . --script res://tests/isometric_environment_manifest_smoke_test.gd
godot --headless --path . --script res://tests/biome_obstacle_generation_smoke_test.gd
godot --headless --path . --script res://tests/biome_world_generation_smoke_test.gd
godot --headless --path . --script res://tests/zombie_environment_milestone_smoke_test.gd
```

## Regressione ISO-001 Milestone 5 - bordi, muri, vuoto e caduta

QA visuale da eseguire con seed fisso a `1280x720` e `960x540`, in `default`
e `high_contrast`.

- In ogni bioma, verificare che i lati con regione adiacente ma senza edge siano
  bloccati da muri/barriere tematiche, non da fall zone.
- Verificare che i lati collegati mostrino un'apertura percorribile e che i
  segmenti chiusi attorno al passaggio restino fisici.
- Verificare che i lati senza regione adiacente siano fall zone visive e
  dannose, con profondita/cliff leggibile.
- Provare il roll su un piccolo gap/fall zone e confermare che riesca solo con
  landing valida.
- Provare il roll attraverso lava, gas/acqua profonda o altri hazard ambientali
  e confermare che venga bloccato.
- Confermare che zombie, casse e spawn non usino fall zone o hazard come
  posizioni valide.
- Salvare screenshot per border/fall zone dei cinque biomi durante il prossimo
  playtest end-to-end (Milestone 11).

```text
godot --headless --path . --script res://tests/isometric_environment_manifest_smoke_test.gd
godot --headless --path . --script res://tests/fall_boundary_visual_logic_smoke_test.gd
godot --headless --path . --script res://tests/player_dodge_gap_smoke_test.gd
godot --headless --path . --script res://tests/zombie_fall_hazard_smoke_test.gd
godot --headless --path . --script res://tests/biome_world_generation_smoke_test.gd
godot --headless --path . --script res://tests/open_passage_transition_smoke_test.gd
```

## Regressione ISO-001 Milestone 4 - collisioni coerenti con props e strutture

QA da eseguire con una run survival e seed fisso, con tastiera e joypad.

- Sparare con l'arma fallback contro muri, case/rovine e bordi tematici: i
  proiettili devono fermarsi sul muro e non attraversarlo.
- Sparare contro ostacoli piccoli (rocce, barili, tronchi): confermare che
  bloccano i proiettili in modo coerente con la silhouette.
- Posizionarsi dietro un edificio mentre uno zombie shooter o il boss sparano:
  i proiettili ostili devono essere fermati dal muro.
- Provare il kiting attorno a edifici grandi e nei corridoi centrali:
  player e zombie devono collidere fisicamente con gli ostacoli senza incastri.
- Confermare che spawn nemici e casse non compaiano dentro un ostacolo
  (footprint coerente tra collisione, spawn blocker e validazione casse).
- Provare il dodge verso un ostacolo solido e confermare che la traiettoria
  resti bloccata e il roll si accorci o venga rifiutato.

```text
godot --headless --path . --script res://tests/milestone_4_obstacle_collision_smoke_test.gd
godot --headless --path . --script res://tests/isometric_environment_manifest_smoke_test.gd
godot --headless --path . --script res://tests/biome_obstacle_generation_smoke_test.gd
godot --headless --path . --script res://tests/zombie_environment_milestone_smoke_test.gd
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/player_dodge_gap_smoke_test.gd
```

## Regressione ISO-001 Milestone 6 - connessioni aperte tra biomi

QA visuale da eseguire con seed fisso a `1280x720` e `960x540`, attraversando
almeno otto regioni con tastiera e joypad.

- Verificare che ogni passaggio aperto mostri un gate allineato al varco lasciato
  tra i muri di bordo, non sovrapposto ai muri ne alle fall zone.
- Confermare che il gate sia largo quanto l'apertura del passaggio: passaggi piu
  larghi hanno gate piu largo, quelli stretti restano comunque leggibili.
- Verificare i passaggi nei quattro lati (nord, sud, est, ovest) e che la freccia
  del gate punti nel verso di attraversamento corretto.
- Confermare la differenza tematica del gate per `road`, `bridge`, `snow_pass`,
  `broken_gate` e `burned_road` senza dipendere da testo.
- Attraversare un gate e confermare che il party non venga teletrasportato a un
  punto di ingresso remoto (la camera/party resta vicino al varco).
- Confermare che entrare nel gate cambi regione una sola volta (nessuna doppia
  transizione) e che il terreno del passaggio resti coerente con il gate.

```text
godot --headless --path . --script res://tests/milestone_6_open_passage_smoke_test.gd
godot --headless --path . --script res://tests/open_passage_transition_smoke_test.gd
godot --headless --path . --script res://tests/region_streaming_smoke_test.gd
godot --headless --path . --script res://tests/biome_world_generation_smoke_test.gd
```

## Regressione ISO-001 Milestone 8 - megamappa multi-regione

QA visuale da eseguire con seed fisso a `1280x720` e `960x540`, attraversando
almeno otto regioni con ritorno alla regione precedente.

- Confermare che, oltre alla regione corrente giocabile, i territori vicini
  connessi siano visibili come ground attorno all'arena, posizionati nei lati
  corretti (nord/sud/est/ovest) e affiancati senza sovrapposizioni ne buchi.
- Verificare che i vicini siano solo sfondo: nessun nemico, cassa o hazard
  appare nelle regioni vicine; gli spawn restano nella regione corrente.
- Attraversare un passaggio e confermare che il set di regioni renderizzate si
  aggiorni (la nuova regione diventa corrente, i suoi vicini compaiono, le
  regioni fuori raggio spariscono).
- Tornare alla regione precedente e confermare che le casse gia aperte restino
  consumate (persistenza per regione invariata).
- Monitorare il frame time con i vicini renderizzati e griglia almeno `7x7`;
  annotare eventuale debito di performance (camera/spawn cross-regione restano
  follow-up).

```text
godot --headless --path . --script res://tests/milestone_8_multi_region_smoke_test.gd
godot --headless --path . --script res://tests/region_streaming_smoke_test.gd
godot --headless --path . --script res://tests/open_passage_transition_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
```

## Regressione ISO-001 Milestone 7 - grafo biomi completamente connesso

QA da eseguire in una run survival con il debug overlay biomi attivo
(`BiomeMapDebugOverlay`, toggle `F1`; vista grafo `F8`).

- Con l'overlay visibile, confermare la riga grafo: `connected:true`, regioni
  totali, numero edge (maggiore dello spanning tree) e `unreachable:0`.
- Confermare la riga regione: regione corrente, conteggio active regions
  (corrente + vicini caricati) e regioni non caricate.
- Premere `F8` e verificare che la vista grafo si nasconda/mostri senza
  interferire con HUD o gameplay.
- Attraversare alcune transizioni e confermare che active regions e regione
  corrente nell'overlay restino coerenti con la mappa esplorazione (`M`).
- Aprire la mappa esplorazione e confermare che le regioni `unknown` lontane non
  rivelino la topologia completa (fog rispettata).

```text
godot --headless --path . --script res://tests/milestone_7_graph_connectivity_smoke_test.gd
godot --headless --path . --script res://tests/world_graph_connectivity_smoke_test.gd
godot --headless --path . --script res://tests/exploration_map_smoke_test.gd
godot --headless --path . --script res://tests/biome_world_generation_smoke_test.gd
```

## Regressione ISO-001 Milestone 9 - mappa territori esplorati

QA mappa esplorazione (`M` / joypad `Back/Select/View`) a `1280x720`,
`1024x768` e `960x540`, in `default` e `high_contrast`.

- Aprire la mappa e confermare che regione corrente (oro), visitate, scoperte e
  cleared siano leggibili e distinguibili a tutte e tre le risoluzioni.
- Confermare che le regioni caricate come dati (active/streaming) mostrino il
  marker quadrato distinto dalla regione corrente.
- Verificare che i passaggi noti colleghino solo regioni visibili e che il loro
  colore rifletta il tipo (`road`/`bridge`/`snow_pass`/`broken_gate`/`burned_road`).
- Confermare che le regioni `unknown` lontane non rivelino la topologia completa.
- In `high_contrast` confermare bordi/marker rinforzati senza perdere leggibilita;
  in `reduced_motion` la mappa resta statica e leggibile.
- Aprire/chiudere la mappa durante survival con tastiera e joypad senza perdere
  il focus HUD.

```text
godot --headless --path . --script res://tests/exploration_map_smoke_test.gd
godot --headless --path . --script res://tests/region_streaming_smoke_test.gd
godot --headless --path . --script res://tests/open_passage_transition_smoke_test.gd
```

## Regressione Milestone 10.1 - contratto asset ambiente v7

QA documentale e smoke da eseguire prima di creare asset nuovi.

- Aprire `assets/environment/isometric/manifest.json` e confermare `version: 7`.
- Verificare che le sezioni `tile_sets`, `tile_variants`, `terrain_tiles`,
  `edge_tiles`, `void_tiles`, `object_scenes`, `passage_tiles`,
  `biome_asset_sets` e `fallback_policy` siano presenti.
- Confermare che `fallback_policy.implicit_fallback_allowed` resti `false` e
  che nessun asset esterno sia richiesto per il bootstrap.
- Per un ID terrain, un ostacolo, un bordo, un passaggio e `fall_zone`,
  verificare che il contratto normalizzato abbia `asset_path`, `status`,
  `biome_ids`, `anchor`, footprint/collisione, source, license, attribution e
  `fallback_path` quando l'asset e ancora assente.
- Confermare che lo status `needs_asset` non venga interpretato come arte
  finale: indica un path pianificato coperto da fallback tecnico.

```text
godot --headless --path . --import
godot --headless --path . --script res://tests/milestone_10_asset_manifest_v7_smoke_test.gd
godot --headless --path . --script res://tests/isometric_environment_manifest_smoke_test.gd
godot --headless --path . --script res://tests/isometric_biome_terrain_coverage_smoke_test.gd
```

## Regressione Milestone 10.2 - pipeline asset locale

QA documentale e filesystem da eseguire dopo modifiche al manifest v7.

- Eseguire il generatore in `--dry-run` e verificare che elenchi solo path sotto
  `assets/environment/isometric/`.
- Eseguire `--check` e confermare che tutti gli `asset_path` SVG dichiarati
  esistano.
- Verificare che le cartelle `tiles/`, `objects/`, `edges/`, `passages/` e
  `previews/` esistano con sottocartelle per biomi/categorie.
- Aprire un SVG tile, un oggetto, un edge, un void tile, un passaggio e una
  preview; devono contenere `data-generated-by`, `data-section` e `data-id`.
- Confermare che i file siano `snake_case` e non introducano binari pesanti o
  asset esterni.
- Confermare che `assets/ATTRIBUTION.md` tracci gli SVG generati internamente.

```text
godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --dry-run
godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check
godot --headless --path . --script res://tests/milestone_10_asset_pipeline_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_asset_manifest_v7_smoke_test.gd
godot --headless --path . --script res://tests/isometric_environment_manifest_smoke_test.gd
```

## Regressione Milestone 10.3 - tile layer persistente

QA visuale e runtime da eseguire dopo modifiche a ground, manifest v7 o layout
bioma.

- Avviare survival con seed fisso e confermare che il terreno visibile copra
  tutta la regione `200x200`, non solo il centro.
- Visitare o forzare i cinque biomi (`infected_plains`, `toxic_wastes`,
  `burning_fields`, `frozen_outskirts`, `drowned_marsh`) e acquisire screenshot
  a 1280x720 e 960x540.
- Verificare che floor base e varianti siano coerenti con la palette del bioma
  e restino stabili rigenerando lo stesso seed.
- Verificare che strade e passaggi siano integrati nel ground tile layer e che
  non appaiano piu come ovali `BiomeTerrainPatch` sopra il terreno.
- Verificare cliff/fall boundary: il bordo vicino al terreno usa
  `void_edge_near`, il fuori-mappa/esterno resta `void_depth`.
- Aprire il profiler o l'overlay debug e confermare assenza di 40.000 nodi
  tile: il ground deve essere un `BiomeTileLayer` chunked.

```text
godot --headless --path . --script res://tests/milestone_10_tile_layer_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_asset_manifest_v7_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_asset_pipeline_smoke_test.gd
godot --headless --path . --script res://tests/isometric_biome_terrain_coverage_smoke_test.gd
godot --headless --path . --script res://tests/zombie_environment_milestone_smoke_test.gd
godot --headless --path . --script res://tests/zombie_biome_transition_smoke_test.gd
```

## Regressione todo_roadmap Milestone 5 - dungeon ramificato, shop e biomi

QA da eseguire con almeno tre seed diversi, con tastiera e joypad.

- Avviare il dungeon (`F5`) e confermare che l'HUD mostri stanza, kind, credit,
  seed e la mappa percorso testuale.
- Attraversare fino a trovare una stanza con due uscite (scelta): confermare due
  portali con etichetta destinazione e che entrare in uno scelga quel percorso.
- Verificare con tre seed che il boss resti sempre raggiungibile qualunque ramo
  si scelga, e che la run non resti mai bloccata.
- Entrare in una combat room, eliminare i nemici e confermare che il clear
  sblocchi l'uscita e aggiunga run credit (HUD).
- Entrare nella shop room: confermare le offerte e il costo; con credit
  sufficienti l'acquisto genera il pickup (via DropSystem) e scala i credit; con
  credit insufficienti l'acquisto e rifiutato; un'offerta gia comprata non si
  ripete.
- Entrare nella rest room (se presente nel seed) e confermare la cura ai player.
- Sconfiggere il boss, completare la run e confermare il ritorno alla schermata
  risultati e poi al menu con tastiera e joypad.
- Confermare che lo shop NON modifichi il denaro party persistente del save.

```text
godot --headless --path . --script res://tests/dungeon_graph_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
godot --headless --path . --script res://tests/milestone_19_boss_registry_smoke_test.gd
```

## Regressione Milestone 9

- Il progetto parte con il menu visibile e nessuna modalita attiva.
- Il menu mostra livello, XP, denaro e ultima modalita.
- Tastiera e joypad possono selezionare survival, dungeon e tower defense.
- Il gameplay HUD appare dopo la selezione.
- `Esc` arresta la modalita corrente e torna al menu.
- `Continue` avvia l'ultima modalita salvata.
- Una variazione di XP o denaro aggiorna `user://savegame.json`.
- Riavviando il progetto, livello, XP, denaro e ultima modalita vengono ripristinati.
- Un save v1 viene caricato e riscritto nello schema corrente senza perdere
  progressione.
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
