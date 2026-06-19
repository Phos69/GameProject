GOAL: Revisione completa del rendering degli ostacoli e delle zone non accessibili nella mappa isometrica.

Contesto:
Attualmente la collisione/occupabilità della mappa non è sempre rispecchiata dal disegno. Alcune zone non accessibili sembrano attraversabili, alcuni ostacoli non occupano visivamente lo stesso footprint logico che occupano nella griglia, e gli oggetti grandi/piccoli non sono resi con regole coerenti in visuale isometrica.

Obiettivo:
Fare un passaggio organico su rendering, asset, footprint e debug degli ostacoli, in modo che ciò che è non accessibile sia chiaramente non accessibile anche a livello grafico.

Requisiti funzionali:

1. Coerenza tra collisione e disegno
- La sorgente di verità deve rimanere la mappa logica: tile/slot accessibile, void, cliff, ostacolo, edificio, vegetazione folta ecc.
- Ogni cella o area non attraversabile deve avere un rendering visivo coerente e leggibile.
- Nessun ostacolo deve essere solo “collisione invisibile”.
- Nessun disegno deve suggerire attraversabilità quando invece la zona è bloccata.
- Aggiungere, se utile, una modalità debug overlay che mostri footprint, celle occupate e tipo di blocco.

2. Ostacoli grandi
Gestire almeno queste categorie:
- case / edifici;
- vegetazione folta impenetrabile;
- grandi rocce / pareti naturali;
- eventuali blocchi speciali del bioma.

Per le case:
- Renderizzarle frontalmente/isometricamente, non come semplici placeholder top-down.
- Devono rispettare le stesse regole visive dei cliff/pareti: base chiaramente agganciata alla griglia, parte verticale visibile, ingombro chiaro.
- Il footprint della casa deve essere evidente: se occupa ad esempio 4x4, 5x3 o 6x6 slot, il giocatore deve capirlo dal disegno.
- La base deve coprire esattamente l’area occupata, mentre la parte verticale/tetto può salire sopra la base ma deve rispettare z-order e sorting.

Per la vegetazione folta:
- Deve sembrare veramente impenetrabile.
- Usare asset tipo alberi/cespugli/chiome dense in SVG o generati da SVG.
- Non deve sembrare un cespuglio decorativo attraversabile.
- Il bordo tra vegetazione e strada/sentiero deve essere leggibile.
- Aggiungere varianti modulari per evitare ripetizione visiva.

3. Oggetti piccoli
Gli oggetti piccoli possono restare SVG, ma devono essere pregenerati alla dimensione corretta e legati a footprint precisi.

Gestire almeno queste dimensioni:
- 1x1;
- 2x1;
- 1x2;
- 2x2;
- 3x1;
- 1x3;
- 3x2;
- 2x3;
- 3x3.

Esempi:
- roccia 1x1;
- roccia 2x2;
- tronco 3x1;
- cespuglio 2x1;
- masso grande 3x3;
- recinzione 1x3 o 3x1;
- detriti 2x2.

Regole:
- Ogni asset deve occupare esattamente lo slot dichiarato.
- Il pivot/anchor deve essere coerente con la griglia isometrica.
- Il bounding box visivo deve essere proporzionato al footprint.
- L’oggetto può avere altezza verticale extra, ma la base deve corrispondere allo spazio logico occupato.
- Evitare asset scalati runtime in modo casuale: creare dimensioni predefinite e consistenti.

4. Asset pipeline
- Individuare dove sono definiti/generati/caricati gli asset correnti.
- Creare o aggiornare una pipeline per generare/pregenerare SVG/immagini degli ostacoli nelle giuste dimensioni.
- Gli asset devono essere finiti, non placeholder.
- Organizzare gli asset per categoria e footprint, ad esempio:
  - obstacles/rocks/rock_1x1.svg
  - obstacles/rocks/rock_2x2.svg
  - obstacles/trees/dense_forest_3x3.svg
  - obstacles/houses/house_4x4.svg
  - obstacles/fences/fence_3x1.svg
- Se il progetto usa canvas, pygame, svg inline, spritesheet o altro sistema, integrarsi con l’architettura esistente senza creare doppioni inutili.

5. Rendering isometrico e z-order
- Verificare e correggere il sorting degli oggetti isometrici.
- Gli oggetti devono comparire davanti/dietro al player in base alla posizione nella griglia.
- Case, alberi e oggetti alti devono poter coprire parzialmente il personaggio quando il player passa dietro.
- La base dell’oggetto deve restare agganciata alla tile corretta.
- Evitare flickering o sorting incoerente quando il player si muove vicino agli ostacoli.

6. Zone non accessibili e void
- Le zone void/cliff devono continuare a essere chiaramente distinguibili dagli ostacoli solidi.
- Se una zona è non accessibile perché è un muro, una casa o vegetazione, deve avere un disegno diverso dal void.
- Se una zona è void/caduta, usare bordi, pareti verticali o cliff per far capire che lì si cade.
- Evitare che un blocco non accessibile sembri solo terreno normale.

7. Integrazione con generazione mappa
- Collegare i tipi di ostacolo generati dalla mappa ai nuovi asset.
- Ogni ostacolo generato deve avere:
  - tipo;
  - footprint;
  - celle occupate;
  - asset/variante;
  - altezza visiva se necessaria;
  - proprietà di collisione.
- Aggiornare la generazione per non piazzare asset incompatibili con lo spazio disponibile.
- Gli ostacoli grandi devono occupare realmente blocchi grandi, non essere disegnati come piccoli oggetti sparsi.

8. Pulizia tecnica
- Rimuovere placeholder, duplicazioni e vecchie logiche grafiche incompatibili.
- Non introdurre sistemi paralleli se esiste già un renderer o asset manager.
- Separare chiaramente:
  - dati logici della mappa;
  - definizione footprint;
  - asset grafico;
  - collisione;
  - rendering.
- Se servono nuove classi/strutture, documentarle brevemente.

9. Test e verifica
Aggiungere o aggiornare test/manual checks per verificare:
- footprint logico uguale al footprint renderizzato;
- nessuna collisione invisibile;
- nessun ostacolo disegnato fuori slot in modo errato;
- z-order corretto con player davanti/dietro;
- case e vegetazione folta chiaramente non attraversabili;
- oggetti piccoli 1x1, 2x2, 3x3, 3x1 ecc. renderizzati nella dimensione giusta;
- void/cliff distinguibili dagli ostacoli solidi.

Output richiesto:
- Implementare le modifiche direttamente nella repo.
- Aggiungere o aggiornare documentazione breve, ad esempio in docs/obstacle_rendering.md o file simile, spiegando:
  - come funziona il mapping ostacolo -> footprint -> asset;
  - come creare nuovi asset;
  - come verificare collisione e rendering.
- Alla fine fornire un report con:
  - file modificati;
  - asset aggiunti;
  - regole implementate;
  - eventuali limiti rimasti;
  - prossimi miglioramenti consigliati.

Criteri di accettazione:
- Guardando la mappa, il giocatore deve capire immediatamente cosa è attraversabile e cosa no.
- Gli ostacoli grandi devono sembrare parte reale dell’ambiente isometrico.
- Gli oggetti piccoli devono occupare esattamente il footprint dichiarato.
- Case, vegetazione folta, rocce, recinzioni e cliff devono avere identità grafica distinta.
- Non devono esistere blocchi non accessibili senza rappresentazione grafica coerente.
- Non devono esserci placeholder evidenti.