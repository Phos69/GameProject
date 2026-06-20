extends Node
class_name SurvivalMarketController

signal market_opened(wave_index: int, offers: Array[Dictionary])
signal market_closed(wave_index: int)
signal offers_changed(offers: Array[Dictionary])
signal wallet_changed(balance: int)
signal purchase_succeeded(player_slot: int, item_id: StringName, cost: int)
signal purchase_denied(player_slot: int, item_id: StringName, reason: String)
signal player_ready_changed(player_slot: int, is_ready: bool)

const ITEM_HEAL_SMALL: StringName = &"heal_small"
const ITEM_HEAL_MEDIUM: StringName = &"heal_medium"
const ITEM_AMMO_ACTIVE: StringName = &"ammo_active"
const ITEM_AMMO_ALL: StringName = &"ammo_all"
const MARKET_INVULNERABILITY: StringName = &"survival_market"
const PURCHASE_SERVICE_SCRIPT := preload(
	"res://game/modes/survival/market/survival_market_purchase_service.gd"
)

@export_range(1, 8) var weapon_offer_count: int = 4
@export var heal_small_amount: int = 25
@export var heal_small_cost: int = 8
@export var heal_medium_amount: int = 55
@export var heal_medium_cost: int = 14
@export var ammo_active_cost: int = 10
@export var ammo_all_cost: int = 22
@export var weapon_cost_by_rarity: Dictionary = {
	&"common": 18,
	&"uncommon": 28,
	&"rare": 42,
	&"epic": 60
}
@export var rarity_weight: Dictionary = {
	&"common": 1.0,
	&"uncommon": 0.65,
	&"rare": 0.35,
	&"epic": 0.18
}

var is_run_active: bool = false
var is_market_open: bool = false
var market_wave_index: int = 0
var processed_boss_waves: Dictionary = {}
var weapon_offers: Array[Dictionary] = []
var previous_offer_ids: Array[StringName] = []
var ready_by_slot: Dictionary = {}
var rng := RandomNumberGenerator.new()

var wave_manager: WaveManager
var progression_manager: ProgressionManager
var player_manager: PlayerManager
var purchase_service: RefCounted

func _ready() -> void:
	add_to_group("survival_market_controller")
	rng.randomize()
	_resolve_dependencies()
	_connect_dependencies()
	_resolve_purchase_service()

func start_run() -> void:
	_resolve_dependencies()
	_connect_dependencies()
	_resolve_purchase_service()
	is_run_active = true
	is_market_open = false
	market_wave_index = 0
	processed_boss_waves.clear()
	weapon_offers.clear()
	previous_offer_ids.clear()
	ready_by_slot.clear()
	_set_players_market_state(false)
	if wave_manager != null and wave_manager.is_next_wave_blocked():
		wave_manager.set_next_wave_blocked(false)

func stop_run() -> void:
	is_run_active = false
	is_market_open = false
	market_wave_index = 0
	weapon_offers.clear()
	ready_by_slot.clear()
	_set_players_market_state(false)
	if wave_manager != null and wave_manager.is_next_wave_blocked():
		wave_manager.set_next_wave_blocked(false)

func should_open_after_wave(wave_index: int) -> bool:
	return (
		is_run_active
		and wave_manager != null
		and wave_manager.should_spawn_boss(wave_index)
		and not processed_boss_waves.has(wave_index)
	)

func get_wallet_balance() -> int:
	return progression_manager.money if progression_manager != null else 0

func get_weapon_offers() -> Array[Dictionary]:
	return weapon_offers.duplicate(true)

func get_purchase_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{
			"item_id": ITEM_HEAL_SMALL,
			"purchase_kind": &"health",
			"amount": heal_small_amount,
			"display_name": "Cura rapida",
			"category": &"health",
			"rarity": &"service",
			"cost": heal_small_cost,
			"stats_text": "+%d HP (senza superare il massimo)" % heal_small_amount
		},
		{
			"item_id": ITEM_HEAL_MEDIUM,
			"purchase_kind": &"health",
			"amount": heal_medium_amount,
			"display_name": "Cura completa",
			"category": &"health",
			"rarity": &"service",
			"cost": heal_medium_cost,
			"stats_text": "+%d HP (senza superare il massimo)" % heal_medium_amount
		},
		{
			"item_id": ITEM_AMMO_ACTIVE,
			"purchase_kind": &"ammo_active",
			"display_name": "Ammo arma equipaggiata",
			"category": &"ammo",
			"rarity": &"service",
			"cost": ammo_active_cost,
			"stats_text": "Ripristina caricatore e riserva dell'arma attiva"
		},
		{
			"item_id": ITEM_AMMO_ALL,
			"purchase_kind": &"ammo_all",
			"display_name": "Ammo tutte le armi",
			"category": &"ammo",
			"rarity": &"service",
			"cost": ammo_all_cost,
			"stats_text": "Ripristina caricatore e riserva di tutte le armi"
		}
	]
	for offer in weapon_offers:
		options.append(offer.duplicate(true))
	return options

func try_purchase(player_slot: int, item_id: StringName) -> bool:
	if not is_market_open:
		return _deny(player_slot, item_id, "Mercato non disponibile")
	var player := _find_alive_player(player_slot)
	if player == null:
		return _deny(player_slot, item_id, "Player non attivo")
	if bool(ready_by_slot.get(player_slot, false)):
		return _deny(player_slot, item_id, "Togli READY prima di acquistare")

	var option := _find_purchase_option(item_id)
	if option.is_empty() or purchase_service == null:
		return _deny(player_slot, item_id, "Offerta non valida")
	var result: Dictionary = purchase_service.try_purchase(player, option)
	if not bool(result.get("success", false)):
		return _deny(
			player_slot,
			item_id,
			str(result.get("reason", "Acquisto negato"))
		)
	return _succeed(player_slot, item_id, int(result.get("cost", 0)))

func set_player_ready(player_slot: int, ready: bool) -> bool:
	if not is_market_open or _find_alive_player(player_slot) == null:
		return false
	ready_by_slot[player_slot] = ready
	player_ready_changed.emit(player_slot, ready)
	if ready and _all_alive_players_ready():
		_close_market()
	return true

func toggle_player_ready(player_slot: int) -> bool:
	return set_player_ready(
		player_slot,
		not bool(ready_by_slot.get(player_slot, false))
	)

func is_player_ready(player_slot: int) -> bool:
	return bool(ready_by_slot.get(player_slot, false))

func set_random_seed(seed: int) -> void:
	rng.seed = seed

func _on_wave_completed(wave_index: int) -> void:
	if not should_open_after_wave(wave_index):
		return
	if not PlayerQuery.any_alive(get_tree()):
		return
	processed_boss_waves[wave_index] = true
	wave_manager.set_next_wave_blocked(true)
	_open_market(wave_index)

func _open_market(wave_index: int) -> void:
	is_market_open = true
	market_wave_index = wave_index
	ready_by_slot.clear()
	for player in PlayerQuery.alive(get_tree()):
		ready_by_slot[int(player.get("player_slot"))] = false
	_generate_weapon_offers()
	_set_players_market_state(true)
	market_opened.emit(market_wave_index, get_weapon_offers())
	offers_changed.emit(get_weapon_offers())
	wallet_changed.emit(get_wallet_balance())

func _close_market() -> void:
	if not is_market_open:
		return
	var closed_wave := market_wave_index
	is_market_open = false
	ready_by_slot.clear()
	_set_players_market_state(false)
	market_closed.emit(closed_wave)
	if wave_manager != null:
		wave_manager.set_next_wave_blocked(false)

func _generate_weapon_offers() -> void:
	var pool := WeaponCatalog.get_all()
	weapon_offers.clear()
	var selected_ids: Array[StringName] = []
	while not pool.is_empty() and weapon_offers.size() < weapon_offer_count:
		var definition := _take_weighted_weapon(pool)
		if definition == null:
			break
		selected_ids.append(definition.weapon_id)
		weapon_offers.append(_make_weapon_offer(definition))
	if _has_same_offer_set(selected_ids, previous_offer_ids) and not pool.is_empty():
		var replacement := _take_weighted_weapon(pool)
		if replacement != null:
			weapon_offers[weapon_offers.size() - 1] = _make_weapon_offer(replacement)
			selected_ids[selected_ids.size() - 1] = replacement.weapon_id
	previous_offer_ids = selected_ids

func _take_weighted_weapon(pool: Array[WeaponData]) -> WeaponData:
	var total_weight := 0.0
	for definition in pool:
		total_weight += _get_rarity_weight(definition.rarity)
	if total_weight <= 0.0:
		return pool.pop_back()
	var roll := rng.randf_range(0.0, total_weight)
	for index in range(pool.size()):
		roll -= _get_rarity_weight(pool[index].rarity)
		if roll <= 0.0:
			return pool.pop_at(index)
	return pool.pop_back()

func _make_weapon_offer(definition: WeaponData) -> Dictionary:
	var range_value := (
		definition.get_resolved_melee_range()
		if definition.uses_melee_attack()
		else definition.max_range
	)
	return {
		"item_id": definition.weapon_id,
		"purchase_kind": &"weapon",
		"weapon_id": definition.weapon_id,
		"weapon_data": definition,
		"display_name": definition.display_name,
		"category": definition.category,
		"rarity": definition.rarity,
		"cost": _get_weapon_cost(definition.rarity),
		"stats_text": "DMG %d  Rate %.1f/s  Range %d  Mag %d" % [
			definition.damage,
			definition.fire_rate,
			roundi(range_value),
			definition.magazine_size
		]
	}

func _find_purchase_option(item_id: StringName) -> Dictionary:
	for option in get_purchase_options():
		if StringName(option.get("item_id", &"")) == item_id:
			return option
	return {}

func _succeed(player_slot: int, item_id: StringName, cost: int) -> bool:
	purchase_succeeded.emit(player_slot, item_id, cost)
	wallet_changed.emit(get_wallet_balance())
	return true

func _deny(player_slot: int, item_id: StringName, reason: String) -> bool:
	purchase_denied.emit(player_slot, item_id, reason)
	return false

func _all_alive_players_ready() -> bool:
	var alive_players := PlayerQuery.alive(get_tree())
	if alive_players.is_empty():
		return false
	for player in alive_players:
		if not bool(ready_by_slot.get(int(player.get("player_slot")), false)):
			return false
	return true

func _find_alive_player(player_slot: int) -> Node:
	for player in PlayerQuery.alive(get_tree()):
		if int(player.get("player_slot")) == player_slot:
			return player
	return null

func _set_players_market_state(active: bool) -> void:
	for player in PlayerQuery.all(get_tree()):
		_set_player_market_state(player, active)

func _set_player_market_state(player: Node, active: bool) -> void:
	if player == null:
		return
	if player.has_method("set_gameplay_input_enabled"):
		player.set_gameplay_input_enabled(not active)
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		return
	if active:
		health.add_invulnerability_source(MARKET_INVULNERABILITY)
	else:
		health.remove_invulnerability_source(MARKET_INVULNERABILITY)

func _on_player_spawned(_player_slot: int, player: Node) -> void:
	if is_market_open:
		_set_player_market_state(player, true)

func _on_player_despawned(player_slot: int, _player: Node) -> void:
	ready_by_slot.erase(player_slot)
	call_deferred("_close_if_all_ready")

func _close_if_all_ready() -> void:
	if is_market_open and _all_alive_players_ready():
		_close_market()

func _on_money_changed(balance: int) -> void:
	wallet_changed.emit(balance)

func _resolve_dependencies() -> void:
	if wave_manager == null:
		wave_manager = get_tree().get_first_node_in_group("wave_manager") as WaveManager
	if progression_manager == null:
		progression_manager = get_tree().get_first_node_in_group(
			"progression_manager"
		) as ProgressionManager
	if player_manager == null:
		player_manager = get_tree().get_first_node_in_group("player_manager") as PlayerManager

func _connect_dependencies() -> void:
	if wave_manager != null:
		var wave_callback := Callable(self, "_on_wave_completed")
		if not wave_manager.wave_completed.is_connected(wave_callback):
			wave_manager.wave_completed.connect(wave_callback)
	if progression_manager != null:
		var money_callback := Callable(self, "_on_money_changed")
		if not progression_manager.money_changed.is_connected(money_callback):
			progression_manager.money_changed.connect(money_callback)
	if player_manager != null:
		var spawn_callback := Callable(self, "_on_player_spawned")
		if not player_manager.player_spawned.is_connected(spawn_callback):
			player_manager.player_spawned.connect(spawn_callback)
		var despawn_callback := Callable(self, "_on_player_despawned")
		if not player_manager.player_despawned.is_connected(despawn_callback):
			player_manager.player_despawned.connect(despawn_callback)

func _resolve_purchase_service() -> void:
	if purchase_service == null:
		purchase_service = PURCHASE_SERVICE_SCRIPT.new(progression_manager)
	else:
		purchase_service.progression_manager = progression_manager

func _get_weapon_cost(rarity: StringName) -> int:
	return maxi(int(weapon_cost_by_rarity.get(rarity, 18)), 1)

func _get_rarity_weight(rarity: StringName) -> float:
	return maxf(float(rarity_weight.get(rarity, 1.0)), 0.01)

func _has_same_offer_set(
	left: Array[StringName],
	right: Array[StringName]
) -> bool:
	if left.size() != right.size():
		return false
	for weapon_id in left:
		if not right.has(weapon_id):
			return false
	return true
