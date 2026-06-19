Agisci in modalità GOAL sulla repository GameProject.

Obiettivo: migliorare in modo iterativo la generazione dei biomi, partendo dal bioma starter/base, senza introdurre placeholder visivi e senza rompere la compatibilità con il gameplay esistente.

Prima di modificare:
1. Analizza lo stato attuale della generazione dei biomi, dei chunk, delle tile isometriche, degli ostacoli, dei burroni/void e degli eventuali sistemi di transizione tra biomi.
2. Individua i file principali coinvolti.
3. Scrivi un breve piano operativo nel log/risposta prima di implementare.
4. Se esiste già una roadmap o un file TODO relativo alla generazione isometrica, aggiornalo invece di crearne uno duplicato.

Implementazione richiesta per il bioma starter:

## 1. Struttura generale del bioma

Ogni bioma deve avere almeno una MAIN ROAD principale.

La main road deve:
- partire da un edge del bioma;
- arrivare a un altro edge del bioma;
- passare in modo credibile per l’area centrale della mappa;
- essere abbastanza larga da permettere movimento, combattimento e attraversamento da parte di più player e nemici;
- essere renderizzata con tile isometriche coerenti, non come semplice rettangolo piatto.

Possono esistere diramazioni di main road:
- una seconda o terza main road può partire dalla main road principale;
- può raggiungere un terzo edge del bioma;
- deve creare una topologia leggibile, non solo rumore casuale;
- le strade devono poter diventare in futuro collegamenti verso altri biomi.

## 2. Sentieri secondari

Dalla main road possono diramarsi sentieri più piccoli.

I sentieri possono:
- collegare due punti diversi della strada principale;
- creare scorciatoie;
- estendersi fino al border;
- raggiungere aree con case, radure, vegetazione, ponti o punti di interesse.

Regole:
- i sentieri devono essere più stretti della main road;
- devono avere transizioni grafiche credibili con erba, terra, vegetazione o altri pavimenti;
- non devono generare percorsi impossibili, spezzati o isolati;
- devono sempre essere attraversabili dai player, salvo ostacoli espliciti.

## 3. Suddivisione degli spazi rimasti

Dopo aver generato main road e sentieri, i chunk/spazi rimasti tra le strade devono essere classificati e riempiti.

Tipologie possibili:
- case;
- recinzioni;
- fitta vegetazione;
- automobili;
- radure libere;
- piccoli ostacoli decorativi;
- zone void/burroni;
- eventuali punti d’acqua come fiumi o laghi.

La scelta deve dipendere dalla forma e dimensione del chunk:
- se il chunk è abbastanza quadrato o rettangolare, dare priorità a case o piccoli gruppi di case;
- se il chunk è stretto o irregolare, preferire recinzioni, vegetazione, automobili o ostacoli naturali;
- se il chunk è grande, può contenere più sotto-oggetti, ma deve restare leggibile;
- evitare distribuzioni casuali uniformi: gli oggetti devono sembrare piazzati con logica ambientale.

## 4. Case isometriche

Le case devono diventare una priorità visiva nel bioma starter.

Requisiti:
- le case devono essere renderizzate in vera visuale isometrica, con volume, pareti e tetto;
- devono essere coerenti con lo stile del personaggio e della camera;
- devono occupare chiaramente uno spazio sul terreno;
- devono avere collisione coerente con il footprint;
- non devono sembrare icone piatte incollate sul pavimento;
- non usare placeholder geometrici se esiste un sistema di sprite/asset proceduralmente disegnati;
- se mancano asset adeguati, crea asset procedural/art finiti semplici ma credibili.

Le case possono essere:
- piccola casa singola;
- casa lunga;
- casetta abbandonata;
- capanno;
- gruppo di 2-3 case se lo spazio lo consente.

## 5. Vegetazione fitta impenetrabile

Implementare chunk di fitta vegetazione.

Requisiti:
- la vegetazione fitta deve essere chiaramente diversa da erba normale o decorativa;
- deve essere impenetrabile;
- deve bloccare player, zombie, proiettili se coerente con il sistema attuale;
- deve essere usata come ostacolo di pathing;
- deve apparire come massa vegetale densa, non come singoli cespugli sparsi;
- deve avere bordi leggibili rispetto ai sentieri e alla strada.

Se il sistema di collisioni distingue ostacoli morbidi/duri, aggiungi una categoria specifica tipo dense_vegetation o equivalente.

## 6. Recinzioni e automobili

Aggiungere ostacoli ambientali secondari.

Recinzioni:
- possono delimitare case, campi, cortili o sentieri;
- devono avere orientamento isometrico coerente;
- devono creare piccoli corridoi e strozzature;
- possono essere parzialmente rotte, ma non devono generare pathing impossibile senza intenzione.

Automobili:
- devono essere isometriche;
- possono stare lungo le main road o vicino alle case;
- devono avere collisione chiara;
- devono contribuire alla creazione di coperture/ostacoli;
- devono avere almeno qualche variante grafica semplice.

## 7. Fiumi, laghi e ponti

Oltre ai burroni/void, ogni mappa può avere un fiume.

Il fiume può:
- attraversare la mappa da edge a edge;
- nascere da un edge e finire in un lago;
- dividere temporaneamente la mappa in due aree.

Requisito fondamentale:
- il passaggio da una parte all’altra del fiume deve essere sempre garantito.

Il passaggio può avvenire tramite:
- ponte;
- guado/sentiero attraversabile;
- passerella;
- strada principale che attraversa il fiume.

Regole:
- non generare mai un fiume che separa aree raggiungibili senza almeno un attraversamento valido;
- se la main road interseca il fiume, generare automaticamente un ponte;
- il ponte deve essere largo abbastanza per player e nemici;
- il pathfinding deve considerare il ponte come walkable;
- l’acqua deve essere non attraversabile salvo tile esplicitamente marcate come ponte/guado.

Graficamente:
- il fiume deve essere isometrico e leggibile;
- le rive devono avere transizioni;
- il lago deve avere bordo chiaro;
- evitare acqua piatta rettangolare senza contesto.

## 8. Burroni / void

Mantenere e migliorare la resa dei burroni.

Requisiti:
- i void devono essere chiaramente pericolosi;
- i bordi devono mostrare verticalità, profondità o pareti discendenti;
- il giocatore deve capire visivamente dove cade;
- non confondere void, acqua e terreno calpestabile;
- i ponti o passaggi sopra void/fiumi devono essere visivamente evidenti.

## 9. Navigabilità e validazione

Dopo la generazione, eseguire una fase di validazione topologica.

La validazione deve controllare:
- la main road collega davvero due edge;
- eventuali diramazioni raggiungono correttamente il terzo edge;
- i sentieri non sono isolati;
- le aree importanti sono raggiungibili;
- case e ostacoli non bloccano completamente la main road;
- fiumi e laghi non dividono la mappa senza ponti;
- gli spawn point rimangono validi;
- player e zombie possono attraversare il bioma in modo credibile;
- il bioma non degenera in una mappa troppo vuota o troppo piena.

Se la validazione fallisce:
- correggi la generazione in modo deterministico;
- oppure rigenera solo la parte problematica;
- evita retry infiniti.

## 10. Seed e debug

La generazione deve restare deterministica tramite seed.

Aggiungi o migliora strumenti di debug:
- stampa del seed usato;
- overlay/debug log con numero di roads, paths, houses, dense vegetation chunks, bridges, river/lake;
- possibilità di riprodurre una mappa problematica;
- eventuale salvataggio snapshot/test se il progetto lo prevede.

## 11. Qualità visiva

Non accettare placeholder.

Ogni nuovo elemento deve avere una resa grafica almeno “giocabile”:
- tile coerenti;
- orientamento isometrico;
- collisione leggibile;
- profondità/ombra se coerente con il rendering;
- varianti minime per evitare ripetizione estrema.

Priorità visiva per questa iterazione:
1. main road isometrica leggibile;
2. case isometriche nei chunk quadrati;
3. vegetazione fitta impenetrabile;
4. fiume/lago con ponte garantito;
5. recinzioni e automobili come ostacoli secondari.

## 12. Test richiesti

Aggiungi o aggiorna test automatici dove possibile.

Minimo da verificare:
- generazione deterministica con seed;
- main road edge-to-edge;
- centro attraversato o vicino al centro;
- ponte generato se fiume interseca strada;
- fiume non blocca la raggiungibilità;
- dense vegetation non walkable;
- case con collisione coerente;
- nessun chunk importante completamente isolato;
- nessun crash durante rendering o gameplay.

Se il progetto non ha test automatici, aggiungi almeno una modalità debug/manual test documentata.

## 13. Output finale

Alla fine:
1. Riassumi i file modificati.
2. Spiega le regole di generazione introdotte.
3. Indica come testare manualmente il bioma starter.
4. Indica eventuali punti rimasti da iterare.
5. Aggiorna TODO/roadmap se esistente.
6. Non lasciare codice morto, placeholder evidenti o funzioni duplicate.

Procedi in modo incrementale, ma completa almeno una vertical slice funzionante del bioma starter:
main road edge-to-edge + sentieri + almeno un tipo di chunk con casa isometrica + vegetazione fitta impenetrabile + gestione opzionale fiume/ponte con validazione.