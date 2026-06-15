# Roadmap Revamp Modalità Zombie — Biomi, Spawn Dinamico e Onde Contestuali

## Obiettivo generale

Rifare la modalità zombie trasformandola da arena statica a modalità survival dinamica con:

- spawn degli zombie dai bordi della visuale attuale, non da punti fissi;
- mondo composto da biomi esplorabili;
- ondate influenzate dal bioma in cui si trova il player;
- casse risorse, ostacoli ambientali, barriere, case e impedimenti fisici;
- terreni pericolosi, inclusa la possibilità di cadere giù e perdere 20 HP;
- progressione graduale da bioma iniziale semplice a biomi più pericolosi.

Ogni partita deve partire sempre dallo stesso bioma iniziale con zombie base, per garantire leggibilità e onboarding del gameplay.

---

# Milestone 1 — Refactor della modalità zombie in sistemi separati

## Goal

Separare la logica zombie in sistemi modulari, così da poter gestire meglio spawn, ondate, biomi e difficoltà.

## Task

Creare o riorganizzare i seguenti sistemi:

- `ZombieModeController`
- `WaveDirector`
- `ZombieSpawner`
- `BiomeManager`
- `BiomeDefinition`
- `TerrainGenerator`
- `ResourceCrateSystem`
- `ObstacleSystem`
- `HazardSystem`

Il `ZombieModeController` deve coordinare:

- avvio partita;
- selezione bioma iniziale;
- inizio/fine ondata;
- transizione tra biomi;
- difficoltà progressiva;
- stato player;
- condizioni di vittoria/sconfitta.

Il `WaveDirector` non deve più generare ondate generiche, ma ondate basate sul bioma corrente.

## Acceptance Criteria

- La modalità zombie continua ad avviarsi correttamente.
- La logica di spawn non è più hardcoded in punti fissi.
- Esiste un punto unico da cui leggere il bioma corrente.
- Le ondate possono interrogare il bioma corrente per sapere quali zombie generare.

---

# Milestone 2 — Spawn dinamico dai bordi della visuale

## Goal

Gli zombie devono spawnare dai bordi della visuale attuale, non da coordinate fisse della mappa.

## Regole di spawn

Gli zombie devono apparire fuori o appena oltre il bordo della camera.

Devono poter spawnare da:

- bordo nord;
- bordo sud;
- bordo est;
- bordo ovest.

La scelta del bordo può essere casuale o pesata in base alla direzione da cui arriva la minaccia.

Lo spawn deve evitare:

- collisioni con muri, case, rocce o barriere;
- spawn dentro acqua non attraversabile;
- spawn dentro voragini;
- spawn troppo vicino al player;
- spawn in zone non raggiungibili dagli zombie.

## Implementazione suggerita

- Calcolare il rettangolo visibile della camera.
- Espandere il rettangolo di una distanza configurabile, ad esempio `spawn_margin = 80/160 px`.
- Scegliere un punto casuale lungo il perimetro esterno.
- Validare il punto con:
  - collision check;
  - pathability check;
  - distanza minima dal player;
  - compatibilità con il bioma corrente.
- Se il punto non è valido, riprovare fino a `max_spawn_attempts`.
- Se dopo molti tentativi non viene trovato un punto valido, usare un fallback sicuro su un bordo libero.

## Parametri configurabili

```txt
spawn_margin
min_distance_from_player
max_spawn_attempts
spawn_edge_weights
spawn_group_radius
max_spawn_per_tick
spawn_delay_between_groups
```

## Acceptance Criteria

- Gli zombie non appaiono più da punti fissi.
- Gli zombie entrano nella visuale dai bordi.
- Non spawnano sopra il player.
- Non spawnano dentro ostacoli o zone impossibili.
- Lo spawn rimane valido anche quando il player si sposta in altri biomi.

---

# Milestone 3 — Sistema biomi

## Goal

Creare una struttura dati per rappresentare i biomi e le loro regole di gameplay.

## Bioma iniziale

Ogni partita deve iniziare sempre nello stesso bioma base.

Nome suggerito:

```txt
Bioma: Pianura Infetta
```

Caratteristiche:

- terreno leggibile;
- pochi ostacoli;
- zombie base;
- casse risorse comuni;
- nessun hazard ambientale estremo;
- difficoltà bassa.

## Biomi iniziali da implementare

## 1. Pianura Infetta

Ruolo: bioma iniziale.

Zombie:

- Zombie Base
- Zombie Lento
- Zombie Runner raro dopo alcune ondate

Ambiente:

- erba secca;
- terra;
- recinti rotti;
- casse base;
- piccole barriere.

Risorse:

- ammo base;
- medikit piccolo;
- materiali comuni.

---

## 2. Bioma Tossico

Ruolo: bioma velenoso e di controllo area.

Zombie:

- Zombie Tossico
- Zombie Base Mutato
- Zombie Esplosivo Tossico

Ambiente:

- pozze verdi;
- fumi tossici;
- barili chimici;
- vegetazione corrotta.

Hazard:

- pozze tossiche che danneggiano nel tempo;
- gas che rallenta o avvelena;
- barili esplosivi tossici.

Risorse:

- antidoti;
- ammo corrosive;
- materiali chimici.

---

## 3. Bioma Infuocato

Ruolo: bioma aggressivo e ad alto danno.

Zombie:

- Zombie Bruciato
- Zombie Runner Infuocato
- Zombie Esplosivo

Ambiente:

- terreno bruciato;
- lava o crepe incandescenti;
- case distrutte;
- fiamme intermittenti.

Hazard:

- zone di fuoco;
- esplosioni ambientali;
- terreno caldo che danneggia se attraversato.

Risorse:

- bombe;
- ammo incendiarie;
- materiali metallici.

---

## 4. Bioma Neve

Ruolo: bioma lento e difensivo.

Zombie:

- Zombie Ghiacciato
- Zombie Corazzato di Ghiaccio
- Zombie Lento Pesante

Ambiente:

- neve;
- ghiaccio;
- rocce;
- tronchi;
- case abbandonate.

Hazard:

- ghiaccio scivoloso;
- neve alta che rallenta player e zombie;
- zone congelate che modificano il movimento.

Risorse:

- kit termici;
- munizioni perforanti;
- materiali rari congelati.

---

## 5. Bioma Acqua / Palude

Ruolo: bioma con movimento difficile e percorsi limitati.

Zombie:

- Zombie Annegato
- Zombie Paludoso
- Zombie che emerge dall’acqua

Ambiente:

- acqua bassa;
- ponti;
- fango;
- canneti;
- relitti.

Hazard:

- acqua profonda non attraversabile;
- fango che rallenta;
- zone dove gli zombie possono emergere improvvisamente.

Risorse:

- casse galleggianti;
- ammo speciali;
- materiali umidi o organici.

## Acceptance Criteria

- Esiste una definizione dati per ogni bioma.
- Ogni bioma definisce:
  - tile/terreno;
  - ostacoli;
  - casse;
  - zombie disponibili;
  - hazard;
  - palette grafica;
  - difficoltà;
  - risorse.
- Il gioco parte sempre dalla Pianura Infetta.
- Le ondate leggono il bioma corrente.

---

# Milestone 4 — Generazione terreno e layout biomi

## Goal

Generare il terreno in modo che ogni bioma abbia identità visiva e gameplay diverso.

## Requisiti

Il terreno deve includere:

- tile base del bioma;
- variazioni decorative;
- ostacoli;
- casse risorse;
- barriere;
- case o ruderi;
- zone pericolose;
- eventuali confini verso altri biomi;
- eventuali impedimenti fisici.

## Regola importante

Non tutti i biomi devono confinare direttamente con un altro bioma.

Alcuni biomi possono essere bloccati da:

- montagne;
- burroni;
- muri;
- acqua profonda;
- lava;
- edifici distrutti;
- foresta impenetrabile;
- recinti o cancelli chiusi.

## Tipi di confine

### Confine attraversabile

Esempio:

- Pianura Infetta → Bioma Tossico
- Neve → Pianura Infetta
- Palude → Pianura Infetta

Il player può passare da un bioma all’altro.

### Confine bloccato

Esempio:

- Pianura Infetta → montagna invalicabile
- Bioma Infuocato → lago di lava
- Bioma Acqua → mare profondo

Serve solo a dare forma al mondo e impedire l’uscita dalla zona.

### Confine pericoloso

Esempio:

- burrone;
- crepa nel terreno;
- ponte rotto;
- bordo isometrico senza protezione.

Se il player cade, perde 20 HP e viene riportato all’ultima posizione sicura.

## Acceptance Criteria

- Il terreno non è più solo una superficie vuota.
- Ogni bioma ha elementi ambientali riconoscibili.
- Ci sono ostacoli che influenzano movimento e combattimento.
- Alcuni bordi possono portare ad altri biomi.
- Alcuni bordi sono bloccati da impedimenti fisici.
- Esistono zone dove si può cadere perdendo 20 HP.

---

# Milestone 5 — Sistema caduta e danno ambientale

## Goal

Implementare un sistema pericoloso di caduta dal terreno.

## Regole

Alcune aree della mappa sono marcate come `fall_zone`.

Se il player entra in una `fall_zone`:

- perde 20 HP;
- viene teletrasportato all’ultima posizione sicura;
- riceve breve invulnerabilità;
- viene mostrato un feedback visivo/audio.

## Parametri

```txt
fall_damage = 20
fall_respawn_invulnerability = 1.0 / 2.0 seconds
safe_position_update_interval
minimum_safe_distance_from_hazard
```

## Posizione sicura

Il gioco deve salvare periodicamente l’ultima posizione sicura del player.

Una posizione è sicura se:

- non è dentro una collisione;
- non è dentro una zona di caduta;
- non è dentro acqua profonda;
- non è dentro lava;
- non è troppo vicina a un hazard letale;
- è raggiungibile.

## Feedback richiesto

- animazione di caduta;
- flash rosso o danno;
- breve knockback o dissolvenza;
- suono di caduta;
- popup grafico `-20 HP`.

## Acceptance Criteria

- Il player può cadere solo in zone designate.
- La caduta sottrae sempre 20 HP.
- Il player non rimane bloccato nella zona di caduta.
- La posizione sicura viene aggiornata correttamente.
- Gli zombie non devono spawnare dentro zone di caduta.

---

# Milestone 6 — Casse risorse e loot ambientale

## Goal

Inserire casse e contenitori nei biomi per rendere l’esplorazione utile.

## Tipi di casse

### Cassa Comune

Contenuto:

- piccola quantità di ammo;
- piccola cura;
- materiali comuni.

### Cassa Medica

Contenuto:

- medikit;
- benda;
- antidoto nei biomi tossici.

### Cassa Militare

Contenuto:

- munizioni;
- bombe;
- arma temporanea o upgrade.

### Cassa Bioma

Contenuto legato al bioma:

- tossico: antidoto, ammo corrosive;
- infuocato: bombe, ammo incendiarie;
- neve: kit termico, ammo perforanti;
- acqua: risorse rare, ammo speciali.

## Regole

- Le casse devono spawnare nel terreno in posizioni valide.
- Non devono bloccare completamente il passaggio.
- Possono essere:
  - rompibili;
  - apribili con interazione;
  - distrutte dagli zombie o dal player.
- Il contenuto deve essere influenzato dal bioma.
- Alcune casse possono essere rare e più protette da zombie o ostacoli.

## Acceptance Criteria

- Ogni bioma può generare casse.
- Il contenuto delle casse cambia in base al bioma.
- Le casse non spawnano in punti irraggiungibili.
- Il player riceve feedback grafico quando raccoglie risorse.

---

# Milestone 7 — Ostacoli, barriere e case

## Goal

Rendere ogni bioma più interessante tramite ostacoli fisici e oggetti ambientali.

## Tipi di ostacoli

### Ostacoli piccoli

- rocce;
- tronchi;
- barili;
- casse rotte;
- carcasse;
- cespugli.

Effetto:

- bloccano o rallentano il movimento;
- possono offrire copertura;
- alcuni possono essere distrutti.

### Barriere

- recinti;
- muri bassi;
- barricate;
- sacchi di sabbia;
- palizzate.

Effetto:

- bloccano gli zombie;
- possono essere danneggiate;
- possono creare choke point.

### Case / Ruderi

- case abbandonate;
- capanni;
- laboratori tossici;
- bunker;
- torri;
- edifici bruciati.

Effetto:

- bloccano il movimento;
- definiscono percorsi;
- possono contenere casse;
- possono creare zone di imboscata.

## Regole

- Gli ostacoli devono essere compatibili con il bioma.
- Non devono impedire completamente il pathfinding.
- Devono creare percorsi interessanti e zone tattiche.
- Alcuni ostacoli possono essere distruttibili.

## Acceptance Criteria

- Ogni bioma ha set di ostacoli specifici.
- Gli ostacoli influenzano movimento e combattimento.
- Gli zombie riescono comunque a raggiungere il player.
- Le mappe non risultano vuote.

---

# Milestone 8 — Ondate legate al bioma corrente

## Goal

Le ondate devono cambiare in base al bioma in cui si trova il player.

## Regola principale

Il `WaveDirector` deve leggere il bioma corrente e generare una composizione di zombie coerente.

## Esempio

Se il player è nel bioma tossico:

- aumentano zombie tossici;
- possono comparire zombie esplosivi tossici;
- le ondate possono includere gas o pozze tossiche;
- le casse possono contenere antidoti o risorse chimiche.

Se il player è nel bioma neve:

- più zombie lenti ma resistenti;
- meno runner;
- movimento rallentato;
- possibilità di zombie corazzati.

## Parametri ondata per bioma

Ogni bioma deve definire:

```txt
allowed_zombie_types
zombie_spawn_weights
elite_spawn_chance
boss_spawn_chance
wave_size_multiplier
spawn_rate_multiplier
resource_drop_modifier
environmental_hazard_chance
```

## Progressione

Le ondate devono scalare con:

- numero ondata;
- tempo sopravvissuto;
- numero player;
- bioma corrente;
- distanza dal bioma iniziale;
- eventuale livello del personaggio.

## Acceptance Criteria

- Le ondate non sono tutte uguali.
- Il bioma corrente modifica davvero i nemici.
- Cambiare bioma cambia il tipo di minaccia.
- Il bioma iniziale resta più semplice.
- I biomi avanzati diventano più pericolosi.

---

# Milestone 9 — Zombie specifici per bioma

## Goal

Aggiungere varianti zombie coerenti con i biomi.

## Zombie base

### Zombie Base

- lento;
- danno basso;
- vita bassa;
- usato nel bioma iniziale.

### Zombie Runner

- veloce;
- fragile;
- mette pressione al player.

### Zombie Tank

- lento;
- molta vita;
- utile come mini-minaccia.

## Zombie tossici

### Zombie Tossico

- lascia piccola pozza velenosa alla morte;
- può infliggere veleno.

### Zombie Esplosivo Tossico

- esplode alla morte;
- crea nube tossica temporanea.

## Zombie infuocati

### Zombie Bruciato

- immune o resistente al fuoco;
- può lasciare fiamme.

### Zombie Runner Infuocato

- molto veloce;
- danno alto;
- bassa vita.

### Zombie Esplosivo

- esplode vicino al player;
- danneggia anche altri zombie.

## Zombie neve

### Zombie Ghiacciato

- rallenta il player se colpisce.

### Zombie Corazzato di Ghiaccio

- più resistente;
- vulnerabile a fuoco o danni pesanti.

## Zombie acqua / palude

### Zombie Annegato

- emerge da acqua bassa o fango.

### Zombie Paludoso

- lento;
- lascia fango o rallentamento.

## Acceptance Criteria

- Ogni bioma ha almeno 2 zombie tematici.
- Gli zombie base restano disponibili nei primi biomi.
- Gli zombie speciali non appaiono subito nella prima ondata.
- Ogni zombie ha almeno una differenza gameplay chiara.

---

# Milestone 10 — Transizione tra biomi

## Goal

Permettere al player di spostarsi tra biomi durante la partita.

## Regole

Il bioma corrente viene determinato dalla posizione del player.

Quando il player entra in un nuovo bioma:

- cambia il set visivo del terreno;
- cambia la musica o ambiente sonoro;
- cambia la composizione delle ondate;
- cambia il tipo di risorse;
- cambia il tipo di ostacoli e hazard.

## Transizione morbida

Quando possibile, usare zone di transizione:

- erba → terra tossica;
- terra → cenere;
- neve → ghiaccio;
- palude → acqua.

## Transizione bloccata

Non tutti i bordi devono portare a un altro bioma.

Alcuni bordi devono essere chiusi da:

- montagna;
- mare;
- burrone;
- lava;
- mura;
- edifici;
- foresta fitta.

## Acceptance Criteria

- Il player può entrare in almeno un secondo bioma.
- Il gioco riconosce il cambio bioma.
- Le ondate cambiano dopo il cambio bioma.
- Alcuni confini sono attraversabili.
- Alcuni confini sono fisicamente bloccati.

---

# Milestone 11 — HUD e feedback visivo bioma

## Goal

Il player deve capire chiaramente in che bioma si trova e quali pericoli sono attivi.

## UI richiesta

- Indicatore nome bioma.
- Icona bioma.
- Colore o bordo HUD tematico.
- Avviso quando si entra in un nuovo bioma.
- Indicatori grafici per:
  - veleno;
  - fuoco;
  - gelo;
  - rallentamento;
  - caduta;
  - danno ambientale.

## Esempi

```txt
Entrata nel Bioma Tossico
Pericolo: veleno ambientale
Risorse utili: antidoti
Nemici principali: zombie tossici
```

```txt
Entrata nel Bioma Infuocato
Pericolo: fiamme e terreno caldo
Risorse utili: bombe e ammo incendiarie
Nemici principali: zombie bruciati
```

## Acceptance Criteria

- Il cambio bioma è visivamente chiaro.
- Il player capisce perché sta subendo danno ambientale.
- Le icone sostituiscono il più possibile le etichette testuali.
- L’HUD resta leggibile anche durante le ondate.

---

# Milestone 12 — Bilanciamento e test

## Goal

Verificare che la nuova modalità zombie sia divertente, leggibile e non frustrante.

## Test obbligatori

### Test spawn

- Gli zombie spawnano dai bordi della camera.
- Non spawnano dentro ostacoli.
- Non spawnano troppo vicini al player.
- Non spawnano in zone irraggiungibili.
- Non spawnano in fall zone.

### Test biomi

- La partita parte sempre dal bioma iniziale.
- Il player può raggiungere almeno un altro bioma.
- Il cambio bioma viene rilevato.
- Le ondate cambiano in base al bioma.

### Test terreno

- Le casse spawnano correttamente.
- Gli ostacoli non bloccano tutta la mappa.
- Le case creano percorsi interessanti.
- I confini bloccati funzionano.
- Le fall zone tolgono 20 HP.

### Test difficoltà

- Prima ondata facile e leggibile.
- Bioma iniziale adatto all’apprendimento.
- Biomi avanzati più pericolosi.
- Gli zombie speciali non appaiono troppo presto.
- Le risorse sono sufficienti ma non eccessive.

## Acceptance Criteria

- La modalità zombie è giocabile per almeno 10 minuti senza bug bloccanti.
- Il player percepisce differenza tra i biomi.
- Lo spawn dinamico funziona anche muovendosi continuamente.
- Le ondate risultano più varie.
- La mappa non sembra vuota.

---

# Priorità di implementazione

## Fase 1 — Fondamenta

1. Separare i sistemi principali.
2. Implementare BiomeManager.
3. Implementare ZombieSpawner dai bordi camera.
4. Far partire sempre la partita dal bioma iniziale.

## Fase 2 — Gameplay base

5. Implementare terreno del bioma iniziale.
6. Aggiungere casse risorse.
7. Aggiungere ostacoli e barriere.
8. Collegare WaveDirector al bioma corrente.

## Fase 3 — Biomi avanzati

9. Aggiungere bioma tossico.
10. Aggiungere bioma infuocato.
11. Aggiungere bioma neve.
12. Aggiungere bioma acqua/palude.

## Fase 4 — Pericoli ambientali

13. Aggiungere fall zone con danno da 20 HP.
14. Aggiungere danno tossico.
15. Aggiungere fuoco/lava.
16. Aggiungere rallentamento neve/fango/acqua.

## Fase 5 — Rifinitura

17. Aggiungere feedback grafico HUD.
18. Aggiungere audio/effetti bioma.
19. Bilanciare risorse e spawn.
20. Testare pathfinding, collisioni e ondate.

---

# Prompt operativo per Codex / Goal Mode

Usa questa roadmap per implementare il revamp della modalità zombie.

Prima di modificare codice:

1. Analizza lo stato attuale della modalità zombie.
2. Identifica dove sono gestiti oggi:
   - spawn zombie;
   - camera/viewport;
   - ondate;
   - collisioni;
   - terreno;
   - player HP;
   - loot;
   - nemici.
3. Proponi un piano di implementazione coerente con l’architettura esistente.
4. Procedi milestone per milestone.
5. Dopo ogni milestone:
   - aggiorna eventuali documenti di progetto;
   - aggiungi test o verifiche manuali;
   - descrivi cosa è stato cambiato;
   - segnala eventuali problemi tecnici o debiti lasciati aperti.

Non implementare tutto in modo monolitico.
Mantieni il codice modulare e leggibile.
Evita hardcoding non necessario.
Rendi configurabili i parametri di spawn, bioma, difficoltà e hazard.

---

# Definition of Done

La modalità zombie può considerarsi revampata quando:

- ogni partita parte sempre dal bioma iniziale;
- gli zombie spawnano dai bordi della visuale e non da punti fissi;
- esistono almeno 4 biomi oltre al bioma iniziale;
- ogni bioma ha terreno, ostacoli, casse e zombie tematici;
- le ondate cambiano in base al bioma corrente;
- alcune aree permettono di cadere perdendo 20 HP;
- alcuni confini portano ad altri biomi;
- alcuni confini sono bloccati da impedimenti fisici;
- il player capisce visivamente dove si trova e quali pericoli sta affrontando;
- il gameplay zombie è più vario, leggibile e rigiocabile.
