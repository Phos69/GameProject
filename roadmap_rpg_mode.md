# Roadmap RPG Mode — Classi, Armi, XP e Super

Repository di riferimento: https://github.com/Phos69/GameProject

## Obiettivo

Trasformare la modalità zombie in una modalità più RPG: prima della partita il giocatore seleziona un personaggio, ogni personaggio ha arma base, statistiche, passiva, super con adrenalina e progressione a livelli.

---

# Milestone 1 — Selezione personaggio pre-partita

Stato: completata come primo pass di flusso pre-run.

Implementato:

- catalogo centralizzato dei quattro personaggi iniziali;
- pannello `Character Select` aperto prima della zombie survival;
- passaggio di `character_id` nel context di `GameModeManager`;
- applicazione del profilo scelto ai player attivi e ai join durante la run;
- smoke test dedicato `tests/milestone_rpg_1_character_select_smoke_test.gd`.

Limite noto: in questo pass la scelta e unica per la party; selezione per-slot e bilanciamento completo arrivano nelle milestone successive.

## Goal

Prima di iniziare una run, il player deve scegliere una classe/personaggio.

## Da implementare

Creare una schermata `Character Select` prima dello start della modalità zombie.

Ogni card personaggio deve mostrare graficamente:

- nome personaggio
- classe
- arma base
- HP iniziali
- attacco
- difesa
- velocità
- icona arma
- descrizione passiva
- descrizione super
- difficoltà consigliata

## Personaggi iniziali

Implementare almeno questi 4 personaggi:

1. **Ranger**
   - Arma: arco
   - Stile: medio/lungo raggio, precisione, critici

2. **Pistoliere**
   - Arma: pistola
   - Stile: raggio medio, cadenza alta, mobilità

3. **Berserker**
   - Arma: ascia
   - Stile: corto raggio, danno alto, hitbox larga

4. **Spadaccino**
   - Arma: spada
   - Stile: melee equilibrato, difesa, fendenti rapidi

Classi future già previste:

5. **Assassino**
   - Arma: coltello

6. **Fiondatore**
   - Arma: fionda

## Criteri di completamento

La partita non parte più direttamente con un player generico.  
Il player selezionato determina arma, statistiche, passiva e super.

---

# Milestone 2 — Sistema classi e statistiche RPG

Stato: completata come primo pass runtime.

Implementato:

- statistiche classe su `RpgPlayerComponent`;
- HP massimi e velocita applicati al player durante la survival;
- progressione per-run con level-up e incremento HP/attacco/difesa;
- formula danno con attacco player e difesa bersaglio;
- formula danno ricevuto con difesa del player;
- HUD player con livello, classe, XP bar e ATK/DEF/SPD;
- smoke test dedicato `tests/milestone_rpg_2_stats_smoke_test.gd`.

Limite noto: le fonti XP reali da kill e fine ondata vengono collegate nella Milestone 6.

## Goal

Ogni personaggio deve avere statistiche proprie e progressione a livelli.

## Statistiche base

Ogni classe deve avere almeno:

```text
name
className
baseWeapon
maxHp
attack
defense
speed
reloadSpeed
adrenalineGain
critChance
critMultiplier
```

## Progressione livello

Per ora ogni livello aumenta:

```text
+ HP massimi
+ attacco
+ difesa
```

Progressione proposta percentuale:

```text
Ogni livello:
HP max +10%
Attacco +8%
Difesa +5%
```

Oppure, più leggibile per il gameplay:

```text
HP max: +10 per livello
Attacco: +2 per livello
Difesa: +1 per livello
```

## Formula danno consigliata

```text
finalDamage = max(1, weaponDamage + playerAttack - zombieDefense)
```

## Formula danno ricevuto

```text
damageTaken = max(1, zombieDamage - playerDefense)
```

## Criteri di completamento

Salendo di livello, il personaggio diventa visibilmente più resistente e più forte.  
Le statistiche devono essere mostrate graficamente nella UI, non solo come testo piccolo.

---

# Milestone 3 — Armi base differenziate

Stato: completata come primo pass `WeaponData`.

Implementato:

- quattro armi base RPG: `rpg_bow`, `rpg_pistol`, `rpg_axe`, `rpg_sword`;
- equip automatico dell'arma base dal profilo personaggio;
- campi `max_range` e `scatter_degrees` in `WeaponData`;
- range proiettile derivato da `max_range` e scatter applicato allo sparo;
- profili visuali procedurali per arma world-space, icona HUD e proiettile;
- smoke test dedicato `tests/milestone_rpg_3_weapons_smoke_test.gd`.

Limite noto: ascia e spada usano ancora proiettili corti; le collisioni melee dedicate vengono completate nella Milestone 4.

## Goal

Ogni arma deve avere gameplay diverso: range, scatter, danno, ammo, reload e hitbox proiettile.

## Armi iniziali

| Arma | Classe | Range | Scatter | Danno | Ammo per reload | Reload | Hitbox |
|---|---:|---:|---:|---:|---:|---:|---|
| Arco | Ranger | alto | basso | medio/alto | 1 freccia | rapido | stretta e lunga |
| Pistola | Pistoliere | medio | medio | medio | 8 colpi | medio | piccola e veloce |
| Ascia | Berserker | corto | nullo | alto | 3 colpi/usi | lento | larga ad arco |
| Spada | Spadaccino | corto/medio | nullo | medio | 4 fendenti | rapido | rettangolare/frontale |

## Dettaglio armi

### Arco

```text
damage: 18
range: 750
scatter: 2°
ammo: 1
reloadTime: 0.55s
fireRate: lenta
projectileSpeed: alta
hitbox: 10x28
```

Gameplay: arma precisa, forte se il player mira bene.

### Pistola

```text
damage: 10
range: 520
scatter: 7°
ammo: 8
reloadTime: 1.2s
fireRate: alta
projectileSpeed: molto alta
hitbox: 8x8
```

Gameplay: facile da usare, buona contro zombie singoli o piccoli gruppi.

### Ascia

```text
damage: 26
range: 95
scatter: 0°
ammo: 3
reloadTime: 1.6s
fireRate: lenta
projectileSpeed: melee
hitbox: 90x70 ad arco
```

Gameplay: colpi pesanti, rischiosa perché richiede vicinanza.

### Spada

```text
damage: 15
range: 125
scatter: 0°
ammo: 4
reloadTime: 0.9s
fireRate: media
projectileSpeed: melee
hitbox: 110x45 frontale
```

Gameplay: melee più sicuro dell’ascia, meno danno ma più controllo.

## Armi future

### Coltello

Rapido, corto raggio, basso danno, alta probabilità critico.

### Fionda

Raggio medio, proiettili lenti, possibile rimbalzo o stun.

## Criteri di completamento

Non devono esserci solo sprite diversi: le armi devono cambiare davvero il modo di giocare.

---

# Milestone 4 — Hitbox proiettili e colpi melee

Stato: completata come primo pass dati/collisione.

Implementato:

- `WeaponData.hitbox_type`, `hitbox_size` e `max_hit_count`;
- shape runtime circle, rectangle, capsule e arc in `Projectile`;
- collisione separata dai poligoni visuali del proiettile;
- mapping pistola/circle, arco/capsule, ascia/arc e spada/rectangle;
- colpi multi-hit per ascia e spada;
- smoke test dedicato `tests/milestone_rpg_4_hitbox_smoke_test.gd`.

Limite noto: le shape melee sono ancora gestite tramite `Projectile`; un sistema melee dedicato potra rifinirne timing e animazione in un pass futuro.

## Goal

I proiettili non devono avere tutti la stessa collisione.

## Tipi di hitbox

Implementare almeno:

```text
circle
rectangle
capsule
arc
```

## Mapping armi/hitbox

```text
Pistola: circle piccola
Arco: capsule stretta e lunga
Ascia: arc larga
Spada: rectangle frontale
Coltello: rectangle piccola
Fionda: circle media
```

## Regola importante

La collisione deve essere separata dallo sprite.

Esempio:

```text
Lo sprite della freccia può essere lungo 40px,
ma la hitbox può essere una capsule 10x28px.
```

## Criteri di completamento

Si deve percepire che:

- la freccia passa in spazi stretti
- l’ascia colpisce più zombie davanti al player
- la pistola richiede mira più precisa
- la spada ha un’area frontale affidabile

---

# Milestone 5 — Sistema ammo e reload per ogni arma

## Goal

Ogni arma deve avere una logica di ammo/reload chiara, ma il player non deve mai restare completamente impossibilitato ad attaccare.

## Regola principale

Ogni arma ha un caricatore o una sequenza di utilizzi.  
Quando finisce, parte il reload.

## Soluzione consigliata

Durante il reload:

- le armi ranged non sparano
- le armi melee non colpiscono
- però il player può sempre muoversi
- eventuale attacco base debole opzionale per evitare frustrazione

## Ammo per arma

```text
Arco: 1 freccia, reload rapido
Pistola: 8 colpi
Ascia: 3 swing pesanti
Spada: 4 fendenti
Coltello: 6 pugnalate
Fionda: 5 sassi
```

## UI ammo

Rimuovere le etichette difficili da leggere.

Mostrare ammo con icone:

```text
Pistola: 8 piccoli proiettili
Arco: 1 freccia
Ascia: 3 tacche lama
Spada: 4 tacche fendenti
Fionda: 5 pietre
Coltello: 6 coltellini
```

Durante reload:

```text
cerchio di ricarica intorno all’icona arma
oppure barra radiale
```

## Criteri di completamento

Il player capisce sempre:

- quanti colpi ha
- quando sta ricaricando
- quando può sparare/attaccare di nuovo

---

# Milestone 6 — Esperienza e level up

## Goal

L’esperienza non deve più essere droppata dagli zombie.

## Nuova regola XP

XP assegnata in due modi:

1. **Kill XP**
   - va al player che dà il colpo di grazia allo zombie

2. **Wave XP**
   - data alla fine dell’ondata
   - può essere uguale per tutti i player
   - oppure proporzionale al contributo, ma per ora meglio uguale

## Formula consigliata

```text
killXp = zombieBaseXp
waveXp = waveNumber * 10
```

Esempio:

```text
Zombie normale: 5 XP
Zombie veloce: 7 XP
Zombie tank: 12 XP
Mini boss: 40 XP
Boss: 100 XP
Fine ondata 1: 10 XP
Fine ondata 2: 20 XP
Fine ondata 3: 30 XP
```

## Level up

Quando il player sale di livello:

```text
+HP max
+attack
+defense
cura parziale opzionale: +25% HP max
effetto grafico level up
suono/flash
```

## Criteri di completamento

La XP deve essere assegnata correttamente al killer.  
A fine ondata deve arrivare XP bonus.  
Il level up deve essere visibile e soddisfacente.

---

# Milestone 7 — Passive skill per personaggio

## Goal

Ogni classe deve avere una passiva coerente con arma e identità.

## Passive iniziali

### Ranger — “Occhio del Predatore”

```text
Più il bersaglio è lontano, più aumenta il danno.
Bonus massimo: +30% damage.
```

Effetto: premia il posizionamento e la precisione.

### Pistoliere — “Mano Veloce”

```text
Ogni reload completato aumenta temporaneamente la fire rate.
Durata: 3 secondi.
Bonus: +20% fire rate.
```

Effetto: gameplay ritmico, sparo/ricarica/sparo.

### Berserker — “Furia di Sangue”

```text
Quando è sotto il 40% HP, guadagna +25% damage.
```

Effetto: personaggio rischioso ma potente.

### Spadaccino — “Guardia Perfetta”

```text
Dopo aver colpito uno zombie, ottiene riduzione danno per breve tempo.
Durata: 1.5 secondi.
Riduzione: 20%.
```

Effetto: melee più tecnico e resistente.

## Criteri di completamento

Ogni passiva deve essere:

- sempre attiva o attivata automaticamente
- visibile nella UI quando entra in funzione
- bilanciata senza richiedere input aggiuntivi

---

# Milestone 8 — Adrenalina e Super

## Goal

Ogni personaggio deve avere una super diversa, utilizzabile quando la barra adrenalina è piena.

## Come si carica l’adrenalina

Adrenalina guadagnata da:

```text
danno inflitto
kill
danno subito
fine ondata
```

Formula semplice:

```text
+1 adrenalina ogni hit
+5 adrenalina per kill
+10 adrenalina a fine ondata
```

La super si attiva a:

```text
100 adrenalina
```

Dopo l’uso:

```text
adrenalina torna a 0
```

## Super iniziali

### Ranger — “Pioggia di Frecce”

```text
Scaglia una raffica di frecce nell’area davanti al player.
Ottima contro gruppi.
```

Effetto:

```text
12 frecce
danno 70% del danno arma ciascuna
area conica
range alto
```

### Pistoliere — “Scarica Finale”

```text
Per pochi secondi spara automaticamente verso i nemici più vicini.
```

Effetto:

```text
durata 4s
fire rate altissima
nessun consumo ammo
scatter ridotto
```

### Berserker — “Terremoto di Sangue”

```text
Colpo ad area intorno al player.
```

Effetto:

```text
danno alto
knockback
stun breve
range circolare medio
```

### Spadaccino — “Lama Fantasma”

```text
Dash in avanti che taglia tutti gli zombie attraversati.
```

Effetto:

```text
dash invulnerabile
danno medio/alto
colpisce più nemici
ottimo escape
```

## UI adrenalina

Mostrare una barra grande o icona speciale vicino al player HUD.

Stati:

```text
vuota
in caricamento
piena lampeggiante
super pronta
cooldown dopo uso
```

## Criteri di completamento

La super deve cambiare il momento della partita.  
Non deve sembrare solo un colpo più forte.

---

# Milestone 9 — HUD grafica RPG

## Goal

Salute, ammo, bombe/adrenalina e livello devono essere grafici e leggibili.

## HUD richiesto

Mostrare:

```text
cuori o barra HP
icone ammo
barra XP
livello personaggio
icona arma
barra adrenalina
icona super
buff passivi attivi
```

## Esempio layout

```text
Angolo basso sinistro:
- ritratto personaggio
- nome classe
- livello
- barra HP

Centro basso:
- icona arma
- ammo grafiche
- reload radiale

Angolo basso destro:
- barra adrenalina
- icona super
- eventuali bombe/consumabili
```

## Criteri di completamento

Il giocatore deve poter capire tutto senza leggere etichette piccole.

---

# Milestone 10 — Bilanciamento prima versione

## Goal

Rendere le 4 classi giocabili e diverse senza cercare ancora la perfezione.

## Target gameplay

### Ranger

Forte se mantiene distanza.  
Debole se circondato.

### Pistoliere

Classe più accessibile.  
Buona per testare il gioco.

### Berserker

Alto rischio, alto danno.  
Deve sentire il peso dei colpi.

### Spadaccino

Melee bilanciato.  
Buono per difesa e controllo.

## Problemi da evitare

```text
Pistola troppo forte perché spara sempre
Ascia frustrante se troppo lenta
Arco inutile se gli zombie sono troppo veloci
Spada troppo simile all’ascia
Super troppo frequenti
XP troppo lenta
```

## Criteri di completamento

Ogni classe deve avere almeno un motivo chiaro per essere scelta.

---

# Milestone 11 — Data-driven configuration

## Goal

Evitare classi hardcoded sparse nel codice.

## Struttura consigliata

Creare configurazioni tipo:

```text
characters.json
weapons.json
skills.json
supers.json
```

Oppure oggetti equivalenti nel codice, purché centralizzati.

## Esempio character config

```json
{
  "id": "ranger",
  "name": "Ranger",
  "weapon": "bow",
  "maxHp": 90,
  "attack": 8,
  "defense": 2,
  "speed": 1.05,
  "passive": "predator_eye",
  "super": "arrow_rain"
}
```

## Esempio weapon config

```json
{
  "id": "bow",
  "name": "Arco",
  "damage": 18,
  "range": 750,
  "scatter": 2,
  "ammo": 1,
  "reloadTime": 0.55,
  "projectileSpeed": 900,
  "hitbox": {
    "type": "capsule",
    "width": 10,
    "height": 28
  }
}
```

## Criteri di completamento

Aggiungere una nuova classe deve richiedere modifiche minime.

---

# Milestone 12 — Polish grafico e feedback

## Goal

Fare percepire il gioco come un vero action RPG arcade.

## Feedback necessari

Per ogni arma:

```text
sprite/animazione diversa
suono diverso
effetto colpo diverso
hit effect diverso
animazione reload diversa
```

Per ogni classe:

```text
idle animation
walk animation
attack animation
hurt animation
super animation
level up animation
death animation
```

Per gli zombie:

```text
flash quando colpiti
knockback
numero danno opzionale
animazione morte
```

## Criteri di completamento

Ogni azione importante deve avere feedback visivo:

- sparo
- colpo melee
- zombie colpito
- kill
- reload
- super pronta
- super usata
- level up
- fine ondata

---

# Priorità implementativa consigliata

## Prima iterazione obbligatoria

1. Character select
2. Config classi
3. Config armi
4. Weapon stats diverse
5. Ammo/reload per arma
6. XP al killer
7. XP fine ondata
8. Level up base
9. HUD grafico minimo

## Seconda iterazione

1. Passive skill
2. Adrenalina
3. Super
4. Hitbox avanzate
5. Effetti visivi
6. Bilanciamento

## Terza iterazione

1. Coltello
2. Fionda
3. Nuove classi
4. Skill tree
5. Upgrade tra ondate
6. Boss con debolezze diverse per arma/classe

---

# Definizione di “fatto”

La roadmap è completata quando:

```text
Il player sceglie una classe prima della partita.
Ogni classe ha arma, stats, passiva e super.
Ogni arma ha range, scatter, danno, ammo, reload e hitbox diverse.
La XP viene assegnata al player che dà il colpo di grazia.
A fine ondata viene assegnata XP bonus.
Ogni level up aumenta HP, attacco e difesa.
HP, ammo, XP e adrenalina sono mostrati graficamente.
Le 4 classi iniziali sono giocabili e chiaramente diverse.
```

---

# Prompt operativo per Codex Goal Mode

Usa questa roadmap come specifica di prodotto. Procedi milestone per milestone, senza saltare la validazione della milestone precedente.

Per ogni milestone:

1. Analizza lo stato attuale della repository.
2. Identifica i file da modificare.
3. Implementa la feature nel modo meno invasivo possibile.
4. Mantieni il codice data-driven dove possibile.
5. Aggiorna README o documentazione tecnica se necessario.
6. Esegui test manuali o automatici disponibili.
7. Scrivi un riepilogo finale con:
   - file modificati
   - comportamento aggiunto
   - eventuali limiti rimasti
   - prossimi step consigliati

Priorità assoluta: rendere la modalità zombie più leggibile, giocabile e riconoscibile come gioco RPG/action arcade.
