# ARCHITECTURE

## Visione tecnica

Il progetto e un sandbox Godot 4.x 2D con resa pseudo-isometrica. La scena principale avvia un playground minimo e registra i sistemi base. Le modalita future devono usare sistemi comuni invece di duplicare gameplay.

## Flusso runtime attuale

1. `main.tscn` carica manager e world.
2. `InputManager` registra azioni tastiera/joypad.
3. `LocalMultiplayerManager` mantiene gli slot locali attivi.
4. `PlayerManager` ascolta gli slot attivi e spawna/despawna i player.
5. `PlayerController` legge input e muove il personaggio del proprio slot.
6. `WeaponSystem` gestisce arma, cooldown, caricatore, riserva e ricarica per il singolo player.
7. `ProjectileSystem` spawna proiettili che applicano danno tramite `HealthSystem`.
8. `IsometricCameraController` segue il gruppo `players`.
9. `HUDManager` mostra slot locali, progressione party, vita e munizioni per-player.

## Sistemi principali

- `InputManager`: crea e legge azioni per slot player. Ogni slot usa azioni `p{slot}_{azione}`.
- `LocalMultiplayerManager`: mantiene gli slot locali attivi, gestisce join/leave e usa mapping deterministico `device joypad + 1 = player_slot`.
- `PlayerManager`: spawna/despawna player in base agli slot attivi e tiene il registro degli slot.
- `PlayerController`: movimento, mira, fire action e colore visuale per slot.
- `GameModeManager`: selezione modalita e contratto comune futuro.
- `WeaponData`: risorsa immutabile con danno, fire rate, velocita proiettile, caricatore, riserva e durata ricarica.
- `WeaponSystem`: stato runtime per-player di arma, cooldown, munizioni e ricarica.
- `ProjectileSystem` e `Projectile`: spawn, movimento, collisione e consegna del danno.
- `HealthSystem` e `HealthComponent`: richieste globali di danno/cura e stato vita locale.
- `EnemySystem`: contratto di spawn nemici.
- `BossSystem`: contratto comune per boss richiesti dalle modalita.
- `WaveManager`: logica ondate e boss ogni N ondate.
- `DungeonGenerator`: generazione dati layout dungeon.
- `TowerDefenseManager`: base health e contratto tower defense.
- `DropSystem` e `LootTable`: drop XP, denaro, armi, munizioni e vita.
- `ProgressionManager`: XP, livello e denaro party.
- `HUDManager`: UI prototipo.

## Contratto combat

- Ogni istanza player possiede il proprio `WeaponSystem`; caricatore, riserva e cooldown non sono condivisi.
- Le statistiche di bilanciamento vivono in risorse `WeaponData`, non nel controller player.
- `ProjectileSystem` riceve i dati dello sparo e configura il proiettile prima di aggiungerlo alla scena.
- Il proiettile non conosce classi nemico specifiche: colpisce un body damageable e inoltra il danno a `HealthSystem`.
- `HealthSystem` cerca un figlio `HealthComponent` sul target; player, nemici, boss e bersagli debug possono condividere lo stesso contratto.
- Collision layer `1`: player e corpi generici.
- Collision layer `2`: bersagli damageable.
- Collision layer `4`: proiettili; la mask attuale colpisce il layer `2`.
- `CombatTarget` e una fixture statica della scena principale per verificare il combat e non sostituisce l'AI nemica della Milestone 4.

## Contratto multiplayer locale

- Player 1 e sempre attivo e non puo lasciare la sessione dal prototipo.
- Gli slot 2-4 possono entrare/uscire durante la scena.
- Un joypad con `device = 0` controlla lo slot 1, `device = 1` controlla lo slot 2, e cosi via.
- `Start` attiva lo slot del controller, `Back/Select` disattiva lo slot se non e player 1.
- `F2`, `F3` e `F4` sono fallback debug per attivare/disattivare gli slot 2, 3 e 4 senza controller fisici.
- `active_slots_changed` e il segnale autoritativo: i sistemi interessati devono ascoltare questo segnale invece di duplicare lo stato multiplayer.

## Contratti per modalita

Ogni modalita deve derivare concettualmente da `BaseGameMode` e fornire:

- `mode_id`;
- start/stop;
- condizione di vittoria/sconfitta;
- richiesta boss;
- collegamento a spawn nemici, drop e progressione.

Modalita previste:

- `survival`: ondate zombie, boss ogni N ondate.
- `dungeon`: stanze generate, boss finale per livello/area.
- `tower_defense`: path nemici, base da difendere, boss nelle ondate principali.

## Estendibilita IA

Per mantenere il progetto gestibile:

- aggiungere sistemi piccoli con responsabilita chiara;
- documentare ogni nuovo contratto pubblico;
- lasciare esempi minimi giocabili;
- mantenere milestone e TODO aggiornati;
- preferire scene/test manuali ripetibili.
