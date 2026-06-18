Agisci in modalità GOAL sulla repository GameProject.

Obiettivo generale:
riscrivere completamente la generazione isometrica di ogni bioma partendo da zero, senza limitarsi a correggere la situazione attuale. In questo momento solo alcune tiles centrali sono isometriche: voglio una generazione isometrica completa, coerente, leggibile e giocabile su tutto il chunk.

Prima di modificare codice:
1. Analizza lo stato attuale della generazione biomi/mappe/tiles/ostacoli/collisioni/rendering.
2. Trova i file responsabili di:
   - generazione terrain/bioma/chunk;
   - rendering isometrico;
   - collisioni, pathfinding, ostacoli;
   - transizioni tra biomi;
   - danno da caduta/void;
   - asset grafici degli oggetti.
3. Se esiste già una roadmap o audit isometrico, aggiornala. Altrimenti crea `isometric_biome_generation_rewrite_roadmap.md`.
4. Lavora in modo incrementale: scegli il prossimo blocco non completato, implementalo davvero, testa, documenta cosa hai fatto e cosa resta.

Specifiche della nuova generazione:

A. Chunk base
- Il chunk/bioma base deve diventare 500x500 celle.
- La generazione deve partire da un chunk completamente VOID, senza pavimento.
- Il void non deve sembrare terreno nero/piatto: deve essere chiaramente un vuoto/fossa/caduta in visuale isometrica.
- I bordi calpestabili vicino al void devono avere resa visiva evidente, con profondità, ombre e/o linee verticali che facciano capire che il giocatore può cadere.
- Il void deve avere collisione/danno coerente: entrarci provoca caduta o danno da caduta, non deve essere attraversabile come pavimento.

B. Pareti perimetrali
- Genera pareti verticali isometriche tutto intorno al chunk.
- Le pareti devono essere alte, leggibili e coerenti con la prospettiva isometrica.
- Dove esistono connessioni verso altri biomi, il perimetro deve aprirsi in varchi/strade, non in portali placeholder.
- Evita portali trigger o caricamenti visibili: la transizione deve essere rappresentata da passaggi fisici coerenti con la mappa.

C. Strade e sentieri
- Dopo il void e le pareti, genera la rete di attraversamento.
- I sentieri devono avere larghezza 4 celle.
- Le strade principali devono avere larghezza 10 celle.
- Le strade devono diramarsi orizzontalmente e verticalmente, creando una rete leggibile.
- Alcune strade possono portare ad altri biomi tramite aperture sui bordi.
- La rete deve essere connessa: il giocatore deve poter attraversare il bioma senza rimanere bloccato.
- Strade e sentieri devono essere isometrici su tutta la loro estensione, non solo nella zona centrale.
- Le tiles del terreno devono avere varianti grafiche coerenti per bioma, con bordi, angoli, raccordi, transizioni e dettagli.

D. Blocchi interni tra le strade
- Le strade devono creare blocchi/quartieri/slot quadrati o rettangolari all’interno del chunk.
- Ogni blocco interno deve essere classificato proceduralmente, per esempio:
  - edificio/casa/gruppo di case;
  - bosco/alberi grandi;
  - rovine/rocce;
  - piazza/spazio aperto;
  - ostacoli grandi;
  - area parzialmente void;
  - area completamente void.
- Gli oggetti grandi devono occupare chiaramente slot isometrici e avere collisioni coerenti.
- Case, alberi, rocce, rovine o altri ostacoli grandi NON devono essere placeholder. Devono avere grafica finita, leggibile, con volume isometrico, ombre e proporzioni coerenti.
- Gli spazi aperti devono comunque avere resa grafica finita, non un rettangolo vuoto.
- Alcuni slot possono restare void, ma il void deve essere visivamente chiaro e giocabile/collidibile correttamente.

E. Oggetti piccoli e decorazioni
- Dopo aver generato struttura, strade e blocchi grandi, completa il bioma con oggetti piccoli:
  - cespugli;
  - fences/staccionate;
  - pietre;
  - tronchi;
  - casse;
  - lampioni/segni/props coerenti con il bioma;
  - piccoli dettagli ambientali.
- Gli oggetti piccoli devono rispettare:
  - griglia isometrica;
  - layer corretto;
  - collisione se necessario;
  - occlusione/profondità;
  - coerenza con il bioma.
- Non usare rettangoli colorati, icone provvisorie, sprite mancanti o placeholder evidenti.

F. Asset grafici
- Dai particolare cura agli asset.
- Ogni asset deve essere “finito” per quanto possibile nel codice/progetto attuale.
- Se il progetto usa asset sprite, crea o sostituisci gli asset necessari.
- Se il progetto usa rendering procedurale/canvas/shapes, costruisci oggetti isometrici composti da forme, ombre, dettagli, tetti, pareti, bordi e profondità.
- Ogni bioma deve avere un set visivo riconoscibile:
  - tile base;
  - varianti terreno;
  - strada/sentiero;
  - bordo void;
  - pareti;
  - ostacoli grandi;
  - oggetti piccoli.
- Rimuovi o sostituisci ogni placeholder grafico collegato alla generazione bioma.

G. Biomi
- Applica il nuovo sistema a ogni bioma esistente, non solo al bioma iniziale.
- Ogni bioma deve condividere la stessa logica strutturale, ma avere identità visiva diversa.
- Le tiles base o le loro varianti devono essere persistenti e coerenti su tutto il bioma.
- Gli ostacoli grandi devono cambiare in base al bioma.
- Gli oggetti piccoli devono essere tematici.
- Le strade/sentieri devono collegare correttamente eventuali biomi confinanti.

H. Gameplay e integrazione
- Mantieni compatibilità con player, zombie, collisioni, spawn, pathfinding e minimappa se presenti.
- Gli zombie devono poter inseguire il giocatore attraverso strade e passaggi.
- Non introdurre passaggi che bloccano il pathfinding senza motivo.
- Il giocatore non deve spawnare nel void o dentro ostacoli.
- I nemici non devono spawnare nel void o dentro ostacoli.
- Le aree calpestabili devono essere distinguibili dalle aree pericolose.
- La generazione deve essere deterministica rispetto al seed, se il progetto ha già un seed o se lo introduci.

Modalità iterativa:
A ogni esecuzione di questo prompt:
1. Leggi `isometric_biome_generation_rewrite_roadmap.md`, se esiste.
2. Identifica il prossimo step non completato più importante.
3. Implementa un incremento concreto e funzionante.
4. Non limitarti a scrivere TODO o stub.
5. Non lasciare placeholder grafici.
6. Aggiorna la roadmap marcando cosa è stato completato.
7. Aggiungi note tecniche su file modificati, decisioni prese e problemi rimasti.
8. Esegui test/build/lint disponibili.
9. Se non esistono test adeguati, aggiungi almeno test o debug utility minime per verificare:
   - dimensione chunk 500x500;
   - presenza void iniziale;
   - generazione pareti perimetrali;
   - larghezza sentieri 4;
   - larghezza strade 10;
   - connettività delle strade;
   - collisioni di void e ostacoli;
   - assenza di spawn invalidi;
   - rendering/layering degli oggetti isometrici.

Priorità consigliata dei passaggi:
1. Audit e roadmap della generazione attuale.
2. Nuovo modello dati per chunk 500x500, celle void, celle calpestabili, pareti, strade, sentieri, blocchi interni e props.
3. Generazione chunk completamente void.
4. Pareti verticali perimetrali e aperture verso biomi confinanti.
5. Generatore di strade principali larghe 10.
6. Generatore di sentieri larghi 4.
7. Segmentazione dei blocchi interni creati dalle strade.
8. Riempimento blocchi con ostacoli grandi, spazi aperti o void.
9. Collisioni e danno da caduta per il void.
10. Asset isometrici finiti per terreno, strade, pareti e void.
11. Asset isometrici finiti per case/alberi/rocce/ostacoli grandi.
12. Oggetti piccoli: cespugli, fences, pietre, props.
13. Applicazione del sistema a tutti i biomi.
14. Integrazione con spawn, zombie, pathfinding e transizioni.
15. Pulizia finale di placeholder, vecchio codice non usato e debug temporaneo.

Definition of Done:
- Il bioma è 500x500.
- Non esiste più una sola area centrale isometrica: tutta la generazione è isometrica.
- Il chunk parte concettualmente da void e viene poi scavato/riempito da strade, sentieri, blocchi e oggetti.
- Le strade sono larghe 10 celle.
- I sentieri sono larghi 4 celle.
- Le pareti perimetrali sono visibili e isometriche.
- Il void è visivamente chiaro e causa caduta/danno.
- I blocchi interni sono riempiti con oggetti grandi, spazi aperti o void.
- Gli oggetti grandi hanno grafica finita, collisioni e occupazione isometrica evidente.
- Gli oggetti piccoli arricchiscono il bioma senza rompere pathfinding o leggibilità.
- Tutti i biomi esistenti usano il nuovo sistema.
- Non restano placeholder evidenti nella generazione biomi.
- Build/test passano oppure viene documentato esattamente cosa fallisce e perché.

Alla fine della tua esecuzione, rispondi con:
- cosa hai implementato;
- file modificati;
- test eseguiti;
- cosa resta da fare nel prossimo ciclo;
- eventuale prompt breve consigliato per continuare.