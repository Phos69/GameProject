extends GutTest
## Combat A5 — Edge case di HealthComponent/HealthSystem (QA-001).
##
## Copre i contratti al limite non toccati dagli smoke di flusso: overkill e
## clamp del danno, cap di cura, sorgenti di invulnerabilita' multiple e
## bypass, danno/cura negli stati downed/dead, transizioni revive/kill_downed,
## set_max_health e tracking dell'ultima sorgente di danno anche con
## riferimenti liberati. Test sintetici: nessun boot di main.tscn.

class DamageFilterTarget:
	extends Node2D
	## Bersaglio con hook modify_incoming_damage: dimezza il danno in arrivo.

	func modify_incoming_damage(amount: int, _source_id: StringName = &"") -> int:
		return int(float(maxi(amount, 0)) * 0.5)

func _make_target(
	max_health: int,
	downed_enabled: bool = false,
	root: Node2D = null
) -> Node2D:
	var target := root if root != null else Node2D.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = max_health
	health.downed_enabled = downed_enabled
	target.add_child(health)
	add_child_autofree(target)
	return target

func _health_of(target: Node) -> HealthComponent:
	return target.get_node("HealthComponent") as HealthComponent

func test_overkill_and_invalid_amounts() -> void:
	var target := _make_target(50)
	var health := _health_of(target)
	watch_signals(health)
	assert_eq(health.apply_damage(80), 50, "overkill applies only the remaining health")
	assert_eq(health.current_health, 0, "overkill clamps health at zero")
	assert_true(health.is_dead, "lethal damage without downed support kills")
	assert_signal_emit_count(health, "died", 1, "died fires exactly once")
	assert_eq(health.apply_damage(10), 0, "dead targets take no further damage")
	assert_signal_emit_count(health, "died", 1, "died is never re-emitted")

	var live := _make_target(50)
	var live_health := _health_of(live)
	watch_signals(live_health)
	assert_eq(live_health.apply_damage(0), 0, "zero damage applies nothing")
	assert_eq(live_health.apply_damage(-15), 0, "negative damage neither heals nor hurts")
	assert_eq(live_health.current_health, 50, "invalid amounts leave health untouched")
	assert_signal_not_emitted(live_health, "damaged", "invalid amounts emit no damaged signal")

func test_heal_caps_and_incapacitated_states() -> void:
	var target := _make_target(100)
	var health := _health_of(target)
	health.apply_damage(30)
	watch_signals(health)
	assert_eq(health.heal(500), 30, "healing past the cap applies only the missing health")
	assert_eq(health.current_health, 100, "healing clamps at max health")
	assert_eq(health.heal(10), 0, "healing at full health applies nothing")
	assert_signal_emit_count(health, "healed", 1, "no healed signal fires for a zero heal")

	var downed_target := _make_target(60, true)
	var downed_health := _health_of(downed_target)
	downed_health.apply_damage(60)
	assert_true(downed_health.is_downed, "lethal damage with downed support downs the target")
	assert_eq(downed_health.heal(20), 0, "downed targets cannot be healed directly")
	assert_eq(downed_health.apply_damage(15), 0, "downed targets take no further damage")

	var dead_target := _make_target(40)
	var dead_health := _health_of(dead_target)
	dead_health.apply_damage(40)
	assert_true(dead_health.is_dead, "target dies for the dead-heal check")
	assert_eq(dead_health.heal(20), 0, "dead targets cannot be healed")

func test_invulnerability_sources_and_bypass() -> void:
	var system := HealthSystem.new()
	add_child_autofree(system)
	var target := _make_target(100)
	var health := _health_of(target)
	health.add_invulnerability_source(&"dodge_roll")
	health.add_invulnerability_source(&"revive_grace")
	health.add_invulnerability_source(&"")
	assert_false(health.has_invulnerability_source(&""), "empty source ids are ignored")
	assert_true(health.is_invulnerable(), "stacked sources grant invulnerability")
	assert_eq(system.apply_damage(target, 25), 0, "invulnerability blocks system damage")
	health.remove_invulnerability_source(&"dodge_roll")
	assert_true(health.is_invulnerable(), "invulnerability persists while any source remains")
	assert_eq(
		system.apply_damage(target, 25, null, &"", Vector2.ZERO, true),
		25,
		"ignore_invulnerability bypasses every source"
	)
	health.remove_invulnerability_source(&"revive_grace")
	assert_false(health.is_invulnerable(), "removing all sources clears invulnerability")
	assert_eq(system.apply_damage(target, 25), 25, "damage applies again without sources")
	assert_eq(health.current_health, 50, "both applied hits reached the health pool")

func test_downed_transitions_and_revive_bounds() -> void:
	var target := _make_target(80, true)
	var health := _health_of(target)
	watch_signals(health)
	health.apply_damage(200)
	assert_true(health.is_downed and not health.is_dead, "lethal damage downs instead of killing")
	assert_signal_emitted(health, "downed", "downed signal fires")
	assert_signal_not_emitted(health, "died", "died does not fire on downed")
	assert_true(health.revive(999), "downed targets can be revived")
	assert_eq(health.current_health, 80, "revive clamps restored health at max")
	assert_false(health.revive(10), "revive on an active target is rejected")
	health.apply_damage(200)
	assert_true(health.is_downed, "target downs again for the kill_downed check")
	health.kill_downed()
	assert_true(health.is_dead and not health.is_downed, "kill_downed converts downed to dead")
	assert_signal_emitted(health, "died", "kill_downed emits died")
	assert_false(health.revive(10), "dead targets cannot be revived")

	var floored := _make_target(80, true)
	var floored_health := _health_of(floored)
	floored_health.apply_damage(500)
	assert_true(floored_health.revive(0), "revive accepts a zero request")
	assert_eq(floored_health.current_health, 1, "revive guarantees at least 1 hp")

func test_set_max_health_clamps() -> void:
	var target := _make_target(100)
	var health := _health_of(target)
	health.set_max_health(40)
	assert_eq(health.max_health, 40, "max health shrinks on request")
	assert_eq(health.current_health, 40, "shrinking max health clamps current health")
	assert_true(is_equal_approx(health.get_health_ratio(), 1.0), "ratio stays normalized after the clamp")
	health.set_max_health(90, true)
	assert_eq(health.current_health, 90, "refill fills the new maximum")
	health.set_max_health(0)
	assert_eq(health.max_health, 1, "max health never drops below 1")

func test_last_damage_source_tracking_and_hook() -> void:
	var system := HealthSystem.new()
	add_child_autofree(system)
	var attacker := Node2D.new()
	add_child_autofree(attacker)
	var target := _make_target(100)
	system.apply_damage(target, 10, attacker, &"claw")
	assert_eq(system.get_last_damage_source(target), attacker, "last damage source is tracked")
	system.clear_last_damage_source(target)
	assert_null(system.get_last_damage_source(target), "clearing forgets the source")

	var doomed := Node2D.new()
	add_child(doomed)
	system.apply_damage(target, 10, doomed, &"bite")
	doomed.free()
	assert_null(system.get_last_damage_source(target), "a freed source is never returned")

	assert_eq(system.apply_damage(target, -5, attacker), 0, "negative system damage resolves to zero")
	assert_null(system.get_last_damage_source(target), "zero-damage hits do not record a source")

	var filtered := _make_target(100, false, DamageFilterTarget.new())
	assert_eq(
		system.apply_damage(filtered, 40, attacker),
		20,
		"modify_incoming_damage halves the resolved damage"
	)
	assert_eq(_health_of(filtered).current_health, 80, "the filtered amount reaches the health pool")
