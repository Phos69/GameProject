extends RefCounted
class_name GameConstants

const MAX_LOCAL_PLAYERS: int = 4
const DEFAULT_BOSS_WAVE_INTERVAL: int = 5

## Bitmask dei collision layer (valori, non indici), come da ARCHITECTURE.md.
## Layer 1: player e corpi generici, inclusi gli ostacoli che bloccano il
## movimento. Layer 2: bersagli damageable. Layer 4: proiettili player.
## Layer 8: pickup. Layer 16: proiettili ostili. Layer 32: ostacoli che
## bloccano i proiettili (un ostacolo solido sta su LAYER_BODIES | LAYER_SOLID_OBSTACLES).
const LAYER_BODIES: int = 1
const LAYER_DAMAGEABLE: int = 2
const LAYER_PLAYER_PROJECTILES: int = 4
const LAYER_PICKUPS: int = 8
const LAYER_HOSTILE_PROJECTILES: int = 16
const LAYER_SOLID_OBSTACLES: int = 32

const DROP_EXPERIENCE: StringName = &"experience"
const DROP_MONEY: StringName = &"money"
const DROP_WEAPON: StringName = &"weapon"
const DROP_AMMO: StringName = &"ammo"
const DROP_HEALTH: StringName = &"health"

const MODE_MENU: StringName = &"menu"
const MODE_INFINITE_ARENA: StringName = &"infinite_arena"
const MODE_SURVIVAL: StringName = &"survival"
const MODE_DUNGEON: StringName = &"dungeon"
const MODE_TOWER_DEFENSE: StringName = &"tower_defense"
