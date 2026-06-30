# Piano cleanup warning GUT

Baseline rilevata dopo il cutover finale GUT del 2026-06-30:

- suite rapida: 45 script, 220 test, exit code `0`, `Deprecated 1486`,
  `Warnings 3`, `70 Orphans`;
- suite soak: 4 script, 4 test, exit code `0`, `Deprecated 212`;
- report JUnit locali in `build/test_logs/`;
- Visual QA fuori da GUT e non considerati in questo piano.

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

Obiettivo: localizzare e correggere i `Warnings 3` del run rapido.

File/sistemi coinvolti:

- runner locale `tools/run_gut.ps1` per cattura log affidabile;
- test GUT che generano warning di assert o logging.

Criterio di accettazione:

- log completo persistente con testo dei warning;
- run per area che identifica i test sorgente;
- warning corretti o tracciati con motivazione esplicita.

### 3. Orphans di proiettili

Obiettivo: eliminare i `70 Orphans` legati a `Projectile:<Area2D>`.

File/sistemi coinvolti:

- `tests/suites/combat/combat_test.gd`;
- `tests/suites/progression/rpg_progression_test.gd`;
- eventuale helper condiviso test/fixture per cleanup proiettili.

Criterio di accettazione:

- run delle aree `combat` e `progression` senza orphans di proiettili;
- nessuna regressione su hit/danno/XP/super.

### 4. Warning UID addon GUT

Obiettivo: rimuovere i warning Godot su `ext_resource, invalid UID` nelle scene
vendorizzate di GUT.

File/sistemi coinvolti:

- `addons/gut/*.tscn`;
- `addons/gut/gui/*.tscn`;
- eventuali `.uid` se si decide di versionarli per l'addon.

Criterio di accettazione:

- avvio GUT senza warning `invalid UID` su scene dell'addon;
- `.gitignore` resta coerente con la scelta sugli `.uid`.

### 5. Leak e resource still in use a shutdown

Obiettivo: distinguere cleanup correggibile nei test da rumore di engine/addon.

File/sistemi coinvolti:

- cache statiche (`WorldDataCache`, loader texture, manifest);
- teardown di nodi UI/runtime nei fixture;
- eventuali residui da GUT/Godot non eliminabili localmente.

Criterio di accettazione:

- riduzione misurabile di `ObjectDB instances leaked`,
  `resources still in use` e RID leaked dopo la correzione degli orphans;
- ogni residuo non risolto documentato con causa probabile.

### 6. Robustezza runner PowerShell sotto redirezione

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
