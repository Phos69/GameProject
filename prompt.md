Analizza lo stato attuale della repository GameProject con focus esclusivo sulla migrazione verso un’ambientazione completamente isometrica.

Obiettivo:
capire cosa ci siamo persi per strada nella migrazione grafica e strutturale verso biomi/mappe totalmente isometrici, soprattutto per quanto riguarda:
- generazione dei biomi;
- terrain isometrico;
- oggetti ambientali;
- ostacoli;
- props;
- bordi del bioma;
- zone di caduta;
- connessioni tra biomi;
- coerenza visiva tra gameplay, mappa e navigazione;
- sostituzione di asset non isometrici con equivalenti isometrici;
- eventuali sistemi chiamati nel codice “genomi”, “biomi”, “biome generation”, “terrain generation”, “map generation” o simili.

Prima fase: audit completo
1. Esplora la repo e individua tutti i file coinvolti in:
   - generazione mappa/bioma;
   - spawn oggetti/ostacoli/props;
   - rendering isometrico;
   - tilemap/terrain;
   - collisioni;
   - pathfinding o navigazione;
   - transizioni tra biomi;
   - minimappa/mappa territori esplorati;
   - asset loading;
   - menu o debug relativi ai biomi.

2. Ricostruisci lo stato attuale:
   - cosa è già realmente isometrico;
   - cosa è ancora top-down, placeholder, flat, non coerente o non convertito;
   - quali oggetti sono ancora fuori stile;
   - quali biomi sono incompleti;
   - quali funzioni sembrano duplicate, abbandonate o parziali;
   - quali TODO/commenti/roadmap esistenti sono rimasti non implementati.

3. Cerca esplicitamente regressioni o feature lasciate a metà rispetto agli obiettivi precedenti:
   - bioma 200x200 completamente riempito da terreno calpestabile;
   - sfondo non limitato solo al centro;
   - ostacoli isometrici coerenti;
   - case/strutture grandi che creano corridoi;
   - muri sui lati confinanti;
   - vuoto/caduta sui lati non confinanti;
   - passaggi aperti tra biomi connessi;
   - grafo dei biomi completamente connesso;
   - megamappa persistente;
   - mappa dei territori esplorati;
   - zone dove si cade leggibili visivamente in isometrico;
   - dodge/roll utile anche per saltare piccoli vuoti;
   - coerenza fra collisioni e rappresentazione visiva.

Seconda fase: output richiesto
Crea o aggiorna un file:

docs/isometric_generation_audit_roadmap.md

Il file deve contenere:

1. Stato attuale sintetico
   - elenco dei sistemi già presenti;
   - file principali coinvolti;
   - cosa funziona;
   - cosa è incompleto.

2. Gap analysis
   Dividi i problemi in aree:
   - Terrain e tile isometrici;
   - Oggetti ambientali e props;
   - Ostacoli e collisioni;
   - Biomi e generazione procedurale;
   - Bordi, muri, vuoto e caduta;
   - Connessioni tra biomi;
   - Megamappa persistente;
   - Mappa esplorata/UI;
   - Asset e art direction;
   - Debug tooling;
   - Performance e compatibilità.

3. Lista dei punti persi per strada
   Per ogni punto indica:
   - descrizione;
   - file coinvolti;
   - stato: mancante / parziale / rotto / placeholder;
   - impatto sul gameplay;
   - dipendenze tecniche;
   - priorità: P0, P1, P2.

4. Roadmap organica in milestone
   La roadmap deve essere realistica, iterativa e adatta a essere eseguita in modalità goal.
   Usa questa struttura:

   Milestone 1 — Audit tecnico e pulizia nomenclatura
   Milestone 2 — Base terrain isometrico 200x200
   Milestone 3 — Oggetti e ostacoli isometrici
   Milestone 4 — Collisioni coerenti con props e strutture
   Milestone 5 — Bordi del bioma, muri, vuoto e caduta
   Milestone 6 — Connessioni aperte tra biomi
   Milestone 7 — Grafo biomi completamente connesso
   Milestone 8 — Megamappa persistente
   Milestone 9 — Mappa territori esplorati
   Milestone 10 — Polish grafico e sostituzione placeholder
   Milestone 11 — Test, debug overlay e regressioni

5. Per ogni milestone includi:
   - obiettivo;
   - modifiche tecniche;
   - file probabili da modificare;
   - criteri di accettazione verificabili;
   - test manuali;
   - rischi;
   - sotto-task ordinati.

6. Crea anche una sezione finale:
   “Prompt iterativo per continuare la roadmap”
   con un prompt breve che posso copiare più volte per farti implementare la milestone successiva senza perdere il contesto.

Terza fase: implementazione minima
Dopo aver creato la roadmap:
- non implementare ancora grossi refactor;
- fai solo eventuali modifiche leggere se servono a rendere la roadmap tracciabile, per esempio:
  - aggiungere TODO tecnici nei file corretti;
  - aggiungere riferimenti nel README o nel TODO principale;
  - creare cartelle docs se mancanti;
  - collegare la nuova roadmap ai documenti esistenti.

Vincoli:
- Non cancellare sistemi esistenti senza motivo.
- Non rompere le modalità già funzionanti.
- Non introdurre asset pesanti o generati casualmente se non necessari.
- Non limitarti a una roadmap generica: deve essere basata sui file reali della repo.
- Ogni affermazione sulla roadmap deve derivare da codice o asset effettivamente trovati.
- Se trovi termini ambigui come “genomi” verifica se nel codice esistono davvero o se probabilmente indicano “biomi/generazione”.
- Alla fine esegui i test disponibili o almeno indica chiaramente quali non sono eseguibili e perché.

Output finale nella risposta:
1. riepilogo breve dell’audit;
2. file creato/modificato;
3. prime 3 priorità consigliate;
4. comando/test eseguiti;
5. prossimo prompt da lanciare in modalità goal.