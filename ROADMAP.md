# ROADMAP

## Milestone 0 - Setup repository e documentazione

Stato: completata.

- Repository Git inizializzato.
- Progetto Godot 4.x creato.
- Struttura cartelle creata.
- Documentazione iniziale creata.
- Regole IA definite in `AGENTS.md`.

## Milestone 1 - Movimento, joypad e camera

Stato: completata come prototipo minimo.

- Scena principale pseudo-isometrica.
- Player controllabile.
- Movimento fluido.
- Input joypad player 1.
- Fallback tastiera.
- Camera che segue il gruppo player.
- Struttura predisposta per multiplayer locale.

## Milestone 2 - Multiplayer locale

Stato: completata come prototipo minimo.

- Assegnazione deterministica device/slot per 1-4 player locali.
- Spawn e despawn dinamico dei player locali.
- Camera di gruppo con zoom dinamico gia condivisa tra i player attivi.
- HUD con conteggio player e slot attivi.
- Join/leave locale: `Start`/`Back` su joypad e `F2`-`F4` come fallback debug per slot 2-4.

## Milestone 3 - Sparo, armi, danni e vita

Stato: completata come prototipo minimo.

- Proiettili visibili con collisione su bersagli damageable.
- Danno applicato tramite `HealthSystem` e `HealthComponent`.
- Statistiche arma configurabili tramite `WeaponData`.
- Pistola base con caricatore, riserva munizioni e ricarica.
- Stato vita e munizioni per-player nell'HUD.
- Bersagli statici per verifica combat nella scena principale.
- Smoke test headless con due player locali.

## Milestone 4 - Nemici base e drop

Stato: completata come prototipo minimo.

- Nemico melee con stati idle, chase, attack e dead.
- Targeting del player vivo piu vicino con retarget dinamico.
- Attacco integrato con `HealthSystem`.
- Spawn, registro e segnali morte tramite `EnemySystem`.
- Loot table tipizzate e configurabili.
- Pickup in scena per XP, denaro, armi, munizioni e vita.
- XP e denaro condivisi; ricompense combat applicate al raccoglitore.
- Seconda arma prototipo equipaggiabile tramite drop.
- Smoke test headless con join/leave di due player.

## Milestone 5 - Zombie survival

Stato: completata come prototipo minimo.

- `SurvivalMode` registrata e avviata tramite `GameModeManager`.
- `WaveManager` con stati intermission, spawning, combat e reward.
- Spawn progressivo e aumento del numero di zombie.
- Scaling per ondata di vita, velocita e danno.
- Ricompense party di denaro, munizioni e cura.
- HUD con ondata, countdown, nemici rimasti e ricompensa.
- Compatibilita join/leave durante la run.
- Sconfitta quando tutti i player attivi sono morti.
- Boss wave ogni cinque ondate con richiesta al `BossSystem`.
- Smoke test headless su tre ondate.

## Milestone 6 - Boss system

Stato: completata come prototipo minimo.

- `Wave Warden` con targeting multiplayer e movimento a distanza.
- Fase 1 con raffiche mirate.
- Fase 2 sotto il 50% con raffiche mirate e radiali alternate.
- Proiettili ostili integrati con `HealthSystem`.
- Barra vita boss con nome, fase e valori.
- `BossSystem` con boss attivo, spawn centralizzato e notifica sconfitta.
- Drop speciale garantito `Wave Cannon`.
- Quinta ondata survival con due scorte e boss reale.
- Wave completata solo alla morte di scorte e boss.
- Smoke test headless boss con due player.

## Milestone 7 - Dungeon procedurale

Stato: completata come prototipo minimo.

- Layout deterministico da seed con celle uniche.
- Link sequenziali attraversabili tra le stanze.
- Start room, combat room, loot room e boss room.
- Scena stanza modulare con pareti e portale bloccabile.
- Spawn nemici e scaling crescente nelle stanze combat.
- Loot room con ricompense fisiche.
- Boss finale richiesto tramite `BossSystem`.
- HUD con seed, indice stanza, stato uscita e nemici rimasti.
- Hotkey debug per passare tra survival e dungeon.
- Smoke test headless su una run completa.

## Milestone 8 - Tower defense

Stato: completata come prototipo minimo.

- Arena tower defense dedicata e avviabile con `F6`.
- Macchina a stati delle ondate separata in `TowerDefenseWaveController`.
- Percorso fisso a waypoint condiviso da nemici e boss.
- Core da difendere con vita e condizione di sconfitta.
- Crediti di run, tre slot costruzione e costo torre.
- Input costruzione `E`/joypad `A` per ogni player locale.
- Torre automatica con targeting, range e proiettili condivisi.
- Ondate con spawn progressivo, scaling e ricompense crediti.
- Boss ogni cinque ondate tramite `BossSystem`.
- HUD con core, crediti, ondata e nemici rimasti.
- Smoke test headless su percorso, costruzione, torre, boss e sconfitta.

## Milestone 9 - Polish, salvataggi e packaging

Stato: completata come prototipo minimo.

- Save/load JSON versionato completato per progressione party e ultima modalita.
- Autosave progressione e validazione dei dati completati.
- Menu principale e selezione modalita completati.
- Ritorno al menu con arresto della modalita attiva completato.
- Feedback audio UI procedurale completato come placeholder minimo.
- Preset export Windows completato.
- Pacchetto PCK generato e avviato headless con successo.
- Template Windows Godot `4.6.3` installati e verificati tramite checksum ufficiale.
- Build Windows release generata e avviata con successo.
- Smoke test interno della build completato con exit code `0`.
- QA visuale completato su menu, focus joypad, avvio survival e ritorno al menu.
- Controller XInput reale e driver audio WASAPI rilevati durante il QA.
- Corretto `ui_accept` per confermare il menu con joypad `A`.
- `tests/` e `build/` esclusi dal pacchetto release.
- Smoke test Milestone 9 completato.
- Save v2 con unlock persistenti e migrazione automatica dei save v1.
- Unlock `Field Kit` ottenuto al livello party 2 e applicato a ogni nuova run.
- Reset salute idempotente per player presenti e join durante una run.
- Feedback audio procedurale per sparo, impatto valido e pickup.
- Primo pass di bilanciamento: `Starter Pistol` a 6 colpi/s e `Prototype Blaster` a 4,5 colpi/s.
- Stato unlock mostrato nel menu principale.

## Milestone 10 - Visual Readability Foundation

Stato: completata come primo pass visuale modulare.

- Arena survival desaturata e pseudo-isometrica con dettagli post-apocalittici.
- Survivor leggibili per slot con animazioni procedurali di movimento e combat.
- Zombie riconoscibili con silhouette e feedback di stato.
- Pickup e supply crate grafici senza etichette testuali.
- HUD per-player con schede, barre vita, arma e munizioni.
- Effetti leggeri per sparo, hit, morte e raccolta.
- Bersagli debug nascosti dal gameplay normale.
- Smoke test visuale e QA a 1280x720.

## Milestone 11 - Boss Telegraph e Combat Danger Feedback

Stato: completata come primo pass modulare.

- Raffica mirata preceduta da cono, corsie e countdown world-space.
- Direzione mirata bloccata al momento del warning.
- Raffica radiale preceduta da raggi, area e countdown leggibili.
- Nessun proiettile generato durante la finestra di telegraph.
- HUD con messaggi distinti per aimed, radial e fase 2.
- Cue audio procedurali per spawn boss, warning e cambio fase.
- Impulso visuale world-space al passaggio in fase 2.
- Smoke test dedicato e QA visuale a 1280x720.

## Milestone 12 - Varianti Zombie Runner e Tank

Stato: completata come primo pass gameplay e visuale.

- Runner rapido, fragile e dalla silhouette sottile.
- Tank lento, resistente e dalla silhouette larga.
- AI melee condivisa tramite `BasicEnemy`.
- Scene, collisioni, health bar e loot configurati per archetipo.
- Composizione wave deterministica: runner dalla wave 2 e tank dalla wave 3.
- Conteggio, scaling, morte e drop continuano a usare i sistemi condivisi.
- Dungeon e tower defense non modificati.
- Smoke test dedicato e QA con quattro player a 1280x720.

## Milestone 13 - Identita Grafica di Armi e Torri

Stato: completata come primo pass visuale modulare.

- `WeaponVisualData` condiviso tra arma world-space, icona HUD e proiettile.
- `Starter Pistol` compatta con accento arancio.
- `Prototype Blaster` a doppia forcella con energia ciano.
- `Wave Cannon` pesante con nucleo e proiettile magenta.
- Forma, scala, glow e trail dei proiettili configurati per profilo.
- Torre con base esagonale, nucleo pulsante e doppia canna orientabile.
- Tracking, idle scan, rinculo e muzzle flash senza autorita gameplay nel visual.
- Smoke test dedicato e due QA visuali a 1280x720.

## Milestone 14 - Polish Finale e Presentabilita

Stato: completata come chiusura del visual gameplay pass.

- `WaveWardenVisual` segmentato con nucleo, piastre e direzione leggibile.
- Palette, spine e animazione dedicate alla fase 2.
- Feedback visuale di spawn, hit e carica pattern.
- Proiettili aimed e radial con profili, glow e trail distinti.
- Effetto morte boss con drop speciale leggibile.
- Pannello boss centrato e responsive.
- Annunci centrali per wave, reward, boss, overdrive e sconfitta.
- Precedenza degli annunci per evitare sovrascritture immediate.
- Smoke test dedicato e QA completa a quattro player a 1280x720.

## Milestone 15 - Zombie Ranged e Pressione a Distanza

Stato: completata come primo pass gameplay e visuale.

- Shooter alto e tossico, distinto dagli archetipi melee.
- Distanza preferita e ritirata quando il player si avvicina.
- Windup con direzione bloccata, corsia e countdown world-space.
- Nessun proiettile creato durante il warning.
- Proiettile ostile verde/ciano distinto dai pattern boss.
- Health, scaling, drop e registro condivisi con i sistemi esistenti.
- Composizione deterministica dalla wave 4.
- Smoke test dedicato e QA con quattro player.

## Milestone 16 - Downed e Revive Multiplayer

Stato: completata come primo pass cooperativo.

- Stato downed separato dalla morte per i player.
- Movimento, fuoco, targeting e reward disattivati durante il downed.
- Revive vicino con interact tenuto e progresso interrompibile.
- Anello world-space e stato dedicato nelle schede HUD.
- Ripristino al 35% senza accumulo del bonus `Field Kit`.
- Join e leave ripuliscono il progresso senza completamenti tardivi.
- Sconfitta party all-downed nelle tre modalita.
- Smoke test e QA con quattro player.

## Milestone 17 - Fine Run, Risultati e Menu

Stato: completata come primo flusso UI condiviso.

- Tracker sessione per durata, XP, denaro e unlock.
- Risultati espliciti per survival, dungeon e tower defense.
- Retry sul nodo modalita esistente e ultimo context.
- Cambio modalita ciclico e ritorno al menu.
- Focus joypad iniziale e input gameplay bloccato sotto l'overlay.
- Salvataggio sincrono prima del menu.
- Smoke test dei tre flussi e QA a 1280x720.

## Milestone 18 - Audio Mix e SFX Sostituibili

Stato: completata come infrastruttura audio modulare.

- Bus separati per musica, UI, armi, nemici, boss e ambiente.
- Cue con stream opzionale e fallback procedurale.
- Limite voci, priorita e variazione leggera di pitch.
- Hook per armi, archetipi nemico, wave, downed, revive e risultati.
- Slider Master, Music e SFX nel menu.
- Save v3 con round-trip delle impostazioni audio.
- Smoke test hook/bus e QA menu a 1280x720.

## Milestone 19 - Secondo Boss e Registro Boss

Stato: completata come primo registro boss configurabile.

- `BossSystem` registra scene, ID e compatibilita per modalita.
- `Wave Warden` resta disponibile in tutte le modalita.
- `Rift Architect` viene usato come boss finale dungeon.
- Pattern `lane_sweep` e `cross_burst` con warning world-space distinti.
- Fase 2, visual dedicato e drop garantito `Rift Repeater`.
- HUD boss reso generico per nome, fase e warning.
- Richieste incompatibili rifiutate con segnale tipizzato.
- Smoke test registry/pattern/drop e due QA visuali a 1280x720.

## Milestone 20 - Arena, Biomi e Props Interattivi

Stato: completata come primo sistema arena survival data-driven.

- `BiomePalette` e `SurvivalArenaProfile` separano dati e controller.
- Layout `Industrial Crossroads` e `Rift Foundry` selezionabili via context.
- `SurvivalArenaManager` configura playground, wave, player e supply crate.
- Gate visibili e non collidenti collegati allo spawn reale.
- Barili esplosivi colpibili senza bloccare il pathing.
- Warning temporizzato e area leggibile prima del danno.
- Danno ad area tramite `HealthSystem` ed effetto condiviso.
- Smoke test, stress a quattro player e QA di entrambi i layout.

## Milestone 21 - Accessibilita, Performance e Asset Pipeline

Stato: completata come primo pass configurabile e misurabile.

- `VisualSettingsManager` separato dai sistemi gameplay.
- Preset default, reduced motion e high contrast.
- Slider per flash, glow, trail, shake e scala testo HUD.
- Marker geometrici per i quattro player e icone pickup non basate sul colore.
- Save v4 con impostazioni visuali persistenti.
- Camera shake e motion reduction applicati solo alla presentazione.
- Convenzioni import, fallback e registro licenze in `assets/`.
- Profiling con quattro player, 28 nemici e boss a 16,58 ms medi.
- Smoke test round-trip/performance e quattro QA a 1280x720.

Attivita post-roadmap:

- sistema ammo survival robusto con fallback infinita, pickup condivisi, supply crate e director anti-frustrazione completato;
- visual gameplay pass della zombie survival completato;
- zombie ranged con telegraph e pressione a distanza completato;
- downed e revive multiplayer completati;
- risultati, retry e cambio modalita completati;
- audio mix, cue sostituibili e persistenza completati;
- secondo boss e registro configurabile completati;
- arena survival, biomi e props interattivi completati;
- accessibilita, profiling e pipeline asset completati;
- roadmap RPG Mode M1-M11 completata fino alla configurazione classi data-driven;
- asset definitivi e ulteriori pass di bilanciamento;
- firma digitale della build pubblica.
