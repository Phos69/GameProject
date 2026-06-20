extends RefCounted
class_name SurvivalMarketPurchaseService

var progression_manager: ProgressionManager

func _init(shared_progression: ProgressionManager = null) -> void:
	progression_manager = shared_progression

func try_purchase(player: Node, option: Dictionary) -> Dictionary:
	if player == null or option.is_empty():
		return _denied("Offerta non valida")
	var cost := maxi(int(option.get("cost", 0)), 1)
	var purchase_kind := StringName(option.get("purchase_kind", &""))
	match purchase_kind:
		&"health":
			return _purchase_health(player, int(option.get("amount", 0)), cost)
		&"ammo_active":
			return _purchase_ammo(player, cost, false)
		&"ammo_all":
			return _purchase_ammo(player, cost, true)
		&"weapon":
			return _purchase_weapon(
				player,
				option.get("weapon_data") as WeaponData,
				cost
			)
		_:
			return _denied("Tipo acquisto non supportato")

func _purchase_health(player: Node, amount: int, cost: int) -> Dictionary:
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	if health == null or not health.is_alive():
		return _denied("Cura non disponibile")
	if health.current_health >= health.max_health:
		return _denied("HP gia al massimo")
	if not _spend(cost):
		return _denied("Fondi comuni insufficienti")
	if health.heal(amount) <= 0:
		_refund(cost)
		return _denied("Cura non applicata")
	return _succeeded(cost)

func _purchase_ammo(
	player: Node,
	cost: int,
	refill_all: bool
) -> Dictionary:
	var weapon_system := player.get_node_or_null("WeaponSystem") as WeaponSystem
	if weapon_system == null:
		return _denied("Sistema ammo non disponibile")
	var missing := (
		weapon_system.get_all_ammo_refill_amount()
		if refill_all
		else weapon_system.get_active_ammo_refill_amount()
	)
	if missing <= 0:
		return _denied("Munizioni gia al massimo")
	if not _spend(cost):
		return _denied("Fondi comuni insufficienti")
	var applied := (
		weapon_system.refill_all_ammo()
		if refill_all
		else weapon_system.refill_active_ammo()
	)
	if applied <= 0:
		_refund(cost)
		return _denied("Ammo non applicate")
	return _succeeded(cost)

func _purchase_weapon(
	player: Node,
	definition: WeaponData,
	cost: int
) -> Dictionary:
	var weapon_system := player.get_node_or_null("WeaponSystem") as WeaponSystem
	if definition == null or weapon_system == null:
		return _denied("Arma non disponibile")
	if weapon_system.has_weapon(definition.weapon_id):
		return _denied("Arma gia posseduta")
	if not _spend(cost):
		return _denied("Fondi comuni insufficienti")
	if not weapon_system.add_weapon(definition, true):
		_refund(cost)
		return _denied("Inventario non disponibile")
	return _succeeded(cost)

func _spend(cost: int) -> bool:
	return (
		progression_manager != null
		and progression_manager.try_spend_money(cost)
	)

func _refund(amount: int) -> void:
	if progression_manager != null:
		progression_manager.add_money(amount)

func _succeeded(cost: int) -> Dictionary:
	return {
		"success": true,
		"cost": cost,
		"reason": ""
	}

func _denied(reason: String) -> Dictionary:
	return {
		"success": false,
		"cost": 0,
		"reason": reason
	}
