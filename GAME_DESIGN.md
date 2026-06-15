# GAME_DESIGN

## Fantasy di gioco

Un action sandbox locale dove 1-4 giocatori affrontano arene, dungeon e difese a ondate con armi, drop, progressione e boss ricorrenti.

## Giocatori

- 1-4 player locali implementati come prototipo minimo.
- Player 1 e sempre presente.
- Player 2-4 possono entrare/uscire durante la scena.
- Ogni player avra vita, arma e munizioni proprie.
- XP e denaro sono per default condivisi dal party per semplificare il multiplayer locale.
- Ogni player usa un colore diverso per restare leggibile nella camera condivisa.

## Movimento e camera

- Movimento fluido con tastiera o joypad.
- Movimento pseudo-isometrico: input di movimento convertito su assi diagonali del playground.
- Camera condivisa che segue il gruppo player e allarga leggermente lo zoom quando i player si separano.
- Il mapping prototipo dei controller e deterministico: controller 1/player 1, controller 2/player 2, controller 3/player 3, controller 4/player 4.

## Armi

Tipi futuri:

- arma base con munizioni infinite;
- pistole;
- shotgun;
- armi automatiche;
- armi speciali da boss/drop.

Ogni arma dovra definire danno, fire rate, spread, velocita proiettile, tipo munizione e rarita.

Arma prototipo implementata:

- `Starter Pistol`;
- 10 danni per colpo;
- 7 colpi al secondo;
- caricatore da 12;
- riserva iniziale da 36;
- ricarica da 1 secondo;
- munizioni e ricarica separate per ogni player.

Seconda arma prototipo:

- `Prototype Blaster`;
- ottenibile come drop raro;
- 16 danni per colpo;
- 4 colpi al secondo;
- caricatore da 8 e riserva iniziale da 24;
- sostituisce immediatamente l'arma del player che la raccoglie.

Controlli ricarica:

- tastiera player 1: `R`;
- joypad: pulsante `X` dello slot associato.

La scena principale include bersagli statici da 40 HP per verificare danno, barra vita e morte. Questi bersagli sono strumenti di prototipo, non nemici della modalita.

## Nemici

Nemico implementato:

- `Basic Zombie`;
- 30 HP;
- velocita 95;
- detection range 900;
- attacco melee da 8 danni;
- cooldown attacco 0,85 secondi;
- seleziona il player vivo piu vicino;
- rivaluta il target durante join, leave e morte dei player;
- stati idle, chase, attack e dead.

Nemici futuri:

- shooter semplice;
- tank lento;
- runner veloce.

## Boss

Ogni modalita deve poter richiedere un boss:

- survival: boss ogni N ondate;
- dungeon: boss alla fine del livello o area;
- tower defense: boss nelle ondate principali.

Boss implementato: `Wave Warden`.

- vita base: 360;
- quinta ondata: 504 HP per lo scaling survival;
- mantiene una distanza media dai player e si muove lateralmente;
- seleziona il player vivo piu vicino;
- fase 1: raffica mirata di 3 proiettili;
- fase 2 sotto il 50%: alterna raffica radiale da 12 e raffica mirata;
- danno proiettile base: 10, portato a 13 nella quinta ondata;
- la barra HUD mostra nome, fase e vita;
- la sconfitta genera 25 XP, 20 denaro e `Wave Cannon`;
- XP, denaro e arma sono pickup fisici da raccogliere.

`Wave Cannon`:

- 24 danni;
- 3,5 colpi al secondo;
- caricatore da 6;
- riserva iniziale da 30;
- ricarica da 1,4 secondi.

I boss futuri devono mantenere il contratto di vita, segnali, drop e integrazione modalita.

## Drop

I mostri possono droppare:

- esperienza;
- denaro;
- armi;
- munizioni;
- vita.

Le loot table devono essere dati configurabili, non logica hardcoded nel nemico.

Loot table prototipo del `Basic Zombie`:

- esperienza: 100%, 3 XP;
- denaro: 55%, 1-2;
- munizioni: 25%, 6-10;
- vita: 15%, 12-20;
- `Prototype Blaster`: 5%.

Regole raccolta:

- XP e denaro sono condivisi dal party;
- munizioni e vita vanno al player che raccoglie;
- un pickup vita resta a terra se il player e gia a vita piena;
- un drop arma equipaggia immediatamente il player che lo raccoglie;
- non esistono ancora inventario, confronto arma o scambio tra player.

## Progressione

Progressione implementata:

- XP party;
- denaro party;
- livello party;
- persistenza automatica tra sessioni;
- ultima modalita selezionata usata dal pulsante `Continue`;
- upgrade futuri di vita, danno, velocita, fire rate e fortuna drop.

Il gioco parte dal menu principale. La selezione avvia survival, dungeon o tower defense; `Esc` interrompe la run corrente e torna al menu. Il menu mostra livello, XP, denaro e ultima modalita salvata.

Il feedback audio del menu usa toni procedurali placeholder per focus e conferma, senza asset esterni obbligatori. D-pad/stick cambiano focus e joypad `A` conferma da qualunque controller. Audio di combattimento e pickup restano futuri.

## Dungeon

La modalita dungeon implementata genera un percorso deterministico da seed:

- start room;
- una o piu combat room;
- una loot room;
- boss room.

Regole del prototipo:

- la run standard contiene 7 stanze;
- ogni stanza usa un'arena confinata riusabile;
- il portale verde a destra avanza alla stanza collegata;
- start e loot room hanno il portale subito disponibile;
- combat e boss room mostrano il portale rosso e bloccato;
- il portale si sblocca quando tutti i nemici tracciati sono morti;
- le combat room aumentano progressivamente conteggio, vita, velocita e danno dei nemici;
- la loot room genera sempre XP, denaro, munizioni e vita;
- la boss room usa il `Wave Warden` con scaling dungeon;
- la run termina attraversando il portale dopo la morte del boss;
- la morte di tutti i player attivi interrompe la run.

Il prototipo e lineare. Diramazioni, shop room, biomi, mappa e scelta del percorso restano futuri.

## Zombie survival

La modalita survival usa l'arena principale e parte dopo la selezione dal menu:

- 3 secondi di preparazione iniziale;
- 4 secondi di intermissione tra ondate;
- ondata 1 con 3 zombie;
- 2 zombie aggiuntivi per ogni ondata successiva;
- spawn scaglionato ogni 0,45 secondi;
- +18% vita, +5% velocita e +12% danno per ondata superata;
- ogni quinta ondata e marcata come boss wave;
- ogni boss wave genera 2 zombie di scorta e il `Wave Warden`;
- la vita boss aumenta del 10% per ondata precedente;
- il danno boss aumenta dell'8% per ondata precedente;
- la wave termina solo quando scorte e boss sono morti;
- la run termina quando tutti i player attivi sono morti.

Ricompense al completamento dell'ondata `N`:

- denaro party: `2 + 2N`;
- munizioni per ogni player vivo: `3 + N`;
- cura per ogni player vivo: `4 + 2N`.

I drop individuali dei nemici restano attivi durante le ondate e sono separati dalla ricompensa di completamento.

L'HUD mostra:

- countdown alla prossima ondata;
- indice ondata e indicatore boss;
- nemici rimasti sul totale;
- ultima ricompensa;
- vita e munizioni di ogni player;
- XP e denaro party.

## Tower defense

La modalita tower defense implementata usa un'arena dedicata:

- core da 250 HP;
- percorso fisso a sei waypoint;
- tre slot torre;
- 75 crediti iniziali;
- costo di una torre: 25 crediti;
- costruzione entrando nello slot e premendo `E` o joypad `A`;
- sconfitta quando il core raggiunge 0 HP.

Nemico `Tower Defense Raider`:

- 38 HP base;
- velocita 105;
- 12 danni al core se completa il percorso;
- 4 crediti se eliminato;
- vita +16%, velocita +4% e danno core +12% per ondata superata.

Torre prototipo:

- range 260;
- 2,5 colpi al secondo;
- 16 danni per colpo;
- targeting automatico del bersaglio valido piu vicino;
- usa i proiettili e il sistema danni condivisi.

Regole ondate:

- 3 secondi di preparazione iniziale;
- 4 secondi di intermissione;
- ondata 1 con 4 nemici;
- 2 nemici aggiuntivi per ondata;
- spawn ogni 0,55 secondi;
- ricompensa completamento: `12 + 4N` crediti;
- ogni quinta ondata genera 3 scorte e il `Wave Warden`;
- boss eliminato: 20 crediti;
- boss arrivato al core: 55 danni.

I player possono continuare a muoversi e sparare direttamente ai nemici. Crediti, torri e core appartengono alla run tower defense; denaro e XP party restano separati. Percorsi multipli, tipi torre, upgrade, vendita e riparazione non sono ancora implementati.
