# GAME_DESIGN

## Fantasy di gioco

Un action sandbox locale dove 1-4 giocatori affrontano arene, dungeon e difese a ondate con armi, drop, progressione e boss ricorrenti.

## Giocatori

- 1 player implementato nel prototipo.
- 2-4 player locali previsti.
- Ogni player avra vita, arma e munizioni proprie.
- XP e denaro sono per default condivisi dal party per semplificare il multiplayer locale.

## Movimento e camera

- Movimento fluido con tastiera o joypad.
- Movimento pseudo-isometrico: input di movimento convertito su assi diagonali del playground.
- Camera condivisa che segue il gruppo player.

## Armi

Tipi futuri:

- arma base con munizioni infinite;
- pistole;
- shotgun;
- armi automatiche;
- armi speciali da boss/drop.

Ogni arma dovra definire danno, fire rate, spread, velocita proiettile, tipo munizione e rarita.

## Nemici

Nemici base futuri:

- zombie melee;
- shooter semplice;
- tank lento;
- runner veloce.

AI iniziale prevista: idle, chase, attack, dead.

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

