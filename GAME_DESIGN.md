# GAME_DESIGN

## Fantasy di gioco

Un action sandbox locale dove 1-4 giocatori affrontano arene, dungeon e difese a ondate con armi, drop, progressione e boss ricorrenti.

## Direzione artistica

- Arcade pseudo-isometrico, stylized e leggibile da distanza couch.
- Mood zombie survival post-apocalittico senza rumore visuale eccessivo.
- Sfondo desaturato e scuro; player, nemici, pickup e pericoli usano accenti piu saturi.
- Il colore slot identifica il player, ma ogni ruolo deve restare leggibile anche dalla silhouette.
- Le animazioni privilegiano anticipazione e risposta gameplay rispetto al realismo.
- I placeholder visuali sono componenti modulari sostituibili con asset definitivi.

## Giocatori

- 1-4 player locali implementati come prototipo minimo.
- Player 1 e sempre presente.
- Player 2-4 possono entrare/uscire durante la scena.
- La zombie survival ora passa da una selezione personaggio prima della run.
- Ogni player avra vita, arma e munizioni proprie.
- XP e denaro sono per default condivisi dal party per semplificare il multiplayer locale.
- Ogni player usa un colore diverso per restare leggibile nella camera condivisa.

Il primo pass visuale aggiunge una silhouette survivor con testa, giacca, arti e
arma visibile. Movimento, mira, sparo, ricarica, danno e morte producono
variazioni visuali senza modificare il controller.

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
- 6 colpi al secondo;
- caricatore da 12;
- riserva infinita;
- ricarica da 1 secondo;
- resta sempre disponibile come fallback;
- munizioni, caricatore e ricarica separate per ogni player.

Regole fallback:

- ogni player mantiene uno slot fallback e uno slot arma speciale;
- le armi speciali conservano caricatore e riserva quando entra in uso la fallback;
- se una speciale non puo ricaricare, lo stesso input fire attiva e spara la `Starter Pistol`;
- la pistola infinita deve comunque ricaricare il caricatore;
- un pickup ammo ripristina la riserva della speciale, la riattiva e avvia il reload;
- la fallback e affidabile ma resta meno efficace delle speciali.

Seconda arma prototipo:

- `Prototype Blaster`;
- ottenibile come drop raro;
- 16 danni per colpo;
- 4,5 colpi al secondo;
- caricatore da 8 e riserva iniziale da 24;
- sostituisce immediatamente l'arma del player che la raccoglie.

Identita visuale delle armi:

- `Starter Pistol`: corpo compatto scuro, accento arancio e proiettile piccolo;
- `Prototype Blaster`: doppia forcella blu/ciano e trail energetico medio;
- `Wave Cannon`: corpo lungo viola, nucleo magenta e proiettile pesante;
- arma in mano, icona HUD, flash di volata e proiettile condividono lo stesso profilo;
- forma e colore aiutano il riconoscimento, ma non sostituiscono i valori di bilanciamento;
- il colore slot del player resta separato dal colore energetico dell'arma.

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

Il `Basic Zombie` usa una posa curva, pelle verde desaturata, abiti scuri e
braccia protese. Camminata, attacco e reazione al colpo devono essere
riconoscibili anche ai bordi della camera.

Varianti survival implementate:

`Runner Zombie`:

- 18 HP;
- velocita 155;
- attacco da 6 danni ogni 0,62 secondi;
- silhouette stretta, postura inclinata e animazione rapida;
- 4 XP garantiti;
- entra dalla wave 2 e occupa ogni terzo slot regolare;
- ruolo: raggiungere rapidamente player isolati e spezzare il kiting passivo.

`Tank Zombie`:

- 90 HP;
- velocita 58;
- attacco da 18 danni ogni 1,25 secondi;
- silhouette larga, arti pesanti e protezione arancione;
- 8 XP garantiti;
- entra dalla wave 3 come ultimo slot quando la wave ha almeno cinque zombie;
- ruolo: assorbire fuoco, occupare spazio e proteggere indirettamente i runner.

Basic, runner e tank usano la stessa AI melee e gli stessi contratti health,
drop e wave. Le differenze sono dati di scena e presentazione visuale.

`Shooter Zombie`:

- 38 HP;
- velocita 78;
- mantiene circa 330 pixel dal target e arretra sotto 220;
- windup da 0,85 secondi con direzione e corsia bloccate;
- proiettile verde/ciano da 11 danni, distinto dai pattern boss;
- cooldown da 2,2 secondi;
- 6 XP garantiti;
- entra dalla wave 4 ogni quarto slot regolare;
- ruolo: interrompere il kiting statico lasciando spazio e tempo di reazione.

Lo shooter estende `BasicEnemy` per health, targeting, scaling, morte e drop,
ma possiede un attacco ranged dedicato. Il telegraph non applica danno.

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
- raffica mirata: cono e tre corsie visibili per 0,70 secondi prima del fuoco;
- la direzione mirata viene bloccata all'inizio del warning, quindi puo essere schivata;
- raffica radiale: dodici raggi e countdown visibili per 0,90 secondi;
- durante il telegraph non vengono creati proiettili e non viene applicato danno;
- il passaggio in fase 2 usa impulso world-space, messaggio HUD e cue audio dedicato;
- danno proiettile base: 10, portato a 13 nella quinta ondata;
- la barra HUD mostra nome, fase e vita;
- la sconfitta genera 25 XP, 20 denaro e `Wave Cannon`;
- XP, denaro e arma sono pickup fisici da raccogliere.

Identita visuale del `Wave Warden`:

- corpo meccanico/energetico segmentato, distinto dagli zombie organici;
- piastre viola e nucleo ciano nella fase 1;
- piastre magenta, spine e nucleo arancio nella fase 2;
- marker frontale orientato verso il target corrente;
- aimed e radial usano cariche e proiettili di colore diverso;
- spawn, hit, overdrive e morte hanno feedback world-space dedicato;
- l'effetto morte lascia subito leggibili i pickup speciali.

`Wave Cannon`:

- 24 danni;
- 3,5 colpi al secondo;
- caricatore da 6;
- riserva iniziale da 30;
- ricarica da 1,4 secondi.
- silhouette pesante viola/magenta con nucleo circolare;
- proiettile piu grande e trail piu marcato delle altre armi.

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
- le munizioni vengono assegnate per intero alle speciali di tutti i player vivi;
- la vita va al player che raccoglie;
- un pickup vita resta a terra se il player e gia a vita piena;
- un pickup ammo resta a terra se nessun player vivo possiede una speciale;
- un drop arma equipaggia immediatamente il player che lo raccoglie;
- non esistono ancora inventario, confronto arma o scambio tra player.

Supply crate:

- contenitore semplice apribile al contatto da un player vivo;
- genera pickup tramite una `LootTable`, senza valori hardcoded nei nemici;
- drop garantiti attuali: 10-14 ammo speciale e 16-22 HP;
- viene usata dal director survival e prima delle boss wave.
- usa una cassa medica azzurro/arancio riconoscibile senza testo.

## Progressione

Progressione implementata:

- XP party;
- denaro party;
- livello party;
- persistenza automatica tra sessioni;
- ultima modalita selezionata usata dal pulsante `Continue`;
- unlock persistente `Field Kit` al livello party 2;
- `Field Kit` aumenta la vita massima da 100 a 120 HP a ogni nuova run;
- upgrade futuri di danno, velocita, fire rate e fortuna drop.

Ogni nuova run ripristina la vita dei player attivi. Un player che entra durante una run riceve gli stessi bonus persistenti senza accumularli tra modalita.

## Downed e revive

- A zero HP un player entra in stato downed invece di morire subito.
- Il player downed non si muove, non spara e non viene scelto come target.
- Un alleato vivo entro 78 pixel puo rianimarlo tenendo interact per 2,4 secondi.
- Uscire dal raggio, lasciare il tasto, cambiare reviver o lasciare la partita azzera il progresso.
- Il revive ripristina il 35% della vita massima.
- `Field Kit` modifica la vita massima della run ma non viene riapplicato dal revive.
- Survival e dungeon terminano quando tutti gli slot sono downed o morti.
- Tower defense termina anche per party all-downed, oltre alla distruzione del core.

Il gioco parte dal menu principale. La selezione avvia survival, dungeon o tower defense; `Esc` interrompe la run corrente e torna al menu. Il menu mostra livello, XP, denaro e ultima modalita salvata.

Ogni fine run mostra un riepilogo condiviso con tempo, XP, denaro e nuovi
unlock. Survival usa `RUN OVER`, il completamento dungeon usa
`DUNGEON COMPLETE` e la sconfitta tower defense usa `DEFENSE FAILED`.
Retry riparte con lo stesso context senza accumulare bonus; cambio modalita
avanza al modo successivo e menu salva prima del ritorno.

Il feedback audio usa toni procedurali placeholder senza asset esterni obbligatori:

- focus e conferma nel menu;
- sparo per armi player, boss e torri;
- impatto solo quando viene applicato danno;
- pickup con tono differenziato per ammo, cura, denaro e arma;
- low ammo, reload e attivazione fallback con toni distinti.

Il mix usa bus separati per UI, armi, nemici, boss, ambiente e musica.
Ogni cue puo ricevere uno stream licenziato opzionale mantenendo il tono
procedurale come fallback. Gli eventi downed, revive, wave e fine run hanno
priorita maggiore degli spari ripetuti. Master, Music e SFX sono regolabili
dal menu e persistiti.

L'HUD aggiunge `LOW`, `RELOAD` e `FALLBACK` allo stato ammo e mostra per 1,75 secondi la quantita di ammo condivisa raccolta.

D-pad/stick cambiano focus e joypad `A` conferma da qualunque controller. Mix avanzato e asset audio definitivi restano futuri.

## RPG Mode

La roadmap RPG Mode introduce personaggi selezionabili prima della zombie
survival. Il primo pass include quattro profili iniziali nel catalogo
centralizzato:

- `Ranger`: arco, precisione, critici e posizionamento a distanza.
- `Pistoliere`: pistola, cadenza alta e mobilita accessibile.
- `Berserker`: ascia, danno alto e rischio da corto raggio.
- `Spadaccino`: spada, difesa e fendenti rapidi.

Il menu mostra una card per ogni profilo con nome, classe, arma base,
statistiche iniziali, passiva, super e difficolta. La scelta e passata alla
survival come `character_id` e applicata ai player attivi tramite
`RpgPlayerComponent`.

Statistiche attive:

- HP massimi dal profilo classe;
- velocita come moltiplicatore del movimento base;
- attacco aggiunto al danno arma;
- difesa sottratta al danno in ingresso;
- livello per-run con `+10 HP`, `+2 attacco` e `+1 difesa`.

Le schede HUD player mostrano livello, classe, barra XP, HP, ammo e riga
ATK/DEF/SPD.

Armi base RPG attive:

- `Arco`: 18 danni, range 750, scatter 2 gradi, 1 freccia e reload 0,55s.
- `Pistola`: 10 danni, range 520, scatter 7 gradi, 8 colpi e reload 1,2s.
- `Ascia`: 26 danni, range 95, 3 swing e reload 1,6s.
- `Spada`: 15 danni, range 125, 4 fendenti e reload 0,9s.

Le armi base hanno riserva infinita ma conservano caricatore e reload. Le
hitbox sono configurate separatamente dal visual: pistola circle, arco capsule,
ascia arc multi-hit e spada rectangle multi-hit. Le milestone successive
collegano fonti XP reali, passive, adrenalina, super e polish feedback.

## Bilanciamento iniziale

- `Starter Pistol`: 60 danni teorici al secondo, tre colpi per un `Basic Zombie`.
- La riserva infinita della `Starter Pistol` non rimuove il caricatore da 12 ne il reload da 1 secondo.
- `Prototype Blaster`: 72 danni teorici al secondo, due colpi per un `Basic Zombie`.
- `Wave Cannon`: 84 danni teorici al secondo e caricatore ridotto da arma boss.
- Low ammo speciale: 8 colpi totali o meno tra caricatore e riserva.
- Ammo director: valutazione ogni 1 secondo, cooldown crate 12 secondi, massimo 1 crate anti-frustrazione attiva.
- Supply crate: 10-14 ammo condivisa e 16-22 HP.
- `Field Kit`: +20 HP, pari a circa due colpi boss base o due attacchi zombie aggiuntivi.
- Lo scaling delle modalita resta invariato in questo primo pass e sara rivalutato con varianti nemico.

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
- la boss room usa il `Rift Architect` con scaling dungeon;
- la run termina attraversando il portale dopo la morte del boss;
- la morte di tutti i player attivi interrompe la run.

Il prototipo e lineare. Diramazioni, shop room, biomi, mappa e scelta del percorso restano futuri.

## Zombie survival

La modalita survival usa un profilo arena selezionabile e parte dopo la
selezione dal menu. I profili attuali sono:

- `Industrial Crossroads`: otto ingressi, corsie incrociate e due barili;
- `Rift Foundry`: sei ingressi radiali, anelli di lettura e tre barili;
- entrambi usano lo stesso `SurvivalMode`, `WaveManager` e roster;
- gate e decorazioni non bloccano il pathing diretto degli zombie;
- il barile e colpibile, mostra area e countdown, poi danneggia tutti gli
  attori nell'area tramite `HealthSystem`.

Regole della run:

- 3 secondi di preparazione iniziale;
- 4 secondi di intermissione tra ondate;
- ondata 1 con 3 zombie;
- 2 zombie aggiuntivi per ogni ondata successiva;
- spawn scaglionato ogni 0,45 secondi;
- +18% vita, +5% velocita e +12% danno per ondata superata;
- dalla wave 2 ogni terzo zombie regolare e un runner;
- dalla wave 3, con almeno cinque zombie regolari, l'ultimo e un tank;
- dalla wave 4 ogni quarto slot regolare e uno shooter, salvo lo slot tank;
- ogni quinta ondata e marcata come boss wave;
- ogni boss wave genera 2 zombie di scorta e il `Wave Warden`;
- la vita boss aumenta del 10% per ondata precedente;
- il danno boss aumenta dell'8% per ondata precedente;
- la wave termina solo quando scorte e boss sono morti;
- la run termina quando tutti i player attivi sono morti.

Ricompense al completamento dell'ondata `N`:

- denaro party: `2 + 2N`;
- munizioni speciali per ogni player vivo: `3 + N`;
- cura per ogni player vivo: `4 + 2N`.

I drop individuali dei nemici restano attivi durante le ondate e sono separati dalla ricompensa di completamento.

Ammo director survival:

- ignora i player che possiedono solo la fallback infinita;
- se almeno un player vivo con speciale scende a 8 colpi totali o meno, puo generare una supply crate;
- usa un cooldown di 12 secondi per evitare sovrabbondanza;
- genera una fonte supply garantita durante l'intermissione prima della boss wave;
- se la boss wave parte senza intermissione, genera la fonte all'inizio della wave.

L'HUD mostra:

- countdown alla prossima ondata;
- indice ondata e indicatore boss;
- nemici rimasti sul totale;
- ultima ricompensa;
- vita e munizioni di ogni player;
- stato low ammo, reload e fallback;
- conferma temporanea dei pickup ammo condivisi;
- XP e denaro party.

Ogni player dispone inoltre di una scheda colorata con barra vita, arma attiva
e munizioni. Le informazioni party e wave restano nel pannello superiore,
mentre i dettagli individuali sono raccolti nella fascia inferiore.

Feedback visuali implementati:

- flash di volata allo spawn del proiettile;
- scintille su impatto con danno valido;
- anello e frammenti alla morte di uno zombie;
- anello colorato alla raccolta di un pickup;
- indicatori visuali di ricarica e danno sul survivor.
- cono/raggi e countdown prima degli attacchi del `Wave Warden`;
- impulso, HUD e cue audio per il cambio fase boss.
- annunci centrali per preparazione, wave start, reward e boss;
- pannello boss incorniciato con fase, vita e warning;
- effetto morte dedicato con messaggio `WARDEN DOWN`.

## Known Visual TODOs

- Sostituire gradualmente i placeholder procedurali con sprite o skeletal
  animation mantenendo silhouette e contratti attuali.
- Rifinire menu e selezione modalita con lo stesso linguaggio delle schede HUD.
- Sostituire i toni procedurali con SFX mixati e licenziati.
- Preparare biomi dungeon senza aumentare il rumore dello sfondo.

## Accessibilita visuale

- preset `default`, `reduced_motion` e `high_contrast`;
- flash, glow, trail e shake regolabili separatamente;
- scala testo HUD configurabile tra 80% e 120%;
- reduced motion ferma bob, pulse, scale UI e shake, non i timer gameplay;
- P1-P4 usano circle, triangle, square e diamond oltre al colore;
- pickup e crate usano icone e silhouette diverse;
- high contrast rende bianchi bordi HUD, marker e countdown principali;
- le opzioni sono persistite nel save v4.

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
- base esagonale scura con nucleo energetico ciano;
- doppia canna orientata verso il target;
- idle scan quando non ha bersagli;
- rinculo e flash di volata durante il fuoco;
- proiettile ciano dedicato, distinto dalle armi player.

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
