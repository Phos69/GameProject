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

Un boss deve avere vita elevata, pattern riconoscibile, drop speciale e segnale di sconfitta.

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

Progressione prevista:

- XP party;
- denaro party;
- livello party;
- upgrade futuri di vita, danno, velocita, fire rate e fortuna drop.

## Dungeon

La modalita dungeon generera una sequenza/grafo di stanze:

- start room;
- combat room;
- loot room;
- shop room futura;
- boss room.

## Zombie survival

La modalita survival usa un'arena e ondate crescenti:

- ondate normali;
- pausa breve tra ondate;
- boss ogni N ondate;
- drop e ricompense tra ondate.

## Tower defense

La modalita tower defense prevede:

- una base con vita;
- path nemici;
- punti torre;
- ondate;
- boss nelle ondate principali.
