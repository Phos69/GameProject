# Streaming crash hardening - 2026-07-21

## Sintomo e ipotesi principale

Il crash/freeze e stato osservato dopo movimento prolungato tra biomi, fino a
rendere Windows poco responsivo. Senza dump o log della sessione non e possibile
attribuire retroattivamente una causa unica, ma il lifecycle conteneva un rischio
coerente con il sintomo: `WorldRegionRetirementQueue` avanzava solo nei frame
senza build regione, commit contenuti o commit chunk. Un percorso continuo poteva
quindi trattenere interi alberi invisibili piu rapidamente di quanto venissero
liberati, facendo crescere nodi, risorse e RID fino a pressione memoria/GPU.

## Difese implementate

1. Il retirement avanza sempre: un nodo/0,2 ms nei frame occupati, quattro
   nodi/0,8 ms nei frame liberi o quando il backlog raggiunge tre root.
2. La telemetria registra eta della root piu vecchia, massimo numero di root,
   totali accodati/completati e nodi ritirati, oltre alle metriche chunk/regioni.
3. `RuntimeDiagnostics` flusha ogni due secondi un JSONL con frame time, memoria
   di sistema e rendering, ObjectDB, modalita, regione e snapshot streaming.
4. Il file logging nativo Godot e esplicito e ruota dieci sessioni.
5. Un nuovo soak usa lo streaming reale e attraversa otto volte lo stesso seam;
   il precedente soak da dieci minuti passava `disable_region_streaming: true` e
   non esercitava il percorso segnalato.
6. I log di un playtest successivo hanno mostrato `current_region_id=biome_1_0`
   con `visible_visual_chunks=0`: la party aveva lasciato la banda del varco
   prima della readiness/cooldown, perdendo il cambio autoritativo. Il seam ora
   conserva il crossing pendente fino al commit o al ritorno nella source.

## Artefatti dopo un problema

Su Windows, raccogliere prima di riavviare nuovamente il gioco:

- `%APPDATA%\Godot\app_userdata\Local Action Sandbox\diagnostics\runtime_previous.jsonl`;
- `runtime_latest.jsonl` se non si e ancora riavviato;
- `%APPDATA%\Godot\app_userdata\Local Action Sandbox\logs\godot.log` e file ruotati;
- ora dell'evento e percorso/biomi attraversati.

Un JSONL troncato e valido fino all'ultima riga completa. L'ultima fotografia
permette di distinguere almeno: memoria host esaurita, crescita ObjectDB,
retirement fermo, eccesso di regioni FULL, coda tile/contenuti o hitch senza
crescita memoria.

## Limite e strategia di escalation

Un kill del sistema, un reset GPU o un OOM possono impedire a codice GDScript di
scrivere uno stack finale. Se il problema ricompare con code bounded, il passo
successivo e acquisire un dump nativo della build esportata tramite Windows Error
Reporting LocalDumps oppure ProcDump, insieme ai due log. Il dump serve a
separare crash del renderer/driver, deadlock worker e access violation engine;
la black box descrive invece lo stato nei secondi precedenti.

## Accettazione e test

- `world_region_streamer_unload_test.gd`: 9/9, 40 assert.
- `diagnostics_test.gd`: 3/3, 41 assert.
- `world_graph_streaming_test.gd`: 8/8, 53 assert, incluso attraversamento
  completato dopo aver lasciato la fascia del passaggio.
- `integration_test.gd`: 11/11, 865 assert.
- `region_streaming_churn_test.gd`: 1/1, 82 assert, otto attraversamenti reali
  con rimbalzo sul seam, uscita dalla banda, drain e crescita nodi verificati.
- build smoke con `--runtime-diagnostics`: exit code 0 e JSONL leggibile.

La telemetria di una sessione successiva ha mostrato un secondo caso reale:
crossing pendente `biome_1_1 -> biome_1_2`, seguito da un singolo rientro
geometrico sul lato sorgente e quindi da oltre un minuto di mismatch senza
pending. Il seam mantiene ora il crossing durante le oscillazioni che restano
nella banda fisica del passaggio e lo annulla soltanto dopo un rientro netto.
- Residuo manuale: percorso di almeno 20 seam/20 minuti a rendering reale,
  verificando p95/max frame e assenza di crescita dopo i ritorni.
