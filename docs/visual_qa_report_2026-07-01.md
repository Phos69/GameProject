# Visual QA Report - 2026-07-01

## Esito

**NON PASS.**

La suite ha prodotto abbastanza evidenza per confermare problemi visuali
runtime e problemi strutturali del tooling QA, ma non puo essere considerata
una validazione completa della release: 26 delle 40 catture di scenario
principali mostrano ancora la schermata di caricamento invece dello stato che
dovrebbero validare.

## Follow-up QA-VIS-FIX - 2026-07-02

**PASS per l'affidabilita del tooling.** I problemi `QA-VIS-001` -
`QA-VIS-005` sono stati corretti senza chiudere automaticamente i finding
visuali di prodotto `VIS-001` - `VIS-012`.

- Il runner esegue 25 entry point standalone ed esclude i due helper WVIS.
- Gli scenari gameplay attendono overlay rimosso, marker specifico, terreno
  pronto e `visible_missing_chunks == 0` prima della cattura.
- Il review biomi sospende il seam automatico durante i teleport controllati e
  ha rigenerato 150 PNG con zero chunk visibili mancanti.
- La QA isometrica finale usa il percorso sincrono deterministico e rigenera le
  sette evidenze senza errore nel clone della cache.
- Il test Infinite Arena distingue cliff perimetrali e chasm interni, in linea
  con il contratto GUT.
- Il cleanup condiviso libera scena, cache mondo, manifest e texture prima
  dell'uscita.

Validazione finale:

- `./tools/run_visual_qa.ps1 -SkipImport`: **25 OK, 0 falliti**, exit code `0`;
- 47 PNG root e 150 PNG del review biomi rigenerati;
- ispezione della contact sheet root: nessuna schermata di loading;
- 25 log senza `FAIL`, errori, leak `ObjectDB` o risorse residue.

## Ambiente e metodo

- Branch: `master` (`origin/master` avanti di 2 commit al termine della QA).
- Working tree iniziale: pulito.
- Engine: Godot `4.6.3.stable.official.7d41c59c4`.
- Renderer: `gl_compatibility`, OpenGL 4.3, VMware SVGA3D/Mesa 24.1.0.
- Comando: `./tools/run_visual_qa.ps1`.
- Risultato automatico: **22 script OK, 5 falliti, 27 eseguiti**.
- Output ispezionati: **225 PNG**:
  - 150 catture bioma a `1280x720` e `960x540`;
  - 40 catture principali in `build/qa/`;
  - 35 catture specialistiche per cliff, ostacoli, superfici e asset.
- Per l'ispezione sono state generate 12 contact sheet locali in
  `build/qa/review_contact_sheets/`; `build/` resta ignorata da Git.

Le severita usate nel report sono:

- **Bloccante**: rende la QA non attendibile o mostra una scena incompleta;
- **Alta**: altera semantica, leggibilita o accesso a una UI primaria;
- **Media**: incoerenza evidente con impatto percettivo o di gerarchia;
- **Bassa**: polish e coerenza senza blocco funzionale immediato.

## Incongruenze visuali del prodotto

### VIS-001 - Alta - Settings tagliato a 1280x720

La pagina `Video` supera l'altezza del viewport. Il bordo inferiore e il
pulsante `Back` sono tagliati; il testo del pulsante e visibile solo in parte.
La risoluzione e quella di riferimento del progetto, quindi non e un caso
limite.

Evidenza:
`build/qa/milestone_21_visual_settings_menu.png`.

Impatto: la navigazione resta ambigua e i controlli inferiori possono diventare
inaccessibili o apparire fuori safe area.

### VIS-002 - Alta - Seam e griglia dei tile dominano il terreno

I cinque biomi mostrano rettangoli, checker e giunzioni ortogonali chiaramente
visibili. Il problema e particolarmente evidente:

- nel Tossico, dove ogni blocco raster e distinguibile dal successivo;
- in Neve, dove strada e ghiaccio formano una griglia bianca regolare;
- in Palude, dove le bande verticali e i cambi di materiale sembrano pannelli;
- nella Pianura, dove strada, sentiero ed erba terminano con scalini e angoli
  netti;
- nei crossing, dove `path_to_road` appare come una fascia sovrapposta.

Evidenze:

- `build/qa/biome_rendering_review/960x540/960x540_seed_641004_toxic_wastes_biome_2_2_obstacle_hazard.png`;
- `build/qa/forest_surfaces/forest_transition_runtime.png`;
- `build/qa/forest_surfaces/forest_path_runtime.png`;
- `build/qa/milestone_11_boss_aimed.png`.

Impatto: il terreno sembra composto da patch indipendenti e non da uno spazio
continuo; le route sembrano overlay tecnici.

### VIS-003 - Alta - Muri e voragini comunicano la stessa semantica

L'Infinite Arena deve usare un perimetro `walled`, ma la suite rileva
`Infinite Arena cliffs are not fall zones` come failure. Le catture mostrano
pareti perimetrali con nero oltre il bordo e numerosi riquadri neri interni:
visivamente leggono come cadute, non come cliff rialzati e solidi.

Evidenze:

- `build/qa/infinite_arena_cliffs/east.png`;
- `build/qa/infinite_arena_cliffs/north.png`;
- `build/qa/infinite_arena_cliffs/north_west_corner.png`;
- `build/qa_logs/20260701_230556_infinite_arena_cliff_visual_qa.log`.

Impatto: il player non puo distinguere un muro invalicabile da una fall zone
che infligge danno e consente il roll solo entro regole specifiche.

### VIS-004 - Alta - Vuoto nero senza bordo e oggetti sospesi

Molte catture `1280x720` mostrano grandi aree nere adiacenti al terreno senza
un cliff continuo. In alcuni casi pickup, marker o props restano visibili nel
nero. Un esempio netto e la Palude seed `918273`, con un pickup a destra e un
marker in basso a destra fuori dalla superficie renderizzata.

Evidenza principale:
`build/qa/biome_rendering_review/1280x720/1280x720_seed_918273_drowned_marsh_biome_2_1_center.png`.

Il difetto e molto meno esteso a `960x540`. Il test sposta istantaneamente la
camera e attende solo 3 frame (`MAX_CAPTURE_WAIT_FRAMES`), senza chiamare
`prepare_area`/`is_area_ready`: la causa piu probabile e una cattura prima del
commit dei chunk visibili. Il comportamento durante movimento normale resta da
confermare, ma le immagini correnti non possono validare il requisito "zero
chunk mancanti in camera".

### VIS-005 - Alta - Scala e linguaggio delle crate incoerenti

Le resource crate tematiche sono circa 2-3 volte il volume visuale del player e
sembrano piccoli edifici. Usano contorni vettoriali puliti e colori saturi sopra
fondali raster molto dettagliati. La differenza di scala e stile le fa sembrare
un overlay o un placeholder invece di un oggetto fisico del mondo.

Evidenze:

- `build/qa/biome_rendering_review/960x540/960x540_seed_641004_toxic_wastes_biome_2_2_obstacle_hazard.png`;
- `build/qa/biome_rendering_review/960x540/960x540_seed_641004_burning_fields_biome_2_1_obstacle_hazard.png`.

Il contrasto rende la crate leggibile, ma rompe profondita, proporzione e
coerenza con collisione/footprint.

### VIS-006 - Media - Contrasto dei biomi sbilanciato

- **Infuocato**: il rumore arancio del terreno compete con hazard, telegraph e
  oggetti piccoli.
- **Neve**: il fondale e sovraesposto; cliff, ghiaccio, route e crate chiare
  perdono separazione.
- **Palude**: valori troppo scuri e vicini; strada, acqua profonda e terreno
  sono difficili da separare.
- **Tossico**: il grigio uniforme rende route e terreno quasi equivalenti,
  mentre le pozze verdi sono molto piccole.

Evidenze: le dieci contact sheet
`build/qa/review_contact_sheets/biome_*.png`.

Impatto: hazard e percorsi richiedono lettura per colore locale invece di
silhouette/materiale, con rischio maggiore in co-op e durante le wave.

### VIS-007 - Media - HUD sovradimensionato rispetto agli attori

La card P1 occupa circa `276x182` px anche a `960x540`, quasi un terzo della
larghezza e un terzo dell'altezza. Gran parte del pannello e vuota. Il
faceplate world-space e largo circa tre volte il personaggio e puo coprire
ostacoli o bersagli sopra l'attore. Durante il boss, barra boss e annuncio
centrale occupano insieme buona parte della fascia alta.

Evidenze:

- `build/qa/biome_rendering_review/960x540/960x540_seed_641004_toxic_wastes_biome_2_2_obstacle_hazard.png`;
- `build/qa/milestone_11_boss_radial.png`;
- `build/qa/player_world_hud_faceplate.png`.

Impatto: la gerarchia privilegia telemetria statica rispetto al campo di
combattimento; il problema aumenta con quattro player.

### VIS-008 - Media - Ripetizione e scala degli alberi

Il `forest_tree` usa un raster molto dettagliato e molto piu grande di player,
armi e oggetti vettoriali. I muri di vegetazione ripetono lo stesso albero con
scala, orientamento e spaziatura identici, rendendo evidente il tiling. Le
chiome possono coprire una porzione ampia del combattimento.

Evidenze:

- `build/qa/forest_surfaces/forest_path_runtime.png`;
- `build/qa/obstacle_assets/forest_tree.png`;
- `build/qa/infinite_arena_cliffs/east.png`.

### VIS-009 - Media - Asset ostacolo non normalizzati

L'asset board mostra sorgenti con trattamento molto diverso:

- `large_rock` appare come texture quadrata opaca, non come oggetto isometrico;
- `broken_fence` e sfocato rispetto alle case vettoriali;
- `reed_wall` occupa una parte minima di una canvas alta e in runtime rischia
  di apparire sottoscala;
- `forest_tree` ha dettaglio fotografico mentre case, auto e rocce piccole
  usano forme piatte.

Evidenze:
`build/qa/review_contact_sheets/specialized_outputs.png` e
`build/qa/obstacle_assets/`.

### VIS-010 - Media - Character Select compositivamente incompleto

Le quattro slot card superiori contengono grandi aree vuote; gli slot inattivi
mostrano griglia e cerchi fantasma ma nessun placeholder informativo. Le linee
decorative sembrano attraversare i limiti delle card. La griglia personaggi
attiva una scrollbar pur mostrando solo due righe e lascia una grande area
vuota a destra/in basso.

Evidenza:
`build/qa/character_select_opened.png`.

La schermata mescola inoltre inglese (`CHARACTER SELECT`, `Slot empty`,
`Start Zombie Survival`) e italiano nei nomi/descrizioni delle abilita.

### VIS-011 - Media - Identita armi non uniforme alla scala di gioco

I pickup condividono tutti un grande contenitore pentagonale che domina la
silhouette; l'arma interna e piccola. Nel board melee:

- `quick_knife` e ridotta a due segmenti grigi quasi invisibili;
- `spear` e una linea molto sottile;
- `chain_lightning` usa un trattino giallo minuscolo;
- `fireball` e `unstable_void` differiscono soprattutto per palette, non per
  massa o ritmo della forma.

Evidenze:

- `build/qa/weapon_visual_identity_pickup_grid.png`;
- `build/qa/weapon_visual_identity_melee_slash_grid.png`;
- `build/qa/weapon_visual_identity_elemental_impact_grid.png`.

Il board held/HUD perde inoltre le etichette dei primi due campioni della riga
superiore, quindi la tavola non e internamente coerente.

### VIS-012 - Bassa - Main menu privo del linguaggio visuale del gioco

Il menu e leggibile e il focus e visibile, ma usa una colonna nera stretta su
sfondo quasi nero, con molto spazio morto e nessun richiamo ai biomi, ai
personaggi o all'isometria del gameplay. E coerente con il `Known Visual TODO`
gia documentato, ma resta molto distante dalle card HUD e dal Character Select.

Evidenze:
`build/qa/menu_initial.png` e `build/qa/menu_joypad_focus.png`.

## Problemi del tooling Visual QA

### QA-VIS-001 - Bloccante - 26 catture principali fotografano il loading

Sono invalide le catture:

- `infinite_arena_started`;
- `milestone_10_survival`;
- `milestone_12_enemy_variants`;
- `milestone_13_defense_towers`, `milestone_13_player_weapons`;
- tutte le quattro `milestone_14_*`;
- `milestone_15_ranged_enemy`;
- `milestone_16_downed_revive`;
- `milestone_17_run_results`;
- `milestone_19_rift_cross`, `milestone_19_rift_lane`;
- tutte le tre `milestone_21_profile_*`;
- `survival_started`;
- tutte le tre `weapon_visual_identity_crowded_*`;
- tutte le cinque `zombie_biome_*`.

Le percentuali sono comprese circa tra 18% e 95%. Alcuni script risultano
comunque `OK` perche verificano solo che il PNG esista.

Impatto: non sono validati enemy variants, tower defense, weapon gameplay,
presentazione boss finale, downed/revive, risultati, Rift Architect, profili
accessibilita e panoramiche bioma legacy.

### QA-VIS-002 - Alta - Il runner esegue due helper come test standalone

`weapon_visual_identity_qa_board.gd` estende `Node2D` e
`weapon_visual_identity_survival_qa.gd` estende `RefCounted`; sono helper
precaricati dall'orchestratore, non `SceneTree`/`MainLoop`. Il runner esegue
ogni `*.gd` e genera due failure inevitabili.

Evidenze:

- `build/qa_logs/20260701_230556_weapon_visual_identity_qa_board.log`;
- `build/qa_logs/20260701_230556_weapon_visual_identity_survival_qa.log`.

### QA-VIS-003 - Alta - La QA isometrica finale non costruisce il mondo

`milestone_10_isometric_final_visual_qa.gd` fallisce per tutti i cinque biomi,
non trova il world graph per il chase e termina con:

```text
Invalid access to property or key '' on a base object of type
'RefCounted (BiomeCell)'
```

Backtrace:
`game/procedural/world_generation/world_data_cache.gd:171`.

Non vengono rigenerate le sette evidenze finali dichiarate dal report storico.

### QA-VIS-004 - Alta - Criteri automatici troppo deboli

La suite considera sufficiente che un'immagine esista o abbia variazione di
pixel. Una barra di caricamento soddisfa questi criteri. Anche
`biome_rendering_review_visual_qa.gd` valida il dettaglio dell'immagine ma non
verifica:

- assenza del loading overlay;
- numero di chunk visibili mancanti;
- presenza dello stato/attore specifico atteso;
- assenza di oggetti sopra il void;
- stabilita dell'annuncio bioma tra le due risoluzioni.

Esempio: la cattura Burning Fields seed `772031` a `1280x720` mostra
temporaneamente `BIOMA TOSSICO`, mentre quella `960x540` mostra correttamente
`BIOMA INFUOCATO`.

### QA-VIS-005 - Media - Cleanup incompleto e leak nei processi QA

Quindici log riportano risorse ancora in uso o istanze `ObjectDB` non liberate.
Il caso peggiore e `survival_visual_qa.gd`, con 153 texture GL segnalate come
leaked, RID residui e 180 risorse ancora in uso. Lo script esce comunque con
stato `PASS`.

Evidenza:
`build/qa_logs/20260701_230556_survival_visual_qa.log`.

## Aree risultate leggibili nelle evidenze valide

- Focus tastiera/joypad del main menu chiaramente visibile.
- Telegraph `aimed` e `radial` del Wave Warden distinguibili.
- Barra boss, titolo e warning leggibili a `1280x720`.
- Board projectile/muzzle/impact generalmente distinguibile per famiglia.
- Profili crate tematici distinguibili per colore, pur con scala/stile da
  correggere.
- Le 150 catture del review biomi coprono realmente cinque biomi, tre seed e
  due risoluzioni; restano pero soggette ai problemi di attesa chunk descritti.

## Priorita consigliata

### 1. QA-VIS-FIX - Rendere attendibile la suite

- Obiettivo: catturare solo stati gameplay pronti e non eseguire gli helper.
- Milestone collegata: `QA-001`.
- File/sistemi: `tools/run_visual_qa.ps1`, `tests/visual_qa/`,
  `WorldRegionStreamer`.
- Criterio di accettazione: nessuna cattura contiene il loading overlay; ogni
  scenario verifica almeno un marker specifico; helper eseguiti solo tramite
  orchestratore; suite con exit code `0`.
- Test richiesto: suite Visual QA completa, ispezione delle 40 catture root e
  controllo automatico `visible_missing_chunks == 0`.

### 2. WORLD-VIS-FIX - Correggere cliff, void e copertura viewport

- Obiettivo: separare chiaramente muro e caduta e impedire buchi/oggetti nel
  vuoto.
- Milestone collegata: `BAL-001`.
- File/sistemi: `game/modes/zombie/terrain/`, `WorldRegionStreamer`,
  `game/modes/zombie/cliffs/`, `Infinite Arena`.
- Criterio di accettazione: bordo `walled` mai classificato come fall zone;
  ogni contatto ground/void ha cliff continuo; nessun oggetto su void; zero
  chunk mancanti durante movimento e cambio zoom.
- Test richiesto: QA Infinite Arena sui quattro lati, review biomi a
  `1280x720`/`960x540`, attraversamento manuale senza teleport e profiling
  `visible_missing_chunks`.

### 3. UI-VIS-FIX - Ripristinare safe area e gerarchia HUD

- Obiettivo: eliminare clipping e ridurre l'occlusione del campo di gioco.
- Milestone collegata: `UIUX-001`.
- File/sistemi: `game/ui/`, `game/settings/`, Character Select, boss HUD.
- Criterio di accettazione: Settings interamente accessibile a `1280x720`,
  `1024x768` e `960x540`; card/faceplate senza sovrapposizioni critiche con
  quattro player e boss; nessuna scrollbar inutile.
- Test richiesto: checklist UI multi-risoluzione, quattro player, boss wave e
  navigazione completa tastiera/joypad.

### 4. ART-VIS-FIX - Normalizzare materiali e oggetti

- Obiettivo: ridurre seam/tiling e uniformare scala, dettaglio e ombre.
- Milestone collegata: `UIUX-001` / `BAL-001`.
- File/sistemi: generated biome art, tile resolver, crate visual, obstacle
  manifest e asset.
- Criterio di accettazione: transizioni senza pannelli rettangolari evidenti;
  crate proporzionata al player/footprint; oggetti della stessa categoria con
  densita di dettaglio e padding coerenti.
- Test richiesto: asset board rigenerata, review biomi sui tre seed e playtest
  multi-bioma con generated art.

### 5. WEAPON-VIS-FIX - Rendere leggibili le armi deboli

- Obiettivo: distinguere pickup e attacchi per silhouette, non solo per colore.
- Milestone collegata: `UIUX-001`.
- File/sistemi: `WeaponVisualRenderer`, palette/catalogo visuale, board WVIS.
- Criterio di accettazione: knife, spear e chain lightning leggibili alla scala
  gameplay; il contenitore pickup non domina l'arma; tutte le label del board
  presenti.
- Test richiesto: board WVIS, scenario crowded realmente caricato e preset
  default/reduced motion/high contrast.

## File di evidenza

- Log della run: `build/qa_logs/20260701_230556_*.log`.
- Screenshot: `build/qa/`.
- Contact sheet: `build/qa/review_contact_sheets/`.

Gli output sotto `build/` sono locali e ignorati da Git; questo report conserva
nomi, esiti e passi di riproduzione ma non incorpora i PNG.
