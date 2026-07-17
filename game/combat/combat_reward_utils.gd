extends RefCounted
class_name CombatRewardUtils

## Assegna l'esperienza della kill all'ultimo attaccante registrato dal
## sistema vita. Nemici e boss condividono questo percorso per evitare che
## reward e conferma kill divergano tra tipi di bersaglio.
static func grant_kill_experience(
	tree: SceneTree,
	defeated: Node,
	experience_amount: int
) -> bool:
	if tree == null or not is_instance_valid(defeated) or experience_amount <= 0:
		return false
	var health_system := tree.get_first_node_in_group("health_system") as HealthSystem
	if health_system == null:
		return false
	var killer := health_system.get_last_damage_source(defeated)
	health_system.clear_last_damage_source(defeated)
	if not is_instance_valid(killer):
		return false
	var rpg_component := killer.get_node_or_null(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	if rpg_component == null:
		return false
	rpg_component.add_experience(experience_amount)
	rpg_component.notify_kill_confirmed()
	return true
