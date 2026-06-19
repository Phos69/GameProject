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
- La zombie survival ora passa da una selezione personaggio per slot player prima della run.
- Ogni player avra vita, arma e munizioni proprie.
- XP e denaro sono per default condivisi dal party per semplificare il multiplayer locale.
- Ogni player usa un colore diverso per restare leggibile nella camera condivisa.

Il primo pass visuale aggiunge una silhouette survivor con testa, giacca, arti e
arma visibile. Movimento, mira, sparo, ricarica, danno e morte producono
variazioni visuali senza modificare il controller.

## Movimento e camera

- Movimento fluido con tastiera o joypad.
- Movimento pseudo-isometrico: input di movimento convertito su assi diagonali del playground.
- Ogni player puo eseguire un dodge/roll: `Shift`/`Ctrl` su tastiera player 1 o `B` sul joypad dello slot.
- Il roll concede una breve invulnerabilita, mette in cooldown l'azione,
  sospende il fuoco durante la schivata e puo attraversare piccoli gap/fall
  zone solo se traiettoria e landing sono valide; lava, gas, acqua profonda e
  altri hazard ambientali non vengono trattati come gap.
- Camera condivisa che segue il gruppo player e allarga leggermente lo zoom quando i player si separano.
- Il mapping prototipo dei controller e deterministico: controller 1/player 1, controller 2/player 2, controller 3/player 3, controller 4/player 4.

## Armi

Categorie disponibili:

- arma base con munizioni infinite;
- pistole;
- shotgun;
- armi automatiche;
- armi speciali da boss/drop;
- melee ed elementali.

Ogni arma definisce ID stabile, nome, categoria, descrizione, rarita, danno,
fire rate, range, ammo/reload, visuale ed effetti speciali.

Arma prototipo implementata:

- `Starter Pistol`;
- 10 danni per colpo;
- 6 colpi al secondo;
- caricatore da 12;
- riserva infinita;
- ricarica da 1 secondo;
- resta sempre disponibile come fallback;
- munizioni, caricatore e ricarica separate per ogni player.

Regole inventario e fallback:

- ogni player possiede un `PlayerWeaponInventory` di `WeaponInstance`;
- ogni istanza conserva caricatore, riserva, reload, cooldown, carica e stato temporaneo;
- l'arma base del personaggio resta sempre nel ciclo circolare;
- D-pad su/giu cambia arma in direzioni opposte, separatamente per slot locale;
- raccogliere una nuova arma la aggiunge e la seleziona senza cancellare le precedenti;
- raccogliere un ID gia posseduto converte il pickup in ammo o denaro se l'arma e infinita;
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
- viene aggiunta all'inventario e selezionata senza azzerare le altre armi.

Il catalogo drop contiene 30 armi aggiuntive: 10 da fuoco, 10 melee e 10
elementali. I comportamenti coprono cono multiproiettile, burst, pierce,
charged shot, melee arc/line/dash, AOE, explosion, stun, freeze, slow, burn,
poison, bleed, knockback, chain lightning, delayed explosion e ground hazard.
Ogni `weapon_id` puo apparire come drop una sola volta per run; esaurito il
pool, il drop diventa ammo.

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

Controlli super RPG:

- tastiera player 1: `Q`;
- joypad: pulsante `Y` dello slot associato.

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
- 7 XP RPG al killer;
- entra dalla wave 2 e occupa ogni terzo slot regolare;
- ruolo: raggiungere rapidamente player isolati e spezzare il kiting passivo.

`Tank Zombie`:

- 90 HP;
- velocita 58;
- attacco da 18 danni ogni 1,25 secondi;
- silhouette larga, arti pesanti e protezione arancione;
- 12 XP RPG al killer;
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
- 7 XP RPG al killer;
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

- denaro: 55%, 1-2;
- munizioni: 25%, 6-10;
- vita: 15%, 12-20;
- `Prototype Blaster`: 5%.
- XP RPG: 5 al player che infligge il colpo finale.

Regole raccolta:

- I pickup XP fisici, quando presenti in dungeon/boss/fixture, restano condivisi dal party;
- gli zombie survival assegnano XP RPG direttamente al killer;
- denaro dei pickup e reward resta condiviso dal party;
- le munizioni vengono assegnate per intero alle speciali di tutti i player vivi;
- la vita va al player che raccoglie;
- un pickup vita resta a terra se il player e gia a vita piena;
- un pickup ammo resta a terra se nessun player vivo possiede una speciale;
- un drop arma aggiunge e seleziona l'istanza del player che lo raccoglie;
- l'inventario non e condiviso; lo scambio diretto tra player resta fuori scope.

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

Il gioco parte dal menu principale. La selezione avvia survival, dungeon o tower defense; `Esc` interrompe la run corrente e torna al menu. Durante una partita `Start` su joypad o `P` apre il menu pausa con resume, settings, ritorno al menu e quit. Il menu mostra livello, XP, denaro, ultima modalita salvata e un pulsante Settings.

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
dal tab Audio della pagina Settings e persistiti.

L'HUD aggiunge `LOW`, `RELOAD` e `FALLBACK` allo stato ammo e mostra per 1,75
secondi la quantita di ammo condivisa raccolta. Vita e reload/cooldown utile
sono compatti sopra il survivor; le statistiche rimanenti stanno nelle schede
dei quattro angoli per gli slot attivi. Il riquadro di progresso party
`Party Lv / XP / Money`, il riquadro persistente di ondata survival e il
riquadro status bioma non vengono mostrati nel gameplay.

D-pad/stick cambiano focus in modo circolare nei menu lineari; nella Character
Select navigano la griglia in quattro direzioni con wrapping su card valide e
senza fermarsi su celle mancanti. Joypad `A` conferma da qualunque controller.
In Character Select `Start` joypad o `P` avvia la run solo se gli slot attivi
hanno selezioni valide; se lo slot controller non e ancora attivo, `Start`
resta disponibile al join multiplayer. `Esc`, joypad `B` o `Back` tornano al
menu precedente quando esiste; nel menu principale non devono rompere lo stato
corrente.
Nei Settings, `LB` e `RB` cambiano tab in modo circolare e portano il focus al
contenuto valido della tab attiva. `M` o joypad `Back/Select/View` apre la
mappa dei territori esplorati durante la survival. Il tab Video contiene
fullscreen, borderless, risoluzione, VSync, limite framerate e opzioni
visual/accessibilita. Il tab Controls permette di riassegnare movimento, mira,
fire, reload, super, interact, dodge, world map, pausa, join e leave per
joypad. Mix avanzato e asset audio definitivi restano futuri.

## RPG Mode

La roadmap RPG Mode introduce personaggi selezionabili prima della zombie
survival. Il primo pass include quattro profili iniziali nel catalogo
centralizzato:

- `Ranger` / `Mira Vento`: arco, precisione, critici e posizionamento a distanza.
- `Pistoliere` / `Dante Ferraglia`: pistola, cadenza alta e mobilita accessibile.
- `Berserker` / `Bruna Spaccaferro`: ascia, danno alto e rischio da corto raggio.
- `Spadaccino` / `Kael Guardia`: spada, difesa e fendenti rapidi.
- `Mago` / `Elio Braciastella`: bastone arcano, Dardo Arcano lento e Risonanza Arcana ogni tre hit.
- `Domatrice` / `Nina Bullone`: fionda magnetica e companion Briciola persistente.
- `Licantropo` / `Rocco Lunastorta`: artigli melee, finisher su bersagli feriti e trasformazione Notte Bestiale.

Il menu mostra una griglia di icone per i profili selezionabili e quattro slot
player con portrait, nome proprio, classe, arma base, statistiche iniziali,
passiva, super e difficolta del personaggio scelto. Le scelte sono passate alla
survival come `character_ids_by_slot`, con `character_id` come fallback legacy,
e applicate ai player attivi tramite `RpgPlayerComponent`. I profili sono
risorse `RpgCharacterData` in `game/rpg/characters/`, lette da
`RpgCharacterRegistry`. Il roster esteso include tre classi avanzate aggiunte
come risorse data-driven senza sostituire i quattro starter. Il `display_name`
resta la classe per compatibilita, mentre `hero_name` alimenta Character Select
e HUD nella forma `Mira Vento / Ranger · Arco`.

I campi artistici opzionali dei profili (`portrait_full_path`, `portrait_hud_path`, `gameplay_palette_id`, `sprite_sheet_path`, `weapon_sprite_path`, `passive_icon_path`, `super_icon_path`, `animation_profile_id` e palette primaria/secondaria/accent) rendono data-driven la sostituzione degli asset definitivi. Mira, Bruna, Nina e Rocco usano portrait PNG nel Character Select; Dante, Kael ed Elio restano su placeholder SVG/procedurali finche non arriveranno i PNG definitivi. La checklist manuale e in `docs/rpg_character_visual_checklist.md`.

Nel pass corrente la Character Select e stata rifinita come schermata RPG
completa: ogni profilo compare in una card con preview coerente, nome, classe,
arma, passiva, super, barre HP/ATK/DEF/SPD/RNG e indicatori slot. La card usa
`portrait_hud_path`/`portrait_full_path` se disponibili, poi
`gameplay_sprite_path` e infine un fallback procedurale controllato da palette
e arma.
Il pannello dossier laterale mostra descrizione di stile, range derivato da
`WeaponData` e una preview gameplay isometrica procedurale con arma/stance idle.
`style_description` e `gameplay_sprite_path` completano il profilo dati per
supportare testo di stile e future preview/sprite definitivi senza cambiare il
menu o il contratto survival.

Statistiche attive:

- HP massimi dal profilo classe;
- velocita come moltiplicatore del movimento base;
- attacco aggiunto al danno arma;
- difesa sottratta al danno in ingresso;
- livello per-run con `+10 HP`, `+2 attacco` e `+1 difesa`.

Le schede HUD player mostrano ritratto classe, livello, classe, icona arma,
ammo, riga ATK/DEF/SPD, XP, adrenalina, icona super e il buff passivo attivo.
HP e reload/cooldown leggibile sono invece nel mini HUD world-space sopra il
player.

Armi base RPG attive:

- `Arco`: 20 danni, range 750, scatter 2 gradi, 1 freccia e reload 0,55s.
- `Pistola`: 9 danni, range 520, scatter 8 gradi, 8 colpi e reload 1,2s.
- `Ascia`: 28 danni, range 95, 3 swing, wind-up pesante, hitbox ad arco e reload 1,6s.
- `Spada`: 14 danni, range 135, 4 fendenti, sweep frontale rapido e reload 0,85s.
- `Bastone arcano`: 18 danni, range 690, 5 cariche e reload 1,25s.
- `Fionda magnetica`: 11 danni, range 460, 8 rottami e reload 0,95s.
- `Artigli`: 13 danni, range 82, 5 colpi furia e recover 0,75s.

Le armi base hanno riserva infinita ma conservano caricatore e reload. Le
hitbox sono configurate separatamente dal visual: pistola circle, arco capsule,
ascia arc multi-hit e spada rectangle multi-hit. `WeaponData.attack_type`
decide il runtime: le armi ranged creano projectile, mentre ascia, spada e
artigli creano una hitbox melee temporanea ruotata nella direzione di mira, con
wind-up, finestra attiva, recovery, knockback, hitstop percepito, trail e
anti-multihit per singolo swing.
L'HUD mostra pips ammo per caricatore nelle schede angolo e una barra reload
compatta sopra il player quando serve; il profilo RPG puo accelerare o
rallentare la ricarica tramite `reload_speed`.

XP RPG:

- gli zombie survival non droppano piu pickup XP;
- il player che infligge il colpo finale riceve la XP kill;
- a fine ondata ogni player RPG vivo riceve `waveNumber * 10` XP;
- il level-up aumenta HP, attacco e difesa e cura parzialmente il player.

Passive RPG attive:

- `Ranger`: piu il bersaglio e lontano, piu il danno aumenta, fino a +30%;
- `Pistoliere`: completare un reload concede +20% fire rate per 3 secondi;
- `Berserker`: sotto il 40% HP infligge +25% danno;
- `Spadaccino`: dopo un colpo valido riceve -20% danno subito per 1,5 secondi.
- `Mago`: ogni terzo hit reale crea una mini AoE di Risonanza Arcana attorno al bersaglio.
- `Domatrice`: Briciola segue Nina e attacca automaticamente zombie vicini senza
  bloccare il player; il danno base resta assistivo (5 danni, 0,90s di
  cooldown) e il frenzy aumenta presenza senza sostituire Nina.
- `Licantropo`: Odore del Sangue aumenta il danno contro bersagli sotto il 50% HP.

Adrenalina e super:

- cap adrenalina: 100;
- hit inflitto: +1 adrenalina, modificata dal moltiplicatore classe;
- danno subito: +1 adrenalina, modificata dal moltiplicatore classe;
- kill: +5 adrenalina, modificata dal moltiplicatore classe;
- fine ondata: +10 adrenalina, modificata dal moltiplicatore classe;
- usare la super consuma tutta l'adrenalina e la riporta a 0;
- `Ranger`: `Pioggia di Frecce`, 12 frecce in cono davanti al player;
- `Pistoliere`: `Scarica Finale`, auto-fire per 4 secondi verso bersagli vicini;
- `Berserker`: `Terremoto di Sangue`, danno ad area attorno al player;
- `Spadaccino`: `Lama Fantasma`, dash offensivo con breve invulnerabilita.
- `Mago`: `Stella Cadente`, meteora AoE sul cluster di zombie piu denso vicino.
- `Domatrice`: `Branco di Rottami`, frenzy temporaneo di Briciola con attacchi piu rapidi.
- `Licantropo`: `Notte Bestiale`, trasformazione temporanea con onda d’urto iniziale, danni melee potenziati e recovery leggibile di 0,75s.

Il primo pass di bilanciamento rende il Ranger fragile ma premiato a distanza,
il Pistoliere rapido e accessibile senza superare 85 DPS teorici grezzi, il
Berserker il piu resistente e lento, e lo Spadaccino il piu difensivo tra le
classi iniziali.

Il tuning Milestone 7 blocca le metriche di feeling starter: l'ascia mantiene
wind-up/recovery lunghi, knockback e hitstop superiori come payoff rischioso; la
spada mantiene range melee piu sicuro, recovery breve e hitstop leggero; arco e
pistola restano sul percorso projectile con differenza chiara tra precisione a
distanza e cadenza ravvicinata. Le super usano VFX tipizzati a colpo d'occhio:
cono per `Pioggia di Frecce`, burst per `Scarica Finale`/`Branco di Rottami`,
radiale per `Terremoto di Sangue`/`Stella Cadente` e dash per `Lama Fantasma`/
`Notte Bestiale`.

La prima roadmap RPG e ora completa come pass prototipale: i profili sono
data-driven e level-up/super generano feedback world-space dedicati
`rpg_level_up` e `rpg_super`, oltre a cue procedurali placeholder.

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
- i passaggi tra biomi sono aperture fisiche nel terreno, senza portali o gate
  di transizione visibili;
- il barile e colpibile, mostra area e countdown, poi danneggia tutti gli
  attori nell'area tramite `HealthSystem`.

Il revamp zombie e completo come prima versione giocabile:

- a inizio run viene generata una megamappa globale seed-based con territori
  default `3x3` da `500x500`;
- lo stesso seed ricrea biomi, confini, passaggi, strade, ostacoli, casse e
  fall zone;
- ogni run parte dalla `Pianura Infetta`, il bioma iniziale semplice;
- la topologia e un grafo connesso generato con spanning tree ed edge extra, quindi tutte le regioni sono raggiungibili e possono esistere loop;
- il party attraversa passaggi fisici aperti tra territori confinanti; la
  regione corrente cambia dalla posizione world-space del gruppo, senza
  teletrasporto, portali o trigger visibili nel flusso standard;
- ogni area ha passaggi fisici solo sui lati collegati; i lati esterni senza vicino sono fall boundary leggibili;
- la regione corrente e i territori collegati adiacenti sono presenti come
  contenuto gameplay: ostacoli, hazard e crate dei vicini sono gia fisici prima
  dell'attraversamento;
- il cambio regione aggiorna palette, terreno, ostacoli, casse, hazard, HUD, mappa esplorazione e wave successive;
- gli zombie gia vivi continuano il chase attraverso i varchi aperti tra biomi,
  senza despawn, reset di vita, perdita del target o cambio forzato di roster;
- la mappa consultabile mostra solo territori unknown/discovered/visited/cleared e la posizione corrente del party;
- le ondate leggono il bioma corrente tramite `WaveDirector`;
- lo spawn reale degli zombie viene richiesto a `ZombieSpawner` sui bordi della camera;
- i vecchi punti arena restano fallback di spawn/debug e non rappresentano piu
  il cambio bioma.
- il flusso survival standard non usa piu visual legacy per comunicare la
  megamappa: niente gate di transizione, ground vicino placeholder o patch
  ovali sopra il tile layer asset-driven.

Identita dei biomi:

- `Pianura Infetta`: onboarding, zombie base, casse comuni/mediche e fall zone;
  il visuale ground usa il set foresta base con erba, erba alta, sentieri,
  strada, cliff/void e pareti rocciose, piu transizioni tra grass/path/road,
  tall grass, cliff e mountain wall;
- `Bioma Tossico`: pozze e gas, antidoti, zombie tossici ed esplosivi;
- `Bioma Infuocato`: fiamme, lava, casse militari, runner ed esplosivi;
- `Bioma Neve`: ghiaccio, neve alta, kit termici e zombie corazzati;
- `Bioma Palude`: acqua profonda, fango, loot organico e zombie emergenti;
- tutti i layout sono deterministici e partono da void: il generatore scava
  strade principali orizzontali/verticali larghe 40 celle, sentieri tematici
  medi larghi 20 celle, passaggi fisici larghi 40 celle e blocchi interni;
- ogni layout generato contiene strade, corridoi e ostacoli grandi che
  influenzano movimento e combattimento invece di restare solo decorazione;
- case, cabine, laboratori, barriere, barili, relitti, tronchi, ponti e crate
  usano sprite SVG trasparenti con silhouette isometrica dedicata, non il
  placeholder generico unico;
- i lati collegati tra biomi hanno muri o barriere tematiche con almeno un
  passaggio raggiungibile; i lati senza vicino diventano fall zone con visuale
  cliff/depth;
- tall grass, path, road e transizioni del bioma base sono solo lettura
  visuale: non rendono obbligatori asset esterni e non cambiano walkability,
  danno, spawn o pathfinding;
- tutto il `500x500` viene classificato come walkable, obstacle, hazard, border,
  void o fall zone;
- casse e spawn vengono validati contro ostacoli e hazard.

Zombie tematici:

- Tossico: `toxic_zombie`, `toxic_exploder`;
- Infuocato: `burned_zombie`, `fire_runner`, `fire_exploder`;
- Neve: `frozen_zombie`, `ice_armored_zombie`, `heavy_slow_zombie`;
- Palude: `drowned_zombie`, `marsh_zombie`, `water_emerging_zombie`;
- i profili configurano statistiche, resistenze, status al contatto, emersione e hazard alla morte;
- tutte le varianti riusano targeting, health, scaling, drop e AI di `BasicEnemy`.

Regole hazard:

- la `Pianura Infetta` contiene una fall zone visibile fuori dalle corsie centrali;
- le fall zone rappresentano vuoto/caduta, restano distinte dagli hazard
  ambientali e sono gli unici gap attraversabili dal roll entro distanza
  valida;
- il confine calpestabile/caduta usa cliff orientati sui quattro lati, angoli
  interni/esterni e raccordi diagonali; la faccia verticale, le linee di
  discesa e il gradiente della parete verso il nero devono rendere il vuoto non
  ambiguo senza affidarsi al nero o alla semplice assenza di tile;
- il void profondo non mostra texture o reticoli ripetuti: resta uniforme e
  usa lo stesso colore del fuori-mappa e viene definito visivamente dal cliff
  dettagliato solo sul confine con terreno calpestabile;
- quando void e bordo esterno si incontrano non viene disegnato alcun raccordo,
  muro o cliff aggiuntivo: l'intero tratto di contatto resta puro vuoto;
- entrando nella zona il player perde 20 HP, anche se ha un'altra invulnerabilita attiva;
- il player torna all'ultima posizione sicura registrata e la velocita viene azzerata;
- dopo il recupero riceve 1,25 secondi di invulnerabilita dedicata;
- altre sorgenti di invulnerabilita restano attive e indipendenti;
- zombie e casse non possono usare la fall zone come posizione valida;
- danno e respawn producono feedback visuale, camera shake e cue ambientale.
- tossico e fuoco applicano danno periodico;
- gas, neve alta, acqua e fango riducono temporaneamente la velocita;
- ghiaccio applica un modificatore di movimento distinto senza cambiare input;
- gli status da nemico scadono automaticamente e non alterano permanentemente le statistiche.

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
- nei biomi avanzati il roster pesato sostituisce progressivamente questi ruoli con varianti tematiche;
- numero player, tempo sopravvissuto e distanza dal bioma iniziale aumentano gradualmente la pressione;
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

- annunci temporanei per preparazione ondata, inizio ondata, reward e boss,
  senza riquadro persistente con countdown, indice ondata o nemici rimasti;
- vita/reload sopra ogni player e munizioni nelle schede angolo;
- stato low ammo, reload e fallback;
- conferma temporanea dei pickup ammo condivisi;
- dati bioma e status ambientali restano nel runtime, senza riquadro HUD
  persistente;
- annuncio centrale e cambio colore bordo quando il party entra in un nuovo bioma;
- XP e denaro party restano dati di progressione, senza riquadro dedicato nel
  gameplay corrente.

Ogni player dispone inoltre di una scheda colorata ancorata al proprio angolo:
P1 in alto a sinistra, P2 in alto a destra, P3 in basso a sinistra e P4 in
basso a destra. Le informazioni wave restano eventi temporanei, mentre i
dettagli individuali di HP/reload restano vicino al survivor.

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
- le opzioni sono persistite nel save v6 insieme a video, controlli joypad e stato mondo.

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

## Iterazione survival biome-based: status, ostacoli, encounter

Gli status temporanei ora usano cinque ID canonici: `poison`, `burn`, `bleed`, `freeze` e `shock`. Poison fa danno basso e persistente, burn colpisce piu forte ma per meno tempo, bleed mantiene pressione fisica, freeze riduce controllo e cadenza tramite il moltiplicatore ambiente, shock e un micro-stun breve. Gli status sono refreshati con durata massima e intensita conservativa, non modificano statistiche permanenti e vengono puliti allo stop run.

| Bioma | Ostacoli leggibili | Hazard/status | Nemici tematici |
| --- | --- | --- | --- |
| Pianura Infetta | case diroccate, muretti, auto, casse, corridoi larghi | pericolo basso | roster base onboarding |
| Tossico | cisterne, tubi, pozze, barili chimici | `poison` da pozze/gas | Toxic Zombie, Toxic Exploder |
| Infuocato | lava, fiamme, auto bruciate, crateri | `burn` da fuoco/lava | Burned Zombie, Fire Runner, Fire Exploder |
| Neve | ghiaccio, neve alta, rocce ghiacciate | `freeze`/slow | Frozen Zombie, Ice Armored Zombie, Heavy Slow Zombie |
| Palude | alberi morti, fango, acqua stagnante, radici | `poison`/`bleed`/slow | Drowned Zombie, Marsh Zombie, Water Emerging Zombie |

Gli encounter casuali supportano `ambush`, `elite_pack`, `cursed_crate`,
`hazard_burst`, `survivor_cache` e mini-eventi bioma dedicati:
`toxic_leak`, `fire_breakout`, `whiteout` e `marsh_emergence`. Sono selezionati
per bioma con RNG seed-based, frequenza bassa, cooldown di due wave complete e
reward proporzionata; `survivor_cache` varia il ritmo senza trappola, mentre
`cursed_crate` scambia loot migliore con status o pressione extra. I warning
world-space dei mini-eventi usano identita visuale specifica, restano leggibili
in high contrast e reduced motion, e gli status da warning colpiscono solo chi
rimane nell'area annunciata. I mini-eventi avanzati assegnano una reward crate
tematica quando il sistema casse e attivo.
