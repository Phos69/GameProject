Analizza la repo del gioco e implementa un primo sistema completo di texture isometriche per pavimenti, muri e cliff/void, partendo dal bioma base foresta.

Obiettivo:
Riscrivere/estendere gli asset grafici del terreno del bioma foresta in modo che ogni zona sia chiaramente leggibile in visuale isometrica, senza placeholder. Le texture devono includere anche transizioni visive tra un tipo di terreno e l’altro.

Contesto:
Il gioco deve avere biomi isometrici credibili. Non basta avere tile piatti centrali: ogni pavimento, bordo, muro e zona di caduta deve comunicare chiaramente se è calpestabile, ostacolo, bordo pericoloso o void. Repo di riferimento: :contentReference[oaicite:0]{index=0}

Implementa o prepara gli asset per il bioma base foresta:

1. Pavimenti calpestabili
   - Sentiero stretto:
     - terra battuta
     - larghezza logica compatibile con i path già previsti
     - bordi irregolari naturali
     - variazioni leggere tra tile per evitare ripetizione evidente
   - Strada larga:
     - strada sterrata più ampia e leggibile
     - può avere pietre, solchi, radici, fango leggero
     - deve distinguersi chiaramente dal sentiero
   - Erba:
     - terreno base del bioma foresta
     - texture persistente per tutto il bioma
     - varianti leggere: ciuffi, foglie, sassolini, radici
   - Erba alta:
     - deve essere distinguibile dall’erba normale
     - più densa, più scura/alta, con volume isometrico
     - può essere usata come ostacolo leggero, decorazione o zona semi-pericolosa in futuro

2. Void / cliff / zone da cui si cade
   - Il void non deve sembrare semplicemente “nero” o “mancanza di tile”.
   - Deve essere evidente che il giocatore cade se entra lì.
   - Crea un bordo cliff isometrico leggibile:
     - lato verticale del terreno visibile
     - linee verticali/discesa dal bordo calpestabile
     - ombra profonda sotto il bordo
     - eventuale nebbia/scuro in basso
   - I confini tra terreno calpestabile e void devono avere texture dedicate:
     - bordo nord/sud/est/ovest
     - angoli interni/esterni
     - raccordi diagonali compatibili con griglia isometrica
   - Evita transizioni ambigue: il giocatore deve capire subito dove si può camminare e dove si cade.

3. Muri esterni montagna
   - Intorno al chunk/bioma, dove serve delimitare lo spazio, usa muri verticali naturali di montagna/roccia.
   - Devono sembrare pareti alte, non semplici blocchi piatti.
   - Prevedi:
     - parete rocciosa frontale
     - pareti laterali
     - angoli
     - raccordi con terreno erboso
     - eventuali radici, muschio, crepe, pietre sporgenti
   - I muri esterni devono bloccare chiaramente il passaggio.
   - Se un lato confina con un altro bioma, lascia possibilità di apertura/passaggio invece del muro continuo.

4. Transizioni tra zone
   Ogni coppia importante di terreni deve avere una transizione visiva.
   Implementa preferibilmente texture dedicate o, se più pratico, overlay/edge mask applicati sui tile.

   Transizioni richieste:
   - erba → sentiero
   - erba → strada
   - erba → erba alta
   - sentiero → strada
   - erba/sentiero/strada → cliff/void
   - erba → muro montagna
   - strada/sentiero → apertura tra muri o passaggio verso altro bioma

   Le transizioni devono funzionare con:
   - bordi dritti
   - angoli
   - incroci
   - raccordi a T
   - curve naturali
   - tile isolati o piccoli cluster

5. Requisiti grafici
   - Niente placeholder.
   - Niente rettangoli colorati provvisori.
   - Niente texture piatte senza profondità.
   - Ogni asset deve essere pensato per visuale isometrica.
   - Ogni tile deve avere volume, ombre coerenti e bordo leggibile.
   - Le cliff devono essere più scure/profonde rispetto al terreno.
   - I muri montagna devono avere altezza e silhouette riconoscibile.
   - Le texture devono essere modulari e riutilizzabili.
   - Le varianti devono essere randomizzabili tramite seed senza rompere la leggibilità.

6. Requisiti tecnici
   - Individua dove sono definiti/generati gli asset attuali del terreno.
   - Crea una struttura dati chiara per i terrain types:
     - forest_grass
     - forest_tall_grass
     - forest_path
     - forest_road
     - forest_void
     - forest_cliff_edge
     - forest_mountain_wall
   - Aggiungi supporto per edge/transition tiles:
     - grass_to_path
     - grass_to_road
     - grass_to_tall_grass
     - ground_to_void_cliff
     - ground_to_mountain_wall
     - path_to_road
   - Se il motore non supporta ancora tile transitions, implementa un sistema semplice basato sui vicini:
     - controlla i tile adiacenti
     - scegli automaticamente bordo, angolo o transizione
     - usa varianti seeded
   - Mantieni compatibilità con la generazione esistente.
   - Non rompere gameplay, collisioni o pathfinding.
   - Le zone void devono essere marcate anche a livello logico come non calpestabili/pericolose.
   - I muri montagna devono essere non attraversabili.

7. Primo risultato atteso
   Al termine voglio poter avviare il gioco e vedere il bioma foresta con:
   - erba base isometrica estesa
   - sentieri e strade distinguibili
   - erba alta riconoscibile
   - void leggibile con cliff edge e profondità
   - muri esterni montagna con volume verticale
   - transizioni credibili tra tutte le zone principali
   - nessun placeholder visibile

8. Output richiesto
   - Modifica il codice necessario.
   - Aggiungi eventuali nuovi asset generati/procedurali.
   - Aggiorna o crea documentazione breve in markdown spiegando:
     - terrain types aggiunti
     - sistema di transizioni
     - come aggiungere nuove texture per altri biomi
     - cosa resta da fare
   - Aggiungi una checklist finale dei test manuali da eseguire.

Procedi in modalità goal:
1. Prima analizza lo stato attuale della repo.
2. Poi individua il punto migliore dove inserire il sistema texture/transition.
3. Implementa un primo pass completo per il bioma foresta.
4. Avvia test/build disponibili.
5. Correggi gli errori.
6. Aggiorna la documentazione.
7. Lascia un report finale con file modificati, scelte fatte e follow-up consigliati.