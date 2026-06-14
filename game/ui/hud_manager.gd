extends CanvasLayer
class_name HUDManager

var status_label: Label
var boss_name_label: Label
var boss_health_bar: ProgressBar

func _ready() -> void:
	add_to_group("hud_manager")
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(18.0, 18.0)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.modulate = Color(0.90, 0.96, 1.0, 1.0)
	add_child(status_label)
	_create_boss_hud()
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if status_label == null:
		return

	var players := get_tree().get_nodes_in_group("players")
	var active_slots := _get_active_slots(players)
	var progression = get_tree().get_first_node_in_group("progression_manager")
	var level := 1
	var experience := 0
	var money := 0
	if progression != null:
		level = progression.level
		experience = progression.experience
		money = progression.money

	status_label.text = "Survival Arena\nPlayers: %d/4  Slots: %s\nParty Lv %d  XP %d  Money %d" % [
		active_slots.size(),
		_format_slots(active_slots),
		level,
		experience,
		money
	]
	var combat_status := _format_combat_status(players)
	if not combat_status.is_empty():
		status_label.text += "\n" + combat_status
	var wave_status := _format_wave_status()
	if not wave_status.is_empty():
		status_label.text += "\n" + wave_status
	_refresh_boss_hud()

func _get_active_slots(players: Array[Node]) -> Array:
	var local_multiplayer = get_tree().get_first_node_in_group("local_multiplayer_manager")
	if local_multiplayer != null and local_multiplayer.has_method("get_active_slots"):
		return local_multiplayer.get_active_slots()

	var slots: Array[int] = []
	for player in players:
		slots.append(int(player.get("player_slot")))
	return slots

func _format_slots(active_slots: Array) -> String:
	var labels := PackedStringArray()
	for player_slot in active_slots:
		labels.append("P%d" % int(player_slot))
	return " ".join(labels)

func _format_combat_status(players: Array[Node]) -> String:
	var lines := PackedStringArray()
	for player in players:
		var player_slot := int(player.get("player_slot"))
		var health_component := player.get_node_or_null("HealthComponent")
		var weapon_system := player.get_node_or_null("WeaponSystem")
		var current_health := 0
		var max_health := 0
		var ammo_text := "-"
		if health_component != null:
			current_health = int(health_component.get("current_health"))
			max_health = int(health_component.get("max_health"))
		if weapon_system != null and weapon_system.has_method("get_ammo_text"):
			ammo_text = weapon_system.get_ammo_text()
		lines.append("P%d  HP %d/%d  Ammo %s" % [
			player_slot,
			current_health,
			max_health,
			ammo_text
		])
	lines.sort()
	return "\n".join(lines)

func _format_wave_status() -> String:
	var wave_manager := get_tree().get_first_node_in_group("wave_manager") as WaveManager
	if wave_manager == null:
		return ""

	match wave_manager.state:
		&"intermission":
			return "Next Wave %d in %.1fs%s" % [
				wave_manager.current_wave + 1,
				wave_manager.get_intermission_time_left(),
				_format_last_reward(wave_manager.last_reward)
			]
		&"spawning":
			return "Wave %d%s  Spawning  Enemies %d/%d" % [
				wave_manager.current_wave,
				" BOSS" if wave_manager.current_wave_is_boss else "",
				wave_manager.get_enemies_remaining(),
				wave_manager.current_wave_enemy_total
			]
		&"combat":
			return "Wave %d%s  Enemies %d/%d" % [
				wave_manager.current_wave,
				" BOSS" if wave_manager.current_wave_is_boss else "",
				wave_manager.get_enemies_remaining(),
				wave_manager.current_wave_enemy_total
			]
		&"reward":
			return "Wave %d Complete%s" % [
				wave_manager.current_wave,
				_format_last_reward(wave_manager.last_reward)
			]
		_:
			return "Survival idle"

func _format_last_reward(reward: Dictionary) -> String:
	if reward.is_empty():
		return ""
	return "  Reward +%d$ +%d Ammo +%d HP" % [
		int(reward.get("money", 0)),
		int(reward.get("ammo", 0)),
		int(reward.get("health", 0))
	]

func _create_boss_hud() -> void:
	boss_name_label = Label.new()
	boss_name_label.name = "BossNameLabel"
	boss_name_label.position = Vector2(440.0, 18.0)
	boss_name_label.size = Vector2(400.0, 26.0)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 20)
	boss_name_label.modulate = Color(1.0, 0.78, 0.92, 1.0)
	boss_name_label.hide()
	add_child(boss_name_label)

	boss_health_bar = ProgressBar.new()
	boss_health_bar.name = "BossHealthBar"
	boss_health_bar.position = Vector2(440.0, 48.0)
	boss_health_bar.size = Vector2(400.0, 24.0)
	boss_health_bar.min_value = 0.0
	boss_health_bar.max_value = 100.0
	boss_health_bar.show_percentage = false
	boss_health_bar.hide()
	add_child(boss_health_bar)

func _refresh_boss_hud() -> void:
	if boss_name_label == null or boss_health_bar == null:
		return
	var boss_system := get_tree().get_first_node_in_group("boss_system") as BossSystem
	var boss := boss_system.get_active_boss() if boss_system != null else null
	if boss == null:
		boss_name_label.hide()
		boss_health_bar.hide()
		return

	var health_component := boss.get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null:
		boss_name_label.hide()
		boss_health_bar.hide()
		return

	var display_name := str(boss.get("display_name"))
	var phase_index := int(boss.get("phase_index"))
	boss_name_label.text = "%s  Phase %d  %d/%d" % [
		display_name,
		phase_index,
		health_component.current_health,
		health_component.max_health
	]
	boss_health_bar.max_value = float(health_component.max_health)
	boss_health_bar.value = float(health_component.current_health)
	boss_name_label.show()
	boss_health_bar.show()
