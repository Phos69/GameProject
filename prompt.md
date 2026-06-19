Analizza lo stato attuale della repo e implementa un passaggio completo su caduta nel vuoto e animazione di schivata.

OBIETTIVO
Voglio che player e zombie interagiscano correttamente con le celle void della mappa isometrica:
- non deve più bastare varcare una soglia/border per prendere danno;
- il trigger reale deve essere il calpestare una qualsiasi tile/cella void;
- se un personaggio supera il border o attraversa un vuoto tramite schivata, non deve subire danno durante il movimento della schivata;
- quando la schivata finisce, se il personaggio si trova ancora sopra una cella void, deve cadere.

REQUISITI PLAYER
1. Crea uno stato/animazione di caduta nel vuoto valido per tutti i player.
2. Quando un player finisce sopra una cella void:
   - blocca input/movimento normale;
   - avvia animazione di caduta;
   - applica il danno solo al momento effettivo della caduta, non al primo superamento del bordo;
   - dopo la caduta, riposiziona il player in una posizione sicura recente, oppure usa la logica di respawn/danno già presente se esiste.
3. Mantieni una memoria dell’ultima posizione sicura calpestabile per ogni player.
4. Se il player muore per caduta, usa la normale logica di morte del player.
5. Evita trigger ripetuti: durante lo stato falling il player non deve ricevere danni multipli frame-by-frame.

REQUISITI ZOMBIE
1. Crea una animazione di caduta nel vuoto anche per gli zombie.
2. Gli zombie devono poter cadere nel void se finiscono sopra una cella void.
3. Quando uno zombie cade:
   - muore dopo l’animazione;
   - non rilascia drop;
   - non dà exp;
   - non dà denaro/risorse;
   - non conta come kill premiata al player, salvo che il sistema abbia già una distinzione tecnica necessaria.
4. Evita che la morte da void passi dalla stessa pipeline delle morti causate dal player, oppure aggiungi un deathReason chiaro tipo "void", "fall", "environment".
5. Se esiste già un sistema di drop/exp/score, centralizza il controllo in modo che deathReason === void/fall disabiliti ogni reward.

REQUISITI SCHIVATA
1. Crea o completa una animazione di schivata valida per tutti i personaggi giocabili.
2. La schivata deve avere uno stato dedicato, ad esempio dodging, con:
   - durata definita;
   - direzione coerente con input corrente o facing direction;
   - movimento rapido;
   - animazione dedicata;
   - cooldown se già presente o da introdurre in modo semplice.
3. Durante la schivata il controllo void non deve interrompere subito il movimento.
4. Alla fine della schivata:
   - controlla la tile sotto il player;
   - se è calpestabile, torna allo stato normale;
   - se è void, avvia la caduta.
5. La schivata deve funzionare per tutti i PG, senza duplicare codice per ogni personaggio.

IMPLEMENTAZIONE TECNICA ATTESA
1. Prima analizza dove sono gestiti:
   - movimento player;
   - movimento zombie;
   - collisioni;
   - tile/terrain/void;
   - danno da caduta o danno ambientale;
   - morte zombie, drop ed exp;
   - animazioni/stati player.
2. Introduci una funzione unica e riusabile per capire se una entity sta calpestando void, ad esempio:
   - isVoidAtWorldPosition(x, y)
   - isWalkableAtWorldPosition(x, y)
   - getTerrainAtWorldPosition(x, y)
   Scegli il nome coerente con il codice esistente.
3. Il controllo deve basarsi sulla posizione reale dell’entità sul terreno, non solo sul bounding box che supera il bordo.
4. Crea uno stato entity coerente:
   - normal / moving
   - dodging
   - falling
   - dead
5. Evita duplicazione tra player e zombie: se possibile crea helper condivisi per falling/void detection.
6. Mantieni compatibilità con multiplayer locale: ogni player deve avere stato di dodge/fall indipendente.
7. Non introdurre placeholder visivi se esiste già una pipeline grafica/animazioni. Se mancano asset definitivi, crea animazioni semplici ma pulite usando sprite/shape coerenti con lo stile attuale e lascia TODO tecnici chiari solo dove inevitabile.
8. Non rompere la generazione isometrica esistente.

ANIMAZIONE CADUTA
La caduta deve essere leggibile:
- entity che scivola/precipita verso il basso;
- riduzione progressiva di scala o alpha;
- eventuale ombra che si separa o si riduce;
- breve lock dello stato;
- rimozione zombie solo a fine animazione;
- applicazione danno player solo una volta durante/fine animazione.

ANIMAZIONE SCHIVATA
La schivata deve essere visibile:
- piccolo dash nella direzione;
- frame/pose inclinata o effetto streak;
- durata breve;
- ritorno fluido allo stato idle/move;
- nessun blocco se il player attraversa momentaneamente void durante il dash.

ACCETTAZIONE
Alla fine verifica manualmente e/o con test mirati che:
1. Un player fermo su terreno normale non cade.
2. Un player che cammina su una cella void cade e prende danno una sola volta.
3. Un player che supera un border con schivata non prende danno durante la schivata.
4. Se alla fine della schivata è ancora sopra void, cade.
5. Se alla fine della schivata arriva su terreno valido, non cade.
6. Uno zombie che finisce su void fa animazione di caduta e poi sparisce.
7. Uno zombie morto per void non genera drop, exp, denaro o reward.
8. La logica funziona con più player contemporaneamente.
9. Non ci sono errori console.
10. Non vengono introdotte regressioni su movimento, collisioni e combattimento.

OUTPUT RICHIESTO
- Implementa le modifiche direttamente nel codice.
- Aggiorna eventuali documenti tecnici/TODO se esistono.
- Alla fine produci un report sintetico con:
  - file modificati;
  - nuova architettura degli stati dodge/fall;
  - come viene rilevato il void;
  - come viene impedito drop/exp per zombie caduti;
  - test eseguiti;
  - eventuali follow-up consigliati.