extends RefCounted
class_name TowerDefenseTargetUtils

## Risolve l'arrivo al core per qualunque CharacterBody2D che percorra il
## tracciato tower defense. Il chiamante conserva l'autorita sul proprio stato
## di morte e passa il segnale specifico da emettere.
static func reach_base(
	target: CharacterBody2D,
	base_damage: int,
	base_reached: Signal
) -> void:
	if not is_instance_valid(target):
		return
	target.velocity = Vector2.ZERO
	target.collision_layer = 0
	target.collision_mask = 0
	var tree := target.get_tree()
	if tree != null:
		var manager := tree.get_first_node_in_group("tower_defense_manager")
		if manager != null:
			manager.damage_base(base_damage)
	base_reached.emit(target, base_damage)
	target.queue_free()
