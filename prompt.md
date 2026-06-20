Obiettivo: modifica la modalità zombie introducendo un mercato ricorrente dopo le ondate boss.

Analizza prima lo stato attuale della modalità zombie, del sistema ondate, boss, valuta/soldi, armi, ammo, HP, input multiplayer e GUI. Poi implementa la feature in modo integrato, senza workaround e senza placeholder.

REQUISITI GAMEPLAY

* Ogni 5 ondate deve esserci una ondata boss.
* Dopo aver sconfitto completamente l’ondata boss, prima dell’avvio dell’ondata successiva deve aprirsi il mercato.
* Esempio:

  * Wave 1-4 normali
  * Wave 5 boss
  * Boss sconfitto → mercato
  * Uscita dal mercato → Wave 6
  * Wave 10 boss → mercato
  * ecc.

MERCATO

* Il mercato deve essere una fase di gioco separata dallo spawn/combat.
* Durante il mercato non devono spawnare zombie.
* I giocatori devono poter acquistare usando i soldi comuni della run.
* La valuta è condivisa: ogni acquisto di un giocatore scala dal wallet comune.
* Se i soldi comuni non bastano, l’acquisto viene negato con feedback visivo/sonoro chiaro.
* Ogni giocatore deve poter comprare per sé:

  * HP / cura
  * Ammo / refill munizioni
  * Armi generate casualmente a ogni mercato

SHOP RANDOM

* A ogni apertura del mercato deve essere generata una nuova selezione casuale di armi acquistabili.
* Le armi devono essere pescate dal sistema armi esistente, rispettando rarità, categorie e vincoli già presenti se esistono.
* La selezione deve cambiare da mercato a mercato.
* Evita duplicati inutili nella stessa offerta.
* Il mercato deve mostrare chiaramente:

  * nome arma
  * tipo/categoria
  * costo
  * stats principali leggibili
  * eventuale rarità
  * se il player può permettersela o no

INTEGRAZIONE CON INVENTARIO ARMI

* Se esiste già un inventario armi per giocatore, l’arma comprata deve essere aggiunta all’inventario del giocatore che acquista.
* Non deve sovrascrivere l’arma attuale perdendo ammo/stato.
* Ogni arma deve mantenere il proprio stato: ammo, caricatore, cooldown, eventuali effetti.
* Se l’inventario è pieno, gestisci il caso in modo esplicito:

  * o impedisci l’acquisto con messaggio
  * o permetti la sostituzione/drop tramite UI, ma solo se coerente col codice esistente.
* Non introdurre bug dove un giocatore compra un’arma e viene assegnata a un altro.

HP E AMMO

* Acquisto HP:

  * Cura il player che acquista.
  * Non deve superare l’HP massimo, salvo esista già una meccanica di aumento max HP.
  * Se il player è già full HP, mostra feedback e non sprecare soldi, oppure rendi chiaro che sta comprando max HP se scegli quella variante.
* Acquisto Ammo:

  * Ricarica le munizioni del player che acquista.
  * Deve rispettare il sistema ammo esistente.
  * Se ci sono più armi, chiarisci se ricarica:

    * arma equipaggiata
    * tutte le armi
    * oppure un pacchetto ammo generico
  * Preferenza: implementa almeno un’opzione base “refill ammo arma equipaggiata” e, se semplice, una più costosa “refill ammo tutte le armi”.

GUI / UX MULTIPLAYER

* Il mercato deve essere navigabile da ogni giocatore.
* Ogni player deve avere una selezione/slot UI riconoscibile con il proprio colore o indicatore P1/P2/P3/P4.
* Deve essere chiaro chi sta acquistando cosa.
* Deve essere sempre visibile il totale dei soldi comuni.
* Deve essere possibile uscire dal mercato e continuare la run.
* Evita che un solo player chiuda il mercato accidentalmente per tutti senza conferma.
* Implementa una logica semplice tipo:

  * ogni player può segnarsi “ready”
  * quando tutti i player vivi/attivi sono ready, parte la wave successiva
  * oppure un pulsante “continua” con conferma chiara, se il sistema attuale non supporta ready multiplayer.

BILANCIAMENTO INIZIALE

* Definisci prezzi sensati e facili da modificare:

  * cura piccola/media
  * refill ammo
  * armi comuni/non comuni/rare
* I prezzi devono stare in una configurazione o costanti ben nominate, non hardcoded sparse nel codice.
* Il sistema deve poter essere esteso in futuro con perk, upgrade, revive, armor, reroll shop.

ROBUSTEZZA

* Il mercato deve aprirsi una sola volta dopo ogni boss wave completata.
* Non deve riaprirsi se la wave è già stata processata.
* Se tutti i player muoiono durante la boss wave, non deve aprirsi il mercato.
* Se il gioco viene resettato/nuova run, lo stato del mercato e delle offerte deve essere resettato.
* Il sistema deve funzionare anche se c’è un solo giocatore.
* Non rompere il normale avanzamento delle ondate.

IMPLEMENTAZIONE TECNICA

* Mantieni separati:

  * wave progression
  * shop/market state
  * shared currency
  * player purchase logic
  * UI rendering/input
* Evita duplicazione di codice.
* Se trovi codice già esistente per shop, upgrade, loot, armi random o valuta, riusalo e consolidalo.
* Se il codice attuale è confuso, fai un refactor minimo e mirato prima di implementare.
* Aggiungi commenti solo dove aiutano davvero a capire la logica.

OUTPUT RICHIESTO

Alla fine:

1. Implementa la feature.
2. Aggiungi o aggiorna test automatici dove possibile.
3. Esegui i test/build/lint disponibili nel progetto.
4. Crea o aggiorna un breve file di documentazione, ad esempio `docs/zombie_market.md` o sezione equivalente, spiegando:

   * quando appare il mercato
   * come funziona il wallet comune
   * cosa possono comprare i player
   * come viene generata l’offerta random
   * punti futuri di estensione

CRITERI DI ACCETTAZIONE

* Dopo la wave 5 boss, sconfitto il boss, si apre il mercato.
* Durante il mercato non spawnano zombie.
* I soldi comuni sono visibili e vengono scalati correttamente.
* Ogni player può comprare HP, ammo e armi per sé.
* Le armi offerte sono random e cambiano a ogni mercato.
* L’acquisto arma non sovrascrive in modo distruttivo l’arma attuale.
* Uscendo dal mercato la run continua dalla wave successiva.
* Il mercato riappare dopo le wave 10, 15, 20, ecc.
* Nessuna regressione evidente su combat, spawn, boss wave, inventario armi, input multiplayer e HUD.
