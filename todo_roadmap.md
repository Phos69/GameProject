# TODO Roadmap Operativa

## Titolo e obiettivo generale

Questo documento converte la TODO esistente della repository in una roadmap
operativa ordinata, realistica e usabile da agenti successivi.

Le milestones sono pensate per essere eseguite una alla volta in modalita Goal:
ogni goal deve leggere questo file, lavorare solo sulla milestone richiesta,
rispettare i criteri di accettazione e aggiornare `TODO.md` solo a fine lavoro.

Questa roadmap non implementa feature. Serve a trasformare backlog, limiti noti,
follow-up e documentazione esistente in un piano eseguibile.

## Stato attuale sintetico

La repository contiene gia una base molto ampia:

- Godot 4.x con typed GDScript e struttura modulare.
- Modalita survival, dungeon e tower defense giocabili.
- Menu principale, Character Select RPG, pausa, Settings e risultati run.
- Multiplayer locale 1-4 player con input tastiera/joypad.
- Combat, health, drop, armi, projectile, melee temporaneo e boss condivisi.
- Revamp zombie Z1-Z12 completato: biomi, spawn camera-edge, hazard, casse,
  zombie tematici, status, encounter e HUD bioma.
- Motore procedurale seed-based e megamappa persistente `200x200` con grafo
  connesso, passaggi fisici, fall boundary, mappa esplorazione e dodge/gap.
- RPG Mode M1-M13 completata come primo pass: sette classi, armi, passive,
  super, XP, HUD e profili data-driven.
- Asset personaggi in stato `base_complete` secondo `assets/characters/index.json`.
- Suite smoke estesa e build Windows gia esportabile.

Restano aperti o incompleti:

- Warning di cleanup headless `ObjectDB/resources still in use` e possibile
  access violation intermittente in shutdown.
- QA manuale reale dei mini-eventi bioma e tuning di frequenza, reward e status.
- QA di attraversamento continuo della megamappa e streaming selettivo delle
  regioni lontane.
- Sostituzione progressiva di placeholder ambientali isometrici tramite
  `assets/environment/isometric/manifest.json`.
- Espansione dungeon oltre il percorso lineare: diramazioni, shop, biomi,
  scelta stanza, mappa e persistenza della run.
- Asset definitivi, VFX separati, animazioni e pulizia qualitativa dei sette
  personaggi RPG.
- Tuning melee e super starter dopo playtest.
- Polish di Mago, Domatrice e Licantropo, incluso Briciola e trasformazione.
- Ulteriori boss, pattern avanzati, eventuale contenuto tower defense avanzato.
- Pass di bilanciamento/performance dopo playtest reali 2-4 player.
- Firma digitale della build Windows pubblica.
- Documentazione finale e pulizia del backlog storico.

Aree confuse o duplicate nella TODO:

- `Eliminare i warning di cleanup dei test headless` compare due volte con
  criteri simili: va trattato come una sola milestone tecnica.
- `Asset definitivi` compare come backlog generico, come asset ambiente
  isometrici e come asset personaggi RPG: va spezzato in milestone separate.
- Molte sezioni in `TODO.md` sono storiche e gia completate; non vanno
  riaperte, ma restano utili come contesto e criteri di regressione.
- L'indice asset personaggi dice `base_complete`, mentre alcune note parlano di
  placeholder SVG/procedurali o PNG mancanti: serve distinguere "base presente"
  da "qualita finale".
- Alcuni desiderata sono fuori dalla TODO stretta ma presenti in README,
  ROADMAP, GAME_DESIGN o ARCHITECTURE, per esempio firma build, boss futuri,
  upgrade tower defense e inventario armi.

## Aree tematiche

- Architettura core e pulizia tecnica: lifecycle test, shutdown headless,
  regressioni, streaming regioni e contratti tra sistemi.
- Menu, navigazione e UX: main menu, pausa, settings, risultati, focus joypad,
  Character Select e leggibilita a risoluzioni diverse.
- Selezione personaggi: flusso survival pre-run, slot player, profili RPG e
  fallback asset.
- Character design, sprite, animazioni e coerenza grafica: asset dei sette
  personaggi, VFX separati, weapon layer e checklist visuale RPG.
- Classi RPG, armi base, passive e super: tuning starter, polish classi
  avanzate, Briciola, trasformazione licantropo e super leggibili.
- Combattimento, hitbox, danni, status effect e bilanciamento: melee timing,
  knockback, hitstop percepito, status bioma e tuning malus.
- Zombie mode, spawn, ondate, casse e progressione partita: mini-eventi,
  encounter, reward, spawner camera-edge e wave director.
- Biomi, ostacoli, generazione isometrica e megamappa persistente: terrain
  `200x200`, fall boundary, passaggi aperti, manifest ambientale e asset
  isometrici.
- Esplorazione, grafo dei biomi, mappa territori e transizioni aperte:
  attraversamento continuo, stato esplorazione, seed e region streaming.
- Nemici specifici per bioma e incontri casuali: roster tematici, ambush,
  elite pack, cursed crate, hazard burst, survivor cache e mini-eventi.
- UI/HUD grafica: vita, ammo, XP, adrenalina, status, bioma, mappa, boss e
  leggibilita in default/high contrast/reduced motion.
- Save/load, persistenza, seed e riproducibilita: save v6, mondo persistente,
  stato regioni, casse aperte, encounter completati e seed debug.
- Dungeon e modalita secondarie: dungeon ramificato, shop, biomi dungeon,
  mappa percorso, tower defense avanzata e boss aggiuntivi.
- Test, debug, CI, QA e verifica commit: smoke headless, QA visuale, soak,
  build smoke, checklist manuali e loop shutdown.
- Documentazione e workflow agenti: aggiornamento coerente di README,
  ROADMAP, TODO, ARCHITECTURE, GAME_DESIGN, CHANGELOG e checklist.
- Packaging e distribuzione: export Windows, build smoke e firma digitale.

## Milestones ordinate

### Milestone 0 - Audit, consolidamento TODO e baseline tecnica

**Obiettivo**

Allineare backlog, documentazione e baseline test prima di nuove feature.

**Perche va fatta in questo ordine**

La TODO contiene molti blocchi completati e duplicati. Prima di aprire nuovi goal
serve una fotografia verificabile dello stato reale, altrimenti gli agenti
successivi rischiano di reimplementare sistemi gia presenti.

**Punti TODO coperti**

- Consolidamento TODO storica.
- Report baseline da `docs/latest_commit_validation_report.md`.
- Preparazione alla pulizia dei warning headless.

**File/cartelle probabilmente coinvolti**

- `TODO.md`
- `README.md`
- `ROADMAP.md`
- `CHANGELOG.md`
- `docs/latest_commit_validation_report.md`
- `docs/testing/manual_checklist.md`
- `tests/`

**Task concreti**

- Separare in `TODO.md` le sezioni completate dal backlog aperto.
- Accorpare i duplicati senza cancellare il contesto storico.
- Creare o aggiornare una tabella baseline con test essenziali e stato noto.
- Marcare i warning cleanup come debito unico tracciato.
- Annotare quali roadmap storiche sono completate e quali sono solo reference.

**Dipendenze da milestones precedenti**

Nessuna.

**Criteri di accettazione verificabili**

- `TODO.md` distingue chiaramente completato, aperto e follow-up.
- Il debito cleanup headless compare una sola volta.
- Ogni item aperto ha obiettivo, milestone collegata, sistemi, criterio e test.
- Nessuna feature gameplay viene implementata.

**Test manuali da eseguire**

- Revisione manuale di README, ROADMAP, TODO e report test.
- Verifica che nessun item aperto sia stato rimosso senza motivazione.

**Test automatici o script da aggiungere**

- Nessun test gameplay richiesto.
- Eventuale script di discovery test/documenti solo se gia coerente con il repo.

**Rischi tecnici**

- Trasformare un riordino documentale in refactor non richiesto.
- Perdere dettagli storici utili ai goal futuri.

**Prompt breve consigliato**

`Esegui Milestone 0 di todo_roadmap.md: consolida TODO e baseline tecnica, non implementare gameplay, rispetta i criteri di accettazione e aggiorna TODO.md solo a fine lavoro. Non iniziare milestone successive.`

### Milestone 1 - Stabilizzazione shutdown headless e lifecycle test

**Obiettivo**

Eliminare o isolare i warning di cleanup dei test headless e rendere affidabile
il teardown runtime.

**Perche va fatta in questo ordine**

Il problema e trasversale e puo mascherare regressioni future. Risolverlo prima
abbassa il rumore su tutte le milestone successive.

**Punti TODO coperti**

- `Eliminare i warning di cleanup dei test headless` in priorita alta.
- Duplicato in priorita bassa sullo stesso tema.
- Note in `docs/latest_commit_validation_report.md` su 34 test con cleanup warning.

**File/cartelle probabilmente coinvolti**

- `tests/`
- `game/main/`
- `game/modes/`
- `game/audio/`
- `game/projectiles/`
- `game/drops/`
- `game/debug/build_runtime_smoke.gd`

**Task concreti**

- Inventariare i test che lasciano `ObjectDB` o resources in uso.
- Identificare pattern di runner che non liberano root, audio, projectile,
  scene runtime, timer o risorse.
- Aggiungere helper di teardown riusabile nei test se necessario.
- Eseguire un loop di shutdown su scena principale e smoke prioritari.
- Documentare eventuali limiti specifici di Godot 4.6.3 se non eliminabili.

**Dipendenze da milestones precedenti**

Milestone 0 consigliata.

**Criteri di accettazione verificabili**

- I test prioritari terminano con exit code `0` e senza warning cleanup noti,
  oppure ogni warning residuo ha causa isolata e riproduzione documentata.
- 100 avvii/shutdown consecutivi della scena principale passano con exit code `0`.
- Il report aggiornato distingue bug del progetto da comportamento engine.

**Test manuali da eseguire**

- Avvio editor/scena principale e chiusura senza errori visibili.
- Verifica che audio, menu e survival non restino bloccati dopo retry/menu.

**Test automatici o script da aggiungere**

- Loop dedicato di shutdown headless.
- Regressione su smoke base: combat, survival, dungeon, tower defense, pause,
  RPG character select e biome mini events.

**Rischi tecnici**

- Godot potrebbe mantenere warning intermittenti non completamente risolvibili.
- Correzioni di teardown troppo aggressive possono nascondere nodi ancora usati.

**Prompt breve consigliato**

`Esegui Milestone 1 di todo_roadmap.md: stabilizza shutdown headless e cleanup test, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 2 - QA mini-eventi bioma, status e encounter

**Obiettivo**

Validare con gameplay reale ritmo, reward e leggibilita di `toxic_leak`,
`fire_breakout`, `whiteout` e `marsh_emergence`, poi tarare frequenze e malus.

**Perche va fatta in questo ordine**

I mini-eventi esistono gia e hanno smoke test. Prima di aggiungere nuovi
contenuti zombie serve verificare il comportamento reale e ridurre il rischio
di frustrazione.

**Punti TODO coperti**

- QA manuale mini-eventi bioma.
- Follow-up su placeholder status/encounter, frequenze encounter e durata/danno
  dei malus.

**File/cartelle probabilmente coinvolti**

- `game/modes/zombie/random_encounter_system.gd`
- `game/modes/zombie/hazard_system.gd`
- `game/modes/zombie/hazards/`
- `game/modes/zombie/wave_director.gd`
- `game/ui/hud_manager.gd`
- `game/ui/player_hud_card.gd`
- `tests/biome_mini_events_smoke_test.gd`
- `tests/random_encounter_smoke_test.gd`

**Task concreti**

- Preparare una checklist QA 10 wave con seed fisso.
- Verificare ogni mini-evento in default, high contrast e reduced motion.
- Raccogliere valori osservati: durata, danno, reward, spawn extra e leggibilita.
- Tarare frequenza encounter, cooldown, reward e intensita status se necessario.
- Aggiornare test o checklist se il tuning cambia.

**Dipendenze da milestones precedenti**

Milestone 1 consigliata per ridurre rumore nei test.

**Criteri di accettazione verificabili**

- Ogni mini-evento resta evitabile e leggibile.
- Nessun evento blocca passaggi, casse o spawn validi.
- Reward e rischio sono proporzionati per bioma e wave.
- HUD/status spiega il malus senza coprire HP, ammo o XP.

**Test manuali da eseguire**

- QA survival 10 wave con seed fisso.
- Screenshot o video dei quattro mini-eventi.
- Prova con almeno due player locali se possibile.

**Test automatici o script da aggiungere**

- Estendere `tests/biome_mini_events_smoke_test.gd` con casi tuning.
- Aggiungere un test di cooldown/frequenza se non coperto.

**Rischi tecnici**

- Tuning manuale senza telemetria puo produrre valori soggettivi.
- Eventi rari possono essere difficili da riprodurre senza seed/override debug.

**Prompt breve consigliato**

`Esegui Milestone 2 di todo_roadmap.md: valida e tara mini-eventi bioma/status/encounter, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 3 - QA attraversamento megamappa e streaming regioni

**Obiettivo**

Validare l'attraversamento continuo della megamappa e implementare il caricamento
controllato di regione corrente e vicini, lasciando le regioni lontane come dati.

**Perche va fatta in questo ordine**

Lo streaming e un follow-up architetturale sul sistema gia completato. Va
affrontato prima degli asset ambientali definitivi, per evitare di rifinire
oggetti che poi cambiano lifecycle.

**Punti TODO coperti**

- QA manuale di attraversamento continuo e leggibilita isometrica.
- Streaming visuale delle regioni lontane.

**File/cartelle probabilmente coinvolti**

- `game/world/world_runtime.gd`
- `game/world/`
- `game/modes/zombie/zombie_mode_controller.gd`
- `game/modes/zombie/biome_transition_system.gd`
- `game/modes/zombie/terrain_generator.gd`
- `game/modes/zombie/obstacle_system.gd`
- `game/modes/zombie/resource_crate_system.gd`
- `game/modes/zombie/hazard_system.gd`
- `game/ui/exploration_map_panel.gd`
- `game/saves/save_manager.gd`

**Task concreti**

- Eseguire QA manuale con seed fisso attraversando almeno otto regioni.
- Definire il contratto runtime di `active_regions`.
- Salvare stato runtime per regione: casse aperte, encounter completati,
  ostacoli distrutti e regioni visitate.
- Caricare regione corrente e N/E/S/W, scaricando le regioni lontane.
- Verificare che transizioni aperte, spawn e hazard restino coerenti.

**Dipendenze da milestones precedenti**

Milestone 0 e 1 consigliate.

**Criteri di accettazione verificabili**

- I player attraversano otto regioni senza teletrasporti percepiti.
- Le regioni lontane non restano istanziate.
- Rientrando in una regione, casse gia aperte e encounter completati non
  ricompaiono.
- La mappa esplorazione e il save v6 restano coerenti.

**Test manuali da eseguire**

- Checklist 20 minuti survival con seed fisso.
- Screenshot mappa e passaggi aperti in default/high contrast.
- Verifica dodge su gap piccolo in regioni diverse.

**Test automatici o script da aggiungere**

- Smoke headless load/unload regioni.
- Profiling manuale con griglia almeno `7x7`.
- Regressioni: world graph, persistent world, open passage, exploration map,
  survival wave.

**Rischi tecnici**

- Lifecycle di regioni puo duplicare o perdere nodi runtime.
- Persistenza parziale puo rompere riproducibilita seed se salva troppo layout.

**Prompt breve consigliato**

`Esegui Milestone 3 di todo_roadmap.md: valida attraversamento megamappa e implementa streaming regioni, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 4 - Asset isometrici ambiente e ostacoli coerenti

**Obiettivo**

Sostituire progressivamente i placeholder ambientali con oggetti isometrici
coerenti, mantenendo collisioni, footprint, sorting e fallback.

**Perche va fatta in questo ordine**

Dopo lo streaming, gli asset possono agganciarsi al lifecycle corretto delle
regioni. Prima sarebbe piu facile creare duplicazioni o assunzioni sbagliate.

**Punti TODO coperti**

- Pass asset isometrici ambiente.
- Asset definitivi generici, per la parte ambiente.
- Known Visual TODOs su placeholder procedurali.

**File/cartelle probabilmente coinvolti**

- `assets/environment/isometric/manifest.json`
- `assets/README.md`
- `assets/ATTRIBUTION.md`
- `game/modes/zombie/biome_obstacle.gd`
- `game/modes/zombie/terrain_generator.gd`
- `game/modes/zombie/obstacle_system.gd`
- `game/modes/zombie/biome_fall_zone.gd`
- `game/visuals/`

**Task concreti**

- Priorizzare categorie: case, muretti, auto, casse, barili, rocce, tubi,
  cisterne, ponti, scarpate.
- Per ogni categoria definire visual scene, collision shape, shadow, sort offset
  e footprint tiles.
- Mantenere fallback procedurale se asset manca.
- Aggiornare manifest e attribuzioni.
- Verificare silhouette, contrasto e high contrast.

**Dipendenze da milestones precedenti**

Milestone 3 consigliata.

**Criteri di accettazione verificabili**

- Ogni oggetto convertito ha visual, collisione e footprint coerenti.
- Lo sorting Y/isometrico non copre player, zombie o pickup in modo errato.
- Gli oggetti grandi creano corridoi leggibili e non muri casuali.
- Nessun asset esterno diventa obbligatorio per il bootstrap.

**Test manuali da eseguire**

- QA visuale a 1280x720 e 960x540.
- Verifica default, reduced motion e high contrast.
- Traversata di almeno tre biomi con ostacoli convertiti.

**Test automatici o script da aggiungere**

- Smoke collisioni/footprint per categoria convertita.
- Test manifest che segnala asset mancanti o status incoerenti.

**Rischi tecnici**

- Asset visuali possono non corrispondere alla collisione.
- Licenze non tracciate possono bloccare una build pubblica.

**Prompt breve consigliato**

`Esegui Milestone 4 di todo_roadmap.md: converti asset ambiente isometrici secondo manifest e pipeline, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 5 - Dungeon ramificato, shop e biomi dedicati

**Obiettivo**

Espandere il dungeon lineare in una modalita con diramazioni, scelta stanza,
shop, biomi dedicati e una mappa percorso minima.

**Perche va fatta in questo ordine**

Il dungeon e una delle principali voci non completate in README, ROADMAP e TODO.
Va dopo la stabilizzazione core per poter riusare world/asset/test senza
duplicare sistemi survival.

**Punti TODO coperti**

- Espandere il dungeon oltre il percorso lineare.
- Dungeon ramificati, shop, biomi e selezione stanza.
- Known Visual TODO su biomi dungeon.

**File/cartelle probabilmente coinvolti**

- `game/procedural/dungeon_generator.gd`
- `game/modes/dungeon/dungeon_mode.gd`
- `game/modes/dungeon/dungeon_room.gd`
- `game/modes/dungeon/dungeon_room.tscn`
- `game/ui/hud_manager.gd`
- `game/ui/`
- `game/bosses/`
- `game/drops/`
- `tests/dungeon_smoke_test.gd`

**Task concreti**

- Estendere il generatore con nodi, edge, rami opzionali e percorso garantito al
  boss.
- Aggiungere almeno una scelta reale tra due stanze per seed selezionati.
- Definire room type: combat, loot, shop, rest/utility, boss.
- Preparare un bioma dungeon minimo usando palette e ostacoli esistenti.
- Aggiungere UI mappa dungeon o scelta stanza.
- Integrare shop con valuta/run credit senza rompere progressione party.

**Dipendenze da milestones precedenti**

Milestone 1 consigliata. Milestone 4 utile se si usano asset isometrici.

**Criteri di accettazione verificabili**

- Almeno un seed produce una scelta reale tra due stanze.
- Il percorso al boss resta sempre raggiungibile.
- Shop e loot room non duplicano `DropSystem` o progressione.
- La run termina correttamente dopo boss e ritorna ai risultati.

**Test manuali da eseguire**

- Checklist dungeon con tre seed diversi.
- Test scelta stanza, shop, boss e ritorno menu con tastiera/joypad.

**Test automatici o script da aggiungere**

- Estendere `tests/dungeon_smoke_test.gd` su seed multipli.
- Aggiungere smoke per grafo dungeon con branch e shop.

**Rischi tecnici**

- Confondere dungeon graph con megamappa survival.
- Shop e inventario possono allargare troppo lo scope se non limitati.

**Prompt breve consigliato**

`Esegui Milestone 5 di todo_roadmap.md: espandi dungeon con diramazioni, shop e biomi dedicati, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 6 - Asset definitivi e animazioni personaggi RPG

**Obiettivo**

Portare i sette personaggi RPG da `base_complete` a un pass qualitativo
coerente, con VFX separati, animazioni pulite e asset data-driven.

**Perche va fatta in questo ordine**

Dopo avere stabilizzato ambienti e modalita, il pass personaggi puo concentrarsi
su leggibilita e coerenza senza cambiare gameplay.

**Punti TODO coperti**

- Asset definitivi personaggi RPG.
- Asset definitivi generici, per la parte personaggi.
- Checklist `docs/rpg_character_visual_checklist.md`.

**File/cartelle probabilmente coinvolti**

- `assets/characters/`
- `assets/characters/index.json`
- `game/rpg/characters/*.tres`
- `game/rpg/rpg_character_data.gd`
- `game/visuals/player_visual.gd`
- `game/ui/player_hud_card.gd`
- `game/ui/character_select_card.gd`
- `docs/rpg_character_visual_checklist.md`

**Task concreti**

- Definire target qualita per portrait HUD/full, gameplay sprite, sprite sheet,
  weapon layer, passive icon, super icon e VFX.
- Chiarire status `base_complete` vs `final_quality`.
- Rifinire un personaggio alla volta, partendo da `ranger_quality_pass` o dal
  personaggio indicato dal manifest.
- Validare idle, run, attack, reload, hurt, death e super.
- Aggiornare manifest, profili `.tres`, attribuzioni e checklist.

**Dipendenze da milestones precedenti**

Milestone 0 consigliata. Milestone 4 utile per coerenza ambientale.

**Criteri di accettazione verificabili**

- Ogni personaggio ha asset configurati dai campi `RpgCharacterData`.
- Weapon layer e VFX restano separati dal corpo.
- Character Select, HUD e gameplay usano gli stessi dati senza fallback
  incoerenti.
- Nessun asset esterno privo di licenza entra nel repo.

**Test manuali da eseguire**

- Checklist RPG a 1280x720, 1024x768 e 960x540.
- Survival con i sette personaggi, almeno una wave per ciascuno.

**Test automatici o script da aggiungere**

- Estendere `tests/character_select_ui_smoke_test.gd` per path asset.
- Smoke asset manifest personaggi e fallback.
- Regressione `tests/milestone_rpg_13_new_classes_smoke_test.gd`.

**Rischi tecnici**

- Asset definitivi possono introdurre binari pesanti o problemi import.
- Rifinitura visuale puo diventare troppo ampia se non limitata a un set per goal.

**Prompt breve consigliato**

`Esegui Milestone 6 di todo_roadmap.md: rifinisci asset e animazioni personaggi RPG senza cambiare gameplay, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 7 - Tuning melee, super starter e classi RPG avanzate

**Obiettivo**

Playtestare e rifinire timing melee, knockback, hitstop percepito, leggibilita
super starter e polish di Mago, Domatrice e Licantropo.

**Perche va fatta in questo ordine**

Gli asset e le animazioni devono esistere o essere almeno stabili prima di
tuning fine su timing percepito e feedback.

**Punti TODO coperti**

- Tuning melee RPG e super.
- Polish classi RPG avanzate.
- Bilanciamento e leggibilita delle super.

**File/cartelle probabilmente coinvolti**

- `game/weapons/`
- `game/weapons/melee_attack.gd`
- `game/rpg/rpg_player_component.gd`
- `game/rpg/rpg_super_resolver.gd`
- `game/rpg/companions/briciola_companion.gd`
- `game/visuals/gameplay_effects.gd`
- `game/visuals/player_visual.gd`
- `tests/rpg_melee_attack_resolution_smoke_test.gd`
- `tests/milestone_rpg_13_new_classes_smoke_test.gd`

**Task concreti**

- Definire metriche di feeling: wind-up, active window, recovery, knockback,
  hitstop e leggibilita.
- Tuning starter: ascia rischiosa/potente, spada controllata/difensiva, arco e
  pistola leggibili a distanza.
- Rifinire super: Pioggia di Frecce, Scarica Finale, Terremoto di Sangue,
  Lama Fantasma.
- Rifinire Mago, Domatrice e Licantropo: telegraph, Briciola, frenzy,
  trasformazione e recovery.
- Aggiornare smoke e checklist.

**Dipendenze da milestones precedenti**

Milestone 6 consigliata.

**Criteri di accettazione verificabili**

- Ogni starter ha un rischio/beneficio percepibile.
- Le super sono riconoscibili a colpo d'occhio in survival.
- Briciola aiuta senza giocare da solo e non blocca Nina.
- Notte Bestiale termina sempre con recovery leggibile.
- Nessuna modifica rompe projectile/melee split.

**Test manuali da eseguire**

- QA survival con quattro starter a 1280x720 e 960x540.
- QA con Mago, Domatrice e Licantropo per almeno cinque wave.
- Prova con due player per Briciola e trasformazione.

**Test automatici o script da aggiungere**

- Estendere `tests/rpg_melee_attack_resolution_smoke_test.gd`.
- Estendere `tests/milestone_rpg_13_new_classes_smoke_test.gd`.
- Aggiungere smoke per recovery super se non presente.

**Rischi tecnici**

- Tuning puo toccare health/combat/player controller e richiede regressioni.
- Super con targeting automatico possono diventare troppo dominanti.

**Prompt breve consigliato**

`Esegui Milestone 7 di todo_roadmap.md: tara melee, super starter e classi RPG avanzate, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 8 - UI, HUD, audio e polish UX trasversale

**Obiettivo**

Rifinire leggibilita di menu, HUD, Character Select, status, audio e feedback
senza cambiare regole di gioco.

**Perche va fatta in questo ordine**

Conviene fare polish UX dopo i principali pass contenutistici RPG/bioma, cosi
HUD e feedback possono coprire stati reali e non provvisori.

**Punti TODO coperti**

- Known Visual TODOs su menu e selezione modalita.
- Asset audio definitivi o SFX sostituibili oltre i placeholder procedurali.
- HUD leggibile e grafico nella definizione di completato.

**File/cartelle probabilmente coinvolti**

- `game/ui/`
- `game/audio/`
- `assets/audio/`
- `game/visuals/`
- `game/settings/`
- `docs/testing/manual_checklist.md`

**Task concreti**

- Verificare menu, pausa, risultati e Character Select con controller reale.
- Rifinire HUD status, bioma, boss, ammo, adrenalina e mappa esplorazione.
- Collegare eventuali SFX esterni opzionali mantenendo fallback procedurali.
- Aggiornare checklist audio/visuale e attribution.
- Garantire default, reduced motion e high contrast.

**Dipendenze da milestones precedenti**

Milestones 2, 6 e 7 consigliate.

**Criteri di accettazione verificabili**

- Informazioni critiche leggibili senza testo piccolo.
- Focus joypad sempre visibile e coerente.
- Nessun SFX esterno obbligatorio per il bootstrap.
- Audio critico resta udibile con quattro player e boss wave.

**Test manuali da eseguire**

- QA menu/Character Select/Settings a 1280x720, 1024x768 e 960x540.
- QA survival con quattro player e molti effetti.
- Checklist cuffie/speaker/volume basso.

**Test automatici o script da aggiungere**

- Estendere `tests/character_select_ui_smoke_test.gd`.
- Regressione `tests/pause_settings_smoke_test.gd`.
- Regressione `tests/milestone_18_audio_mix_smoke_test.gd`.

**Rischi tecnici**

- Il polish UI puo introdurre layout fragili su aspect ratio stretti.
- Asset audio senza gestione priorita possono saturare il mix.

**Prompt breve consigliato**

`Esegui Milestone 8 di todo_roadmap.md: rifinisci UI, HUD, audio e UX senza cambiare gameplay, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 9 - Boss aggiuntivi e pattern avanzati

**Obiettivo**

Espandere il registro boss con ulteriori boss o pattern avanzati mantenendo il
contratto condiviso tra modalita.

**Perche va fatta in questo ordine**

Dopo polish UX e combat RPG, i nuovi pattern possono usare feedback, telegraph e
HUD ormai stabilizzati.

**Punti TODO coperti**

- Ulteriori boss e pattern avanzati.
- Evoluzione boss citata in README/GAME_DESIGN.

**File/cartelle probabilmente coinvolti**

- `game/bosses/`
- `game/visuals/`
- `game/projectiles/`
- `game/weapons/`
- `game/drops/`
- `game/ui/hud_manager.gd`
- `tests/boss_smoke_test.gd`
- `tests/milestone_19_boss_registry_smoke_test.gd`

**Task concreti**

- Decidere se aggiungere un nuovo boss o espandere pattern di boss esistenti.
- Definire compatibilita per survival, dungeon e tower defense.
- Aggiungere telegraph distinti e drop coerenti.
- Aggiornare registry, HUD, audio e test.
- Evitare pattern che applicano danno senza warning.

**Dipendenze da milestones precedenti**

Milestone 8 consigliata.

**Criteri di accettazione verificabili**

- Boss richiedibile per ID senza cambiare i chiamanti.
- Pattern hanno warning leggibile e nessun danno durante telegraph.
- Drop e ricompense usano `DropSystem`.
- Modalita incompatibili rifiutano il boss in modo tipizzato.

**Test manuali da eseguire**

- QA boss in survival e dungeon.
- QA telegraph con 2-4 player.

**Test automatici o script da aggiungere**

- Smoke nuovo boss o pattern.
- Regressione boss registry e boss smoke.

**Rischi tecnici**

- Pattern complessi possono duplicare logica boss esistente.
- Nuovi drop possono richiedere inventario se non limitati.

**Prompt breve consigliato**

`Esegui Milestone 9 di todo_roadmap.md: aggiungi boss o pattern avanzati mantenendo BossSystem condiviso, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 10 - Tower defense avanzata e sistemi secondari

**Obiettivo**

Pianificare e implementare un'espansione controllata della tower defense:
percorsi multipli, upgrade, vendita, riparazione e nuovi tipi torre, se ancora
prioritari dopo dungeon/survival.

**Perche va fatta in questo ordine**

La tower defense non e indicata come priorita alta nella TODO attuale, ma i
limiti sono documentati. Deve venire dopo le modalita principali e i sistemi
core.

**Punti TODO coperti**

- Limiti futuri di tower defense in GAME_DESIGN e ARCHITECTURE.
- Backlog trasversale di ROADMAP_VISUAL_GAMEPLAY.

**File/cartelle probabilmente coinvolti**

- `game/modes/tower_defense/`
- `game/visuals/defense_tower_visual.gd`
- `game/weapons/`
- `game/ui/hud_manager.gd`
- `tests/tower_defense_smoke_test.gd`

**Task concreti**

- Decidere lo scope minimo: uno tra upgrade, vendita, riparazione o nuovi tipi
  torre.
- Estendere manager e HUD senza mischiare crediti run con denaro party.
- Mantenere `EnemySystem`, `ProjectileSystem` e `BossSystem` condivisi.
- Aggiungere test smoke dedicato allo scope scelto.

**Dipendenze da milestones precedenti**

Milestone 1 consigliata. Milestone 9 opzionale se si usano boss avanzati.

**Criteri di accettazione verificabili**

- La tower defense resta giocabile e non duplica sistemi combat.
- Ogni nuova azione ha costo, feedback e stato HUD chiari.
- Retry/menu puliscono torri, crediti e nemici senza residui.

**Test manuali da eseguire**

- QA tower defense 5 wave con costruzione e feature scelta.
- Test joypad/tastiera su slot costruzione.

**Test automatici o script da aggiungere**

- Estendere `tests/tower_defense_smoke_test.gd`.
- Aggiungere smoke upgrade/sell/repair se implementati.

**Rischi tecnici**

- Espansione tower defense puo competere con priorita survival/dungeon.
- Upgrade possono richiedere UI complessa se non limitati.

**Prompt breve consigliato**

`Esegui Milestone 10 di todo_roadmap.md: espandi tower defense con uno scope minimo e verificabile, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 11 - Bilanciamento, performance e playtest end-to-end

**Obiettivo**

Affinare bilanciamento e performance dopo playtest reali, coprendo survival,
dungeon, tower defense, RPG, biomi e boss.

**Perche va fatta in questo ordine**

Ha senso solo dopo aver consolidato contenuti e polish principali. Prima il
tuning rischia di essere invalidato da modifiche successive.

**Punti TODO coperti**

- Ulteriori pass di bilanciamento.
- Affinare bilanciamento e performance del revamp zombie dopo playtest reali.
- Ampliare i test automatici.
- Definition of complete su gameplay base, zombie mode, HUD e personaggi.

**File/cartelle probabilmente coinvolti**

- `tests/`
- `game/modes/`
- `game/rpg/`
- `game/weapons/`
- `game/enemies/`
- `game/bosses/`
- `game/visuals/`
- `docs/testing/manual_checklist.md`

**Task concreti**

- Definire matrice playtest: 1, 2 e 4 player; tastiera e joypad; tre risoluzioni.
- Raccogliere dati su DPS, time-to-kill, danno subito, risorse e durata wave.
- Tarare valori data-driven prima di cambiare controller.
- Aggiungere smoke mancanti per sistemi condivisi critici.
- Eseguire profiling con wave affollate e boss.

**Dipendenze da milestones precedenti**

Milestones 2-10 consigliate in base al contenuto incluso.

**Criteri di accettazione verificabili**

- Survival 10 wave e soak 10 minuti restano stabili.
- Ogni classe RPG ha un motivo chiaro per essere scelta.
- Biomi avanzati sono piu pericolosi ma non frustranti.
- Frame time resta nel target documentato o il debito e tracciato.
- La suite smoke principale passa.

**Test manuali da eseguire**

- Playtest 20 minuti survival con 1-4 player.
- Dungeon completo con almeno tre seed.
- Tower defense 5 wave.
- Build smoke reale se disponibile.

**Test automatici o script da aggiungere**

- Estendere smoke su health, wave, save/load e lifecycle.
- Profiling script o test performance ripetibile.
- Regressione completa dei test elencati in README.

**Rischi tecnici**

- Bilanciamento puo diventare soggettivo senza metriche.
- Ottimizzazioni premature possono complicare sistemi leggibili.

**Prompt breve consigliato**

`Esegui Milestone 11 di todo_roadmap.md: fai bilanciamento, performance e playtest end-to-end, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 12 - Packaging, firma digitale e release readiness

**Obiettivo**

Preparare la build pubblica Windows: export ripetibile, build smoke, asset
attribuiti e firma digitale dell'eseguibile.

**Perche va fatta in questo ordine**

La firma e la release vanno fatte quando contenuti, test e documentazione sono
stabili, non mentre il gameplay cambia ancora.

**Punti TODO coperti**

- Firma digitale dell'eseguibile Windows.
- Build/export e release readiness in README/ROADMAP.
- Licenze asset e attribution.

**File/cartelle probabilmente coinvolti**

- `export_presets.cfg`
- `build/`
- `assets/ATTRIBUTION.md`
- `assets/README.md`
- `README.md`
- `docs/latest_commit_validation_report.md`
- `game/debug/build_runtime_smoke.gd`

**Task concreti**

- Verificare export release e export pack.
- Verificare esclusioni `tests/` e `build/` dal pacchetto.
- Eseguire build smoke.
- Documentare certificato, timestamping e processo di firma.
- Firmare EXE se certificato disponibile.
- Aggiornare README con istruzioni release.

**Dipendenze da milestones precedenti**

Milestone 11 consigliata.

**Criteri di accettazione verificabili**

- EXE/PCK generati da checkout pulito.
- Build smoke exit code `0`.
- Attribuzioni asset complete.
- EXE firmato, oppure blocco documentato se il certificato non e disponibile.

**Test manuali da eseguire**

- Avvio build su Windows con controller e audio.
- Menu, Character Select, survival start e ritorno menu.

**Test automatici o script da aggiungere**

- Script documentato per export e build smoke.
- Verifica firma se disponibile nella toolchain locale.

**Rischi tecnici**

- Certificato di firma non disponibile nell'ambiente.
- Asset o import mancanti possono rompere build pulita.

**Prompt breve consigliato**

`Esegui Milestone 12 di todo_roadmap.md: prepara packaging, build smoke e firma Windows, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

### Milestone 13 - Documentazione finale e workflow di iterazione

**Obiettivo**

Chiudere la TODO critica, aggiornare documentazione e lasciare un workflow
chiaro per futuri goal.

**Perche va fatta in questo ordine**

La documentazione finale deve riflettere il sistema completato, non un piano
intermedio.

**Punti TODO coperti**

- Documentazione e workflow agenti.
- Definition of complete.
- Pulizia backlog e aggiornamento README.

**File/cartelle probabilmente coinvolti**

- `README.md`
- `ROADMAP.md`
- `TODO.md`
- `CHANGELOG.md`
- `ARCHITECTURE.md`
- `GAME_DESIGN.md`
- `docs/`
- `prompts/`

**Task concreti**

- Aggiornare README con stato reale e comandi test correnti.
- Aggiornare ROADMAP marcando milestone completate o rinviate.
- Ridurre TODO a backlog reale e decisioni aperte.
- Aggiornare ARCHITECTURE/GAME_DESIGN solo se i contratti sono cambiati.
- Aggiornare prompt operativi se il workflow Goal e cambiato.
- Creare un report finale di validazione.

**Dipendenze da milestones precedenti**

Milestones 0-12 secondo scope effettivamente eseguito.

**Criteri di accettazione verificabili**

- Nessun punto TODO critico aperto senza owner o decisione.
- README descrive correttamente avvio, test, build e stato.
- Documenti tecnici non contraddicono il codice.
- Prompt futuri sono autonomi e non chiedono di implementare milestone gia chiuse.

**Test manuali da eseguire**

- Revisione incrociata README/TODO/ROADMAP/ARCHITECTURE/GAME_DESIGN.
- Avvio principale e build smoke se la release e nello scope.

**Test automatici o script da aggiungere**

- Nessun test gameplay obbligatorio.
- Eventuale script di link/check documentale solo se semplice.

**Rischi tecnici**

- Aggiornare troppi documenti puo introdurre incongruenze.
- Chiudere TODO senza criterio puo nascondere decisioni non prese.

**Prompt breve consigliato**

`Esegui Milestone 13 di todo_roadmap.md: chiudi documentazione e workflow finale, leggi todo_roadmap.md, rispetta i criteri, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

## Prompt Goal riutilizzabili

Usare questi prompt uno alla volta.

1. `Esegui Milestone 0 di todo_roadmap.md. Leggi todo_roadmap.md e i documenti indicati, consolida TODO e baseline tecnica, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
2. `Esegui Milestone 1 di todo_roadmap.md. Leggi todo_roadmap.md, stabilizza shutdown headless e cleanup test, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
3. `Esegui Milestone 2 di todo_roadmap.md. Leggi todo_roadmap.md, valida e tara mini-eventi bioma/status/encounter, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
4. `Esegui Milestone 3 di todo_roadmap.md. Leggi todo_roadmap.md, valida attraversamento megamappa e implementa streaming regioni, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
5. `Esegui Milestone 4 di todo_roadmap.md. Leggi todo_roadmap.md, converti asset ambiente isometrici secondo manifest e pipeline, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
6. `Esegui Milestone 5 di todo_roadmap.md. Leggi todo_roadmap.md, espandi dungeon con diramazioni, shop e biomi dedicati, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
7. `Esegui Milestone 6 di todo_roadmap.md. Leggi todo_roadmap.md, rifinisci asset e animazioni personaggi RPG senza cambiare gameplay salvo integrazione asset, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
8. `Esegui Milestone 7 di todo_roadmap.md. Leggi todo_roadmap.md, tara melee, super starter e classi RPG avanzate, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
9. `Esegui Milestone 8 di todo_roadmap.md. Leggi todo_roadmap.md, rifinisci UI, HUD, audio e UX senza cambiare regole gameplay, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
10. `Esegui Milestone 9 di todo_roadmap.md. Leggi todo_roadmap.md, aggiungi boss o pattern avanzati mantenendo BossSystem condiviso, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
11. `Esegui Milestone 10 di todo_roadmap.md. Leggi todo_roadmap.md, espandi tower defense con uno scope minimo e verificabile, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
12. `Esegui Milestone 11 di todo_roadmap.md. Leggi todo_roadmap.md, fai bilanciamento, performance e playtest end-to-end, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
13. `Esegui Milestone 12 di todo_roadmap.md. Leggi todo_roadmap.md, prepara packaging, build smoke e firma Windows, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`
14. `Esegui Milestone 13 di todo_roadmap.md. Leggi todo_roadmap.md, chiudi documentazione e workflow finale, rispetta i criteri di accettazione, aggiorna TODO.md solo a fine lavoro e non iniziare milestone successive.`

## Ordine consigliato di esecuzione

1. Milestone 0 - Audit, consolidamento TODO e baseline tecnica.
2. Milestone 1 - Stabilizzazione shutdown headless e lifecycle test.
3. Milestone 2 - QA mini-eventi bioma, status e encounter.
4. Milestone 3 - QA attraversamento megamappa e streaming regioni.
5. Milestone 4 - Asset isometrici ambiente e ostacoli coerenti.
6. Milestone 5 - Dungeon ramificato, shop e biomi dedicati.
7. Milestone 6 - Asset definitivi e animazioni personaggi RPG.
8. Milestone 7 - Tuning melee, super starter e classi RPG avanzate.
9. Milestone 8 - UI, HUD, audio e polish UX trasversale.
10. Milestone 9 - Boss aggiuntivi e pattern avanzati.
11. Milestone 10 - Tower defense avanzata e sistemi secondari.
12. Milestone 11 - Bilanciamento, performance e playtest end-to-end.
13. Milestone 12 - Packaging, firma digitale e release readiness.
14. Milestone 13 - Documentazione finale e workflow di iterazione.

Milestones parallelizzabili:

- Milestone 2 puo procedere in parallelo con Milestone 6 se non si toccano HUD,
  status o player visual nello stesso momento.
- Milestone 4 e Milestone 6 possono procedere in parallelo per asset ambiente e
  personaggi, purche aggiornino manifest separati.
- Milestone 9 e Milestone 10 possono procedere in parallelo solo dopo Milestone
  1, se non condividono modifiche a `BossSystem`, HUD o projectile.

Milestones sequenziali:

- Milestone 0 prima di tutte.
- Milestone 1 prima di grandi espansioni o tuning esteso.
- Milestone 3 prima della parte piu profonda di Milestone 4.
- Milestone 6 prima di Milestone 7.
- Milestone 11 dopo le milestone contenutistiche che si vogliono includere nel
  bilanciamento.
- Milestone 12 e Milestone 13 alla fine.

## Punti ambigui e decisioni aperte

- Asset personaggi: `base_complete` significa asset base presente, non qualita
  finale. Serve decidere se il target finale richiede PNG, SVG testuali o una
  pipeline mista.
- Dungeon shop: va deciso se usa denaro party persistente, valuta di run o
  entrambi. La scelta impatta save/progressione.
- Tower defense avanzata: non e priorita nella TODO principale; va confermata
  prima di dedicarle un goal lungo.
- Nuovi boss: serve scegliere se il prossimo goal aggiunge un boss nuovo o
  espande pattern dei boss esistenti.
- Firma digitale: richiede certificato e toolchain esterna; se non disponibili,
  il goal deve documentare il blocco invece di simulare la firma.
- Test cleanup headless: se Godot 4.6.3 mantiene warning engine-level, bisogna
  decidere se considerarli accettabili con evidenza o bloccare la roadmap.

## Definizione di completato

La TODO puo essere considerata completata quando:

- non restano punti TODO critici aperti senza decisione;
- il gameplay base di survival, dungeon e tower defense funziona;
- la selezione personaggi e stabile con tastiera e joypad;
- i sette personaggi sono distinguibili per grafica e gameplay;
- melee, passive, super e classi avanzate sono bilanciati almeno come primo pass
  verificato;
- i biomi isometrici sono navigabili, leggibili e validati;
- la megamappa supporta attraversamento continuo, persistenza e streaming
  controllato;
- la zombie mode e giocabile per almeno 10 wave e 10 minuti senza bug bloccanti;
- HUD, status, mappa, ammo e adrenalina sono leggibili e grafici;
- dungeon avanzato ha almeno una diramazione reale, shop minimo e boss path
  garantito;
- warning cleanup test sono risolti o documentati come limite engine-level;
- test manuali e automatici richiesti sono documentati;
- README, ROADMAP, TODO, ARCHITECTURE, GAME_DESIGN e CHANGELOG sono aggiornati
  dove necessario;
- build Windows esportata e verificata, con firma digitale completata o blocco
  esterno documentato.
