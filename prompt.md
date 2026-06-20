Agisci in modalità goal sulla repository.

Obiettivo: analizzare lo stato attuale della repo e produrre un report tecnico completo, seguito da una roadmap operativa su file per risolvere i problemi principali.

Repository di riferimento:
https://github.com/Phos69/GameProject

Cosa devi fare:

1. Analisi iniziale della repo

* Esamina struttura delle cartelle, file principali, entrypoint, asset, moduli di gameplay, generazione mappa/biomi, rendering, GUI/HUD, input joypad, sistema armi, nemici, drop, progressione e modalità zombie.
* Identifica quali parti sembrano consolidate, quali sono incomplete, quali sono duplicate e quali responsabilità sono sparse in troppi file.
* Verifica se esistono TODO, roadmap precedenti, documentazione tecnica o file markdown già presenti, e usali come contesto.
* Esegui i test disponibili, lint/typecheck/build se presenti, oppure documenta chiaramente che non esistono o che falliscono.
* Non limitarti a leggere i nomi dei file: apri il codice e valuta lo stato reale dell’implementazione.

2. Report tecnico
   Crea un file `repo_status_report.md` nella root della repo con queste sezioni:

# Repo Status Report

## 1. Executive summary

Sintesi chiara dello stato attuale del progetto: cosa funziona, cosa è fragile, cosa blocca l’evoluzione.

## 2. Architettura attuale

Descrivi i principali sistemi del gioco:

* game loop
* rendering/isometria
* generazione biomi/mappa
* player e controlli
* armi e combattimento
* zombie/nemici
* HUD/GUI
* asset grafici
* drop/progressione
* modalità di gioco

## 3. Problemi principali

Elenca i problemi più importanti ordinati per impatto:

* bug bloccanti
* codice duplicato
* responsabilità confuse
* asset placeholder o incoerenti
* sistemi incompleti
* problemi di performance
* problemi di manutenibilità
* mancanza di test o strumenti di validazione

Per ogni problema indica:

* file coinvolti
* descrizione
* impatto sul gioco
* rischio tecnico
* proposta di soluzione

## 4. Debito tecnico

Evidenzia refactor necessari, moduli da separare, classi/funzioni troppo grandi, codice morto, naming incoerente e punti dove conviene creare astrazioni più pulite.

## 5. Stato gameplay

Valuta quanto il gioco è effettivamente giocabile oggi, con focus su:

* chiarezza visiva
* feedback del giocatore
* leggibilità HUD
* progressione
* varietà armi/nemici
* qualità della generazione mappa
* coerenza isometrica
* stabilità della modalità zombie

## 6. Stato asset grafici

Valuta:

* asset mancanti
* placeholder
* sprite non coerenti
* asset non isometrici
* elementi grafici poco leggibili
* oggetti che non rispettano l’occupazione reale sulla griglia

## 7. Test e validazione

Riporta:

* comandi eseguiti
* esito
* errori trovati
* test mancanti consigliati
* checklist manuale per verificare il gioco dopo ogni milestone

## 8. Raccomandazioni prioritarie

Chiudi il report con le 10 azioni più importanti da fare subito.

3. Roadmap operativa
   Crea un secondo file `repo_fix_roadmap.md` nella root della repo.

La roadmap deve essere divisa in milestone ordinate, ognuna abbastanza piccola da essere eseguibile in modalità goal separata.

Ogni milestone deve contenere:

## Milestone N - Titolo

### Obiettivo

Descrizione sintetica del risultato atteso.

### Problemi risolti

Elenco dei problemi del report che questa milestone affronta.

### Interventi tecnici

Lista concreta delle modifiche da fare, con file o aree coinvolte.

### Criteri di completamento

Checklist verificabile. Una milestone è completata solo se tutti i criteri sono soddisfatti.

### Test manuali

Passi concreti per provare il gioco e verificare che il comportamento sia corretto.

### Rischi

Possibili regressioni o punti da controllare.

La roadmap deve coprire almeno queste aree:

1. Stabilizzazione build/test/dev workflow

2. Pulizia architettura e riduzione duplicazioni

3. Refactor generazione mappa/biomi

4. Coerenza isometrica completa di terreno, ostacoli, void e cliff

5. Sistema asset grafici più pulito e non placeholder

6. Sistema armi/inventario/ammo/drop

7. Zombie, nemici, spawn e bilanciamento modalità zombie

8. HUD/GUI gameplay e character select

9. Input joypad e navigazione menu

10. Progressione, exp, drop, feedback visivo

11. Test automatici e checklist manuale

12. Documentazione per continuare lo sviluppo con Codex

13. Output finale nella risposta
    Alla fine del lavoro, rispondi con:

* elenco dei file creati/modificati
* sintesi dei problemi principali trovati
* milestone consigliata da eseguire per prima
* comandi eseguiti e relativo esito
* eventuali limiti dell’analisi se qualcosa non è stato possibile verificare

Regole importanti:

* Non implementare ancora fix profondi: questo goal serve prima a capire lo stato reale della repo e creare una roadmap.
* Puoi fare solo piccoli fix non invasivi se servono per eseguire test o leggere meglio il progetto, ma documentali.
* Non inventare problemi: ogni criticità deve essere collegata a file o codice reale.
* Non lasciare la roadmap generica: deve essere abbastanza concreta da poter essere eseguita milestone per milestone in goal successivi.
* Mantieni tono tecnico, diretto e operativo.
