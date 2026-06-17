Obiettivo:
Analizza la TODO attuale della repository e crea un piano organico per completare tutti i punti aperti, trasformandoli in una roadmap ordinata, realistica e divisa per aree tematiche e milestones eseguibili successivamente in modalità Goal.

Repo:
Usa la repository corrente. Prima di modificare qualsiasi cosa, ispeziona:
- TODO.md
- README.md
- AGENTS.md
- eventuali roadmap già presenti
- documenti nella cartella docs/
- changelog, note agenti, issue locali o file markdown rilevanti
- struttura del codice sorgente, per capire quali aree sono già implementate e quali sono incomplete

Vincolo importante:
NON implementare feature di gameplay in questo task.
Questo goal deve produrre principalmente un documento di pianificazione chiaro, completo e utilizzabile per far partire goal successivi.

Output richiesto:
Crea un nuovo file nella root della repo chiamato:

todo_roadmap.md

Il file deve essere scritto in italiano e deve contenere una roadmap organica divisa in milestones.

Struttura obbligatoria del file todo_roadmap.md:

1. Titolo e obiettivo generale
   - Spiega che il documento converte la TODO esistente in una roadmap operativa.
   - Specifica che le milestones sono pensate per essere eseguite una alla volta in modalità Goal.

2. Stato attuale sintetico
   - Riassumi cosa sembra già presente nella repo.
   - Riassumi cosa manca o è incompleto.
   - Evidenzia eventuali aree confuse, duplicate o parzialmente implementate nella TODO.

3. Aree tematiche
   Raggruppa tutti i punti della TODO in aree coerenti, ad esempio:
   - Architettura core e pulizia tecnica
   - Menu, navigazione e UX
   - Selezione personaggi
   - Character design, sprite, animazioni e coerenza grafica
   - Classi RPG, armi base, passive e super
   - Combattimento, hitbox, danni, status effect e bilanciamento
   - Zombie mode, spawn, ondate, casse e progressione partita
   - Biomi, ostacoli, generazione isometrica e mega-mappa persistente
   - Esplorazione, grafo dei biomi, mappa territori e transizioni aperte
   - Nemici specifici per bioma e incontri casuali
   - UI/HUD grafica: vita, ammo, bombe, adrenalina, risorse
   - Save/load, persistenza, seed e riproducibilità
   - Test, debug, CI, QA e verifica commit
   - Documentazione e workflow agenti

   Usa le aree effettivamente rilevate nella TODO, non limitarti a questa lista se trovi altro.

4. Milestones ordinate
   Crea milestones numerate, ad esempio:
   - Milestone 0: Audit, consolidamento TODO e baseline tecnica
   - Milestone 1: Stabilizzazione menu e navigazione
   - Milestone 2: Refactor selezione personaggi
   - Milestone 3: Classi RPG e identità gameplay dei personaggi
   - Milestone 4: Armi, hitbox, passive e super
   - Milestone 5: HUD grafica e feedback di gioco
   - Milestone 6: Zombie mode revamp
   - Milestone 7: Biomi isometrici e ostacoli coerenti
   - Milestone 8: Mega-mappa persistente e grafo dei territori
   - Milestone 9: Nemici, incontri casuali e status effect
   - Milestone 10: Bilanciamento, polish e test end-to-end
   - Milestone 11: Documentazione finale e workflow di iterazione

   Adatta nomi, ordine e numero delle milestones in base alla TODO reale.

5. Per ogni milestone inserisci:
   - Obiettivo
   - Perché va fatta in questo ordine
   - Punti TODO coperti
   - File/cartelle probabilmente coinvolti
   - Task concreti
   - Dipendenze da milestones precedenti
   - Criteri di accettazione verificabili
   - Test manuali da eseguire
   - Eventuali test automatici o script da aggiungere
   - Rischi tecnici
   - Prompt breve consigliato per lanciare quella milestone in modalità Goal

6. Sezione “Prompt Goal riutilizzabili”
   Alla fine del file, aggiungi una sezione con prompt brevi già pronti per lanciare ogni milestone una alla volta.
   Ogni prompt deve essere autonomo, copia-incollabile e deve dire a Codex:
   - quale milestone eseguire
   - di leggere todo_roadmap.md
   - di rispettare i criteri di accettazione
   - di aggiornare TODO.md solo a fine lavoro
   - di non iniziare milestone successive

7. Sezione “Ordine consigliato di esecuzione”
   Crea una lista numerata con l’ordine in cui conviene far partire i goal.
   Evidenzia eventuali milestones che possono essere parallelizzate e quelle che invece devono essere sequenziali.

8. Sezione “Definizione di completato”
   Definisci quando la TODO può essere considerata completata:
   - nessun punto TODO critico aperto
   - gameplay base funzionante
   - selezione personaggi stabile
   - personaggi distinguibili per grafica e gameplay
   - biomi isometrici navigabili
   - zombie mode giocabile
   - HUD leggibile e grafico
   - test manuali documentati
   - README aggiornato

Regole operative:
- Prima fai un audit completo della TODO e dei markdown esistenti.
- Non cancellare punti della TODO senza motivazione.
- Se trovi duplicati, accorpali nella roadmap.
- Se trovi punti troppo grandi, spezzali in task più piccoli.
- Se trovi feature parzialmente implementate, segnala cosa manca per completarle.
- Non fare refactor massivi non richiesti.
- Non implementare gameplay in questo goal.
- Limita le modifiche al nuovo file todo_roadmap.md, salvo piccolissimi aggiornamenti a TODO.md solo se strettamente necessari per linkare la roadmap.
- Mantieni il documento leggibile, concreto e utile per agenti successivi.
- Ogni milestone deve poter diventare un goal indipendente.

Dopo aver creato il file:
- Mostra un riepilogo breve delle aree tematiche trovate.
- Mostra l’elenco delle milestones create.
- Indica il path del file creato.
- Indica eventuali punti TODO ambigui che richiedono decisione umana.
- Non avviare implementazioni successive.