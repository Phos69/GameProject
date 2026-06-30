# Piano cleanup warning GUT

Baseline iniziale rilevata dopo il cutover finale GUT del 2026-06-30:

- suite rapida: 45 script, 220 test, exit code `0`, `Deprecated 1486`,
  `Warnings 3`, `70 Orphans`;
- suite soak: 4 script, 4 test, exit code `0`, `Deprecated 212`;
- report JUnit locali in `build/test_logs/`;
- Visual QA fuori da GUT e non considerati in questo piano.

Stato dopo il primo cleanup del 2026-06-30:

- `wait_frames()` rimosso dai test GUT sotto `tests/suites/**`;
- warning GUT generici localizzati in `character_select_test.gd`,
  `manifest_contract_test.gd` e `void_cliff_asset_test.gd`;
- i tre warning generici sono stati corretti con teardown immediato dei nodi
  creati dai test;
- gli orphans dei proiettili sono stati eliminati dai run mirati `combat` e
  `progression`;
- i warning UID dell'addon GUT sono stati rimossi allineando le scene agli
  `.gd.uid` gia versionati;
- i leak/resource warning di shutdown da `world_data` ciclici sono stati ridotti
  nei run sorgente `world_gen`, `assets`, `combat` e `progression`.

Stato dopo il pass cache/soak del 2026-06-30:

- suite rapida completa: 45 script, 220 test, 14516 assert, exit code `0`;
  resta un residuo di shutdown `ObjectDB instances leaked` + `1 resources still
  in use`;
- suite soak completa: 4 script, 4 test, 59 assert, exit code `0`, senza warning
  di shutdown;
- `ten_wave_test.gd` ora e pulito sia isolato sia dentro la sequenza soak;
- i run mirati `ui_audio`, `diagnostics`, `ten_wave` e `soak` non producono
  warning GUT/RID/resource.

## Obiettivo

Ridurre il rumore dei runner GUT fino a ottenere log locali leggibili, dove i
warning residui indicano problemi reali e non debito tecnico noto.

## Priorita

### 1. Deprecazioni `wait_frames`

Stato 2026-06-30: completato il primo pass. Tutte le occorrenze in
`tests/suites/**` e negli esempi dei fixture in `tests/support/**` sono state
sostituite con `wait_physics_frames()`. Il run mirato
`./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/progression` passa
senza deprecazioni `wait_frames`.

Obiettivo: eliminare l'uso di `wait_frames()` nei test GUT.

Contesto: GUT 9.6.0 marca `wait_frames()` come deprecato e lo inoltra a
`wait_physics_frames()`. La sostituzione diretta con `wait_physics_frames()` e
quindi semanticamente equivalente per i test esistenti.

File/sistemi coinvolti:

- `tests/suites/**`

Criterio di accettazione:

- `rg "wait_frames\\(" tests/suites` non trova occorrenze;
- run mirato su almeno un'area ad alto impatto senza deprecazioni
  `wait_frames`;
- suite rapida ancora verde.

### 2. Warning GUT generici

Stato 2026-06-30: completato. Un audit completo
`./tools/run_gut.ps1 -SkipImport` ha confermato la suite rapida verde con
`Warnings 2` dopo la correzione di `character_select_test.gd`; i warning residui
erano entrambi `Test script has 2 unfreed children` e sono stati localizzati in
`tests/suites/assets/manifest_contract_test.gd` e
`tests/suites/assets/void_cliff_asset_test.gd`. I tre script ora liberano
esplicitamente i nodi creati dai test rimuovendoli dal parent e chiamando
`free()`. I run mirati dei tre script passano senza `Warnings` nel summary GUT.

Obiettivo: localizzare e correggere i `Warnings 3` del run rapido.

File/sistemi coinvolti:

- runner locale `tools/run_gut.ps1` per cattura log affidabile;
- test GUT che generano warning di assert o logging.

Criterio di accettazione:

- log completo persistente con testo dei warning;
- run per area che identifica i test sorgente;
- warning corretti o tracciati con motivazione esplicita.

### 3. Orphans di proiettili

Stato 2026-06-30: completato sui perimetri sorgente. `ProjectileSystem` ora
aggancia i proiettili a `current_scene` quando disponibile, altrimenti al parent
locale del sistema; i test sintetici GUT possono quindi ripulire i proiettili
insieme al proprio `scene_root`. `rpg_progression_test.gd` ripulisce subito i
proiettili delle super ranged dopo aver verificato il conteggio di spawn, cosi
le super melee successive non vengono contaminate da colpi ancora attivi.

Obiettivo: eliminare i `70 Orphans` legati a `Projectile:<Area2D>`.

File/sistemi coinvolti:

- `tests/suites/combat/combat_test.gd`;
- `tests/suites/progression/rpg_progression_test.gd`;
- eventuale helper condiviso test/fixture per cleanup proiettili.

Criterio di accettazione:

- run delle aree `combat` e `progression` senza orphans di proiettili;
- nessuna regressione su hit/danno/XP/super.

Validazione:

- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/combat`: 4 script,
  20 test, 1639 assert, exit code `0`, nessun `Orphans`;
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/progression`: 3
  script, 12 test, 269 assert, exit code `0`, nessun `Orphans`.

### 4. Warning UID addon GUT

Stato 2026-06-30: completato. Gli `ext_resource type="Script"` nelle scene
vendorizzate di GUT puntavano a UID obsoleti rispetto ai `.gd.uid` tracciati.
Le scene sotto `addons/gut/*.tscn` e `addons/gut/gui/*.tscn` ora usano gli UID
effettivi dei rispettivi script. Non sono stati aggiunti nuovi `.uid`; la policy
`.gitignore` resta invariata e continua a ignorare nuovi UID generati.

Obiettivo: rimuovere i warning Godot su `ext_resource, invalid UID` nelle scene
vendorizzate di GUT.

File/sistemi coinvolti:

- `addons/gut/*.tscn`;
- `addons/gut/gui/*.tscn`;
- eventuali `.uid` se si decide di versionarli per l'addon.

Criterio di accettazione:

- avvio GUT senza warning `invalid UID` su scene dell'addon;
- `.gitignore` resta coerente con la scelta sugli `.uid`.

Validazione:

- controllo statico: tutti gli `ext_resource type="Script"` delle scene GUT
  corrispondono al contenuto dei rispettivi `.gd.uid`;
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/_sanity`: 1
  script, 4 test, 5 assert, exit code `0`, nessun match `invalid UID` nel log.

### 5. Leak e resource still in use a shutdown

Stato 2026-06-30: completato sui sorgenti confermati e sul perimetro soak. Il verbose di
`combat` e `golden_snapshot_bake_test.gd` mostrava cicli `RefCounted` tra
`BiomeCell`, `BiomePassage` e `BiomeEnvironmentLayout`: i `BiomeCell.neighbors`
si puntano a vicenda e non vengono liberati dal reference counting se il
`world_data` viene solo rimosso da un `Dictionary`. `WorldDataCache` ora spezza
i link dei `world_data` su overwrite, evizione LRU e `clear()`, espone
`release_world_data()` per gli snapshot consumati direttamente fuori dal
lifecycle di `BiomeManager`, e `BiomeWorldGenerator.clear_world()` ripulisce
anche i mondi adottati da cache che non passano da `BiomeMapGenerator.last_cells`.
Il test golden rilascia esplicitamente i world_data prodotti da codec/fetch.
Il pass successivo ha allargato il cleanup alle cache statiche di manifest,
texture SVG e metriche oggetto, ha aggiunto gli hook pre/post anche alla config
soak e ha reso `ten_wave_test.gd` responsabile del proprio teardown di scena.
La suite soak e ora pulita; il run rapido completo resta verde ma conserva un
residuo cumulativo minimo (`ObjectDB` + `1 resource`) da investigare in una
tranche dedicata.

Obiettivo: distinguere cleanup correggibile nei test da rumore di engine/addon.

File/sistemi coinvolti:

- cache statiche (`WorldDataCache`, loader texture, manifest);
- teardown di nodi UI/runtime nei fixture;
- eventuali residui da GUT/Godot non eliminabili localmente.

Criterio di accettazione:

- riduzione misurabile di `ObjectDB instances leaked`,
  `resources still in use` e RID leaked dopo la correzione degli orphans;
- ogni residuo non risolto documentato con causa probabile.

Validazione:

- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/world_gen -Select golden_snapshot`:
  1 script, 4 test, 18 assert, exit code `0`, nessun warning di shutdown in
  coda;
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/world_gen`: 5
  script, 47 test, 360 assert, exit code `0`, nessun `ObjectDB instances leaked`
  ne `resources still in use` in coda;
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets`: 8
  script, 50 test, 7276 assert, exit code `0`, nessun warning di shutdown in
  coda;
- verbose `combat` su `res://tests/suites/combat`: 4 script, 20 test, 1639
  assert, exit code `0`, nessun `ObjectDB`, `Resource still in use` o `Orphans`
  dopo il summary.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/progression`: 3
  script, 12 test, 269 assert, exit code `0`, nessun warning di shutdown in
  coda.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/ui_audio`: 7
  script, 12 test, 255 assert, exit code `0`, nessun warning in coda.
- `./tools/run_gut.ps1 -SkipImport -Config res://.gutconfig.soak.json -Select ten_wave`:
  1 script, 1 test, 32 assert, exit code `0`, nessun warning in coda.
- `./tools/run_gut.ps1 -SkipImport -Config res://.gutconfig.soak.json`: 4 script,
  4 test, 59 assert, exit code `0`, nessun warning in coda.
- `./tools/run_gut.ps1 -SkipImport`: 45 script, 220 test, 14516 assert, exit
  code `0`; residuo in coda: `ObjectDB instances leaked` e `1 resources still in
  use`.

### 6. Robustezza runner PowerShell sotto redirezione

Stato 2026-06-30: primo fix completato. `tools/run_gut.ps1` abbassa
temporaneamente `$ErrorActionPreference` a `Continue` attorno alle invocazioni
native di Godot, preservando `$LASTEXITCODE` ed evitando che lo stderr nativo
interrompa gli audit rediretti prima del riepilogo GUT.

Obiettivo: permettere audit warning riproducibili con log completi.

File/sistemi coinvolti:

- `tools/run_gut.ps1`.

Criterio di accettazione:

- `./tools/run_gut.ps1 -SkipImport -GutDir <area> *> build/test_logs/<file>.log`
  non viene interrotto da `NativeCommandError` generato dallo stderr nativo di
  Godot;
- exit code reale di GUT preservato.

## Sequenza proposta

1. Sostituire `wait_frames()` nei test GUT.
2. Sistemare la cattura log del runner PowerShell.
3. Localizzare i `Warnings 3` con run per area.
4. Correggere orphans proiettili.
5. Rimuovere warning UID GUT.
6. Rieseguire quick + soak e aggiornare questa baseline.
