GOAL: fare un passaggio completo sulla grafica delle armi appena create, in modo che ogni arma sia immediatamente riconoscibile sia quando è equipaggiata/usata, sia quando è droppata a terra, sia attraverso i suoi proiettili o effetti visivi.

Contesto:
Abbiamo appena introdotto un sistema con molte nuove armi (da fuoco, melee, elementali). Ora bisogna migliorare la loro identità visiva. Al momento non voglio placeholder generici o pickup indistinguibili: ogni arma deve avere una grafica propria e leggibile in gameplay.

Obiettivi principali:
1. Ogni arma deve avere una grafica unica e riconoscibile.
2. Quando un’arma viene droppata a terra, il pickup deve già mostrare chiaramente la forma reale dell’arma, non un’icona generica.
3. Quando l’arma viene utilizzata, la sua resa visiva deve essere coerente con quella del drop.
4. Anche i proiettili / hitbox / slash / effetti devono essere temizzati in base all’arma.
5. Il risultato deve essere coerente con lo stile del progetto e con la visuale isometrica/top-down attuale.

REQUISITI

1. Identità visiva unica per ogni arma
- Ogni arma deve avere una silhouette distinta.
- Non basta cambiare colore ad asset quasi uguali: servono forme riconoscibili.
- Le armi devono essere distinguibili a colpo d’occhio anche in scene affollate.
- Differenziare chiaramente:
  - pistole leggere
  - shotgun
  - rifle
  - heavy weapon
  - armi melee leggere
  - armi melee pesanti
  - armi elementali / arcane

2. Coerenza tra drop ed arma equipaggiata
- Quando l’arma è a terra come pickup, deve già avere l’aspetto dell’arma vera.
- Il pickup non deve essere un box, un’icona generica o un placeholder non leggibile.
- L’arma droppata può essere una versione semplificata, ma deve mantenere:
  - forma generale
  - colori principali
  - eventuali dettagli iconici
- Quando il player la impugna, deve risultare chiaramente la stessa arma.

3. Proiettili ed effetti temizzati
Ogni arma deve avere anche una sua identità nei colpi/effetti:
- armi da fuoco:
  - bullet sprite coerente
  - muzzle flash coerente
  - trail se necessario
  - impatto coerente
- melee:
  - slash arc / swing effect coerente con dimensione e tipo arma
  - hit effect coerente
  - eventuale scia del colpo
- elementali:
  - proiettili/onde/aree con colori, forma e VFX specifici
  - effetti leggibili: fuoco, ghiaccio, fulmine, veleno, vuoto, ecc.

Esempi:
- shotgun: pallettoni visibili o spread corto con flash ampio.
- revolver: colpo secco, bullet pesante, flash compatto.
- lanciagranate: proiettile grosso ad arco + esplosione riconoscibile.
- katana: slash pulito e veloce.
- martello: impatto pesante con shockwave corta.
- arma ghiaccio: proiettile freddo, chiaro/azzurro, impatto gelido.
- fulmine: arco elettrico o bolt con chain visiva.
- veleno: nube, goccia tossica, o residuo verde persistente.

4. Asset pipeline pulita
- Analizza come sono gestiti oggi sprite, animazioni, proiettili, pickup e rendering delle armi.
- Centralizza la definizione visiva delle armi in modo pulito.
- Ogni WeaponDefinition dovrebbe avere riferimenti a:
  - sprite pickup / world sprite
  - sprite equipaggiata / held sprite
  - projectile sprite o VFX profile
  - swing/slash effect
  - impact effect
  - eventuale animation profile
- Evita hardcode sparso in più punti.

5. Armi già create: passaggio completo
Fai un passaggio su tutte le armi nuove già introdotte.
Per ciascuna arma:
- assicurati che abbia:
  - nome chiaro
  - silhouette unica
  - palette riconoscibile
  - drop sprite coerente
  - held sprite coerente
  - projectile/effect theme coerente

6. Linee guida stilistiche
- Mantieni coerenza col gioco.
- Niente asset realistici fotobashed.
- Preferire uno stile game-ready leggibile:
  - pulito
  - contrastato
  - leggibile da camera di gioco
  - compatibile con visuale isometrica/top-down
- Le armi devono essere leggibili anche a dimensioni piccole.
- Se necessario, exaggera un po’ le proporzioni per migliorare la riconoscibilità.

7. Distinzione per categoria
Assicurati che visivamente si capisca subito se un’arma è:
- da fuoco
- melee
- elementale

Le 3 famiglie devono avere linguaggi visivi differenti:
- da fuoco: metallo, canne, tamburi, caricatori, bocche da fuoco, componenti meccaniche
- melee: lame, impugnature, aste, teste contundenti, profili d’attacco
- elementali: focus, cristalli, rune, energia, contenitori magici, forme non convenzionali

8. Feedback a terra
Quando un’arma è a terra:
- deve essere immediatamente riconoscibile
- può avere:
  - piccolo outline
  - ombra
  - lieve bobbing
  - highlight
- ma senza perdere la forma dell’arma
- opzionale: una piccola glow solo per rarità/elementali, senza confondere la silhouette

9. Priorità tecnica
Ordine di lavoro:
1. analizza stato attuale del rendering di armi/drop/proiettili
2. fai un piano sintetico
3. implementa un sistema visivo pulito per arma/drop/projectile
4. aggiorna tutte le armi già create
5. verifica in gioco che siano distinguibili davvero

10. Verifiche richieste
Controlla almeno:
- due armi diverse a terra sono distinguibili a colpo d’occhio
- due armi equipaggiate diverse si vedono chiaramente diverse in mano al player
- i proiettili di armi diverse non sembrano tutti uguali
- gli effetti melee non sembrano identici per tutte le armi
- gli effetti elementali comunicano davvero l’elemento
- nessun pickup usa placeholder generici se l’arma è già implementata
- il sistema resta estensibile per future armi

Deliverable finale:
- codice implementato
- elenco file modificati
- spiegazione sintetica del sistema visivo armi
- lista delle armi aggiornate con breve nota sulla loro identità visiva
- eventuali asset nuovi creati
- eventuali TODO residui, ma senza lasciare incompleto il passaggio principale

Importante:
La priorità non è “mettere un’immagine qualsiasi”, ma dare ad ogni arma una identità visiva forte e coerente:
- stessa arma = stesso linguaggio visivo tra drop, uso e proiettile
- armi diverse = silhouette ed effetti diversi
- niente placeholder indistinguibili
