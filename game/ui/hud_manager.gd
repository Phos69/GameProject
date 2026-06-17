extends CanvasLayer
class_name HUDManager

var status_label: Label
var status_panel: PanelContainer
var status_panel_style: StyleBoxFlat
var boss_panel: PanelContainer
var boss_name_label: Label
var boss_health_bar: ProgressBar
var boss_health_fill_style: StyleBoxFlat
var boss_warning_label: Label
var combat_announcement: CombatAnnouncement
var exploration_map_panel: ExplorationMapPanel
var player_cards_container: HBoxContainer
var player_cards: Dictionary = {}
var pickup_feedback_text: String = ""
var pickup_feedback_timer: float = 0.0
var boss_warning_timer: float = 0.0
var last_boss_display_name: String = "BOSS"
var hud_text_scale: float = 1.0
var high_contrast: bool = false

const SLOT_COLORS: Array[Color] = [
	Color(0.18, 0.74, 0.95, 1.0),
	Color(0.95, 0.42, 0.34, 1.0),
	Color(0.52, 0.86, 0.32, 1.0),
	Color(0.94, 0.78, 0.28, 1.0)
]

func _ready() -> void:
	add_to_group("hud_manager")
	add_to_group("visual_settings_consumers")
	_create_status_hud()
	_create_player_hud()
	_create_boss_hud()
	_create_combat_announcement()
	_create_exploration_map()
	_connect_drop_feedback()
	call_deferred("_connect_boss_system")
	call_deferred("_connect_run_feedback")
	call_deferred("_connect_world_runtime")
	_refresh()
	VisualSettingsManager.sync_consumer(self)

func apply_visual_settings(settings: Dictionary) -> void:
	hud_text_scale = clampf(
		float(settings.get("hud_text_scale", 1.0)),
		0.80,
		1.20
	)
	high_contrast = bool(settings.get("high_contrast", false))
	if status_label != null:
		status_label.add_theme_font_size_override(
			"font_size",
			roundi(16.0 * hud_text_scale)
		)
		status_label.modulate = (
			Color.WHITE
			if high_contrast
			else Color(0.90, 0.96, 1.0, 1.0)
		)
	if boss_name_label != null:
		boss_name_label.add_theme_font_size_override(
			"font_size",
			roundi(20.0 * hud_text_scale)
		)
	if boss_warning_label != null:
		boss_warning_label.add_theme_font_size_override(
			"font_size",
			roundi(16.0 * hud_text_scale)
		)
		boss_warning_label.modulate = (
			Color.WHITE
			if high_contrast
			else Color(1.0, 0.44, 0.24, 1.0)
		)
	for card in player_cards.values():
		if card is PlayerHudCard:
			(card as PlayerHudCard).apply_visual_settings(settings)
	if combat_announcement != null:
		combat_announcement.apply_visual_settings(settings)

func _create_status_hud() -> void:
	status_panel = PanelContainer.new()
	status_panel.name = "StatusPanel"
	status_panel.position = Vector2(16.0, 16.0)
	status_panel.custom_minimum_size = Vector2(368.0, 0.0)
	status_panel_style = StyleBoxFlat.new()
	status_panel_style.bg_color = Color(0.02, 0.032, 0.04, 0.90)
	status_panel_style.border_color = Color(0.36, 0.48, 0.50, 0.78)
	status_panel_style.set_border_width_all(2)
	status_panel_style.corner_radius_top_left = 8
	status_panel_style.corner_radius_top_right = 8
	status_panel_style.corner_radius_bottom_left = 8
	status_panel_style.corner_radius_bottom_right = 8
	status_panel_style.content_margin_left = 14.0
	status_panel_style.content_margin_right = 14.0
	status_panel_style.content_margin_top = 10.0
	status_panel_style.content_margin_bottom = 10.0
	status_panel.add_theme_stylebox_override("panel", status_panel_style)
	add_child(status_panel)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.modulate = Color(0.90, 0.96, 1.0, 1.0)
	status_panel.add_child(status_label)

func _process(delta: float) -> void:
	pickup_feedback_timer = maxf(pickup_feedback_timer - delta, 0.0)
	if pickup_feedback_timer <= 0.0:
		pickup_feedback_text = ""
	boss_warning_timer = maxf(boss_warning_timer - delta, 0.0)
	if exploration_map_panel != null and exploration_map_panel.visible:
		_refresh_exploration_map()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"world_map"):
		return
	var game_mode_manager := get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	if game_mode_manager != null and not game_mode_manager.is_gameplay_active():
		return
	_toggle_exploration_map()
	get_viewport().set_input_as_handled()

func _refresh() -> void:
	if status_label == null:
		return
	var game_mode_manager := get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	visible = (
		game_mode_manager == null
		or game_mode_manager.active_mode_id != GameConstants.MODE_MENU
	)
	if not visible:
		return

	var players := get_tree().get_nodes_in_group("players")
	var active_slots := _get_active_slots(players)
	_refresh_player_cards(players)
	var progression = get_tree().get_first_node_in_group("progression_manager")
	var level := 1
	var experience := 0
	var money := 0
	if progression != null:
		level = progression.level
		experience = progression.experience
		money = progression.money

	status_label.text = "%s\nPlayers: %d/4  Slots: %s\nParty Lv %d  XP %d  Money %d" % [
		_get_mode_title(),
		active_slots.size(),
		_format_slots(active_slots),
		level,
		experience,
		money
	]
	var biome_status := _format_biome_status()
	if not biome_status.is_empty():
		status_label.text += "\n" + biome_status
	var mode_status := _format_mode_status()
	if not mode_status.is_empty():
		status_label.text += "\n" + mode_status
	if not pickup_feedback_text.is_empty():
		status_label.text += "\n" + pickup_feedback_text
	_refresh_boss_hud()

func _create_player_hud() -> void:
	var margin := MarginContainer.new()
	margin.name = "PlayerCardsMargin"
	margin.anchor_left = 0.0
	margin.anchor_top = 1.0
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_left = 18.0
	margin.offset_top = -204.0
	margin.offset_right = -18.0
	margin.offset_bottom = -16.0
	add_child(margin)

	player_cards_container = HBoxContainer.new()
	player_cards_container.name = "PlayerCards"
	player_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	player_cards_container.add_theme_constant_override("separation", 12)
	margin.add_child(player_cards_container)
	for player_slot in range(1, 5):
		var card := PlayerHudCard.new()
		card.name = "Player%dCard" % player_slot
		card.configure(player_slot, SLOT_COLORS[player_slot - 1])
		card.hide()
		player_cards_container.add_child(card)
		player_cards[player_slot] = card

func _refresh_player_cards(players: Array[Node]) -> void:
	for player_slot in range(1, 5):
		var card := player_cards.get(player_slot) as PlayerHudCard
		if card == null:
			continue
		card.refresh(_find_player_by_slot(players, player_slot))

func _find_player_by_slot(players: Array[Node], player_slot: int) -> Node:
	for player in players:
		if int(player.get("player_slot")) == player_slot:
			return player
	return null

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

func _get_mode_title() -> String:
	var game_mode_manager := get_tree().get_first_node_in_group("game_mode_manager") as GameModeManager
	if game_mode_manager != null:
		match game_mode_manager.active_mode_id:
			GameConstants.MODE_DUNGEON:
				return "Procedural Dungeon"
			GameConstants.MODE_TOWER_DEFENSE:
				return "Tower Defense"
			GameConstants.MODE_SURVIVAL:
				var arena_manager := get_tree().get_first_node_in_group(
					"survival_arena_manager"
				) as SurvivalArenaManager
				if arena_manager != null:
					return arena_manager.get_active_display_name()
	return "Survival Arena"

func _format_mode_status() -> String:
	var game_mode_manager := get_tree().get_first_node_in_group("game_mode_manager") as GameModeManager
	if game_mode_manager != null:
		if game_mode_manager.active_mode_id == GameConstants.MODE_DUNGEON:
			var dungeon_mode := get_tree().get_first_node_in_group("dungeon_mode") as DungeonMode
			if dungeon_mode == null:
				return "Dungeon idle"
			return "%s  Seed %d\nMap %s" % [dungeon_mode.get_status_text(), dungeon_mode.run_seed, dungeon_mode.get_map_text()]
		if game_mode_manager.active_mode_id == GameConstants.MODE_TOWER_DEFENSE:
			var tower_defense_mode := get_tree().get_first_node_in_group(
				"tower_defense_mode"
			) as TowerDefenseMode
			if tower_defense_mode == null:
				return "Defense idle"
			return tower_defense_mode.get_status_text()
	return _format_wave_status()

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

func _format_biome_status() -> String:
	var game_mode_manager := get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	if (
		game_mode_manager != null
		and game_mode_manager.active_mode_id != GameConstants.MODE_SURVIVAL
	):
		return ""
	var biome_manager := get_tree().get_first_node_in_group(
		"biome_manager"
	) as BiomeManager
	if biome_manager == null:
		return ""
	var biome := biome_manager.get_current_biome() as BiomeDefinition
	if biome == null:
		return ""
	var text := "[%s] %s  |  %s\nResources: %s" % [
		_biome_icon_label(biome.biome_icon_id),
		biome.display_name,
		biome.danger_summary,
		biome.resource_summary
	]
	var status_text := _format_environment_statuses()
	if not status_text.is_empty():
		text += "\nStatus: " + status_text
	return text

func _format_environment_statuses() -> String:
	var hazard_system := get_tree().get_first_node_in_group(
		"hazard_system"
	) as HazardSystem
	if hazard_system == null:
		return ""
	var labels := PackedStringArray()
	for player in get_tree().get_nodes_in_group("players"):
		var player_slot := int(player.get("player_slot"))
		var status_ids := hazard_system.get_player_status_ids(player)
		if status_ids.is_empty():
			continue
		var status_labels := PackedStringArray()
		for status_id in status_ids:
			status_labels.append(_status_icon_label(status_id))
		labels.append("P%d %s" % [
			player_slot,
			"/".join(status_labels)
		])
	return "  ".join(labels)

func _biome_icon_label(icon_id: StringName) -> String:
	match icon_id:
		&"toxic":
			return "TOX"
		&"fire":
			return "FIRE"
		&"frost":
			return "ICE"
		&"marsh":
			return "MUD"
		_:
			return "BIO"

func _status_icon_label(status_id: StringName) -> String:
	match status_id:
		&"poison", &"poisoned", &"toxic_puddle", &"gas_cloud", &"toxic_cloud":
			return "TOX"
		&"burn", &"burning", &"fire_zone", &"lava_crack", &"fire_patch", &"explosion":
			return "FIRE"
		&"freeze", &"chilled", &"slippery_ice", &"deep_snow_slow":
			return "ICE"
		&"bleed", &"mudded", &"soaked", &"mud_slow", &"deep_water":
			return "MUD"
		&"fall_zone":
			return "FALL"
		_:
			return String(status_id).to_upper()

func _format_last_reward(reward: Dictionary) -> String:
	if reward.is_empty():
		return ""
	return "  Reward +%d$ +%d Ammo +%d HP +%d XP" % [
		int(reward.get("money", 0)),
		int(reward.get("ammo", 0)),
		int(reward.get("health", 0)),
		int(reward.get("experience", 0))
	]

func _create_boss_hud() -> void:
	boss_panel = PanelContainer.new()
	boss_panel.name = "BossPanel"
	boss_panel.anchor_left = 0.5
	boss_panel.anchor_top = 0.0
	boss_panel.anchor_right = 0.5
	boss_panel.anchor_bottom = 0.0
	boss_panel.offset_left = -230.0
	boss_panel.offset_top = 14.0
	boss_panel.offset_right = 230.0
	boss_panel.offset_bottom = 104.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.018, 0.04, 0.90)
	panel_style.border_color = Color(0.62, 0.24, 0.76, 0.88)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_top = 7.0
	panel_style.content_margin_bottom = 7.0
	boss_panel.add_theme_stylebox_override("panel", panel_style)
	boss_panel.hide()
	add_child(boss_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	boss_panel.add_child(content)

	boss_name_label = Label.new()
	boss_name_label.name = "BossNameLabel"
	boss_name_label.custom_minimum_size = Vector2(420.0, 25.0)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 20)
	boss_name_label.add_theme_constant_override("outline_size", 4)
	boss_name_label.add_theme_color_override(
		"font_outline_color",
		Color(0.01, 0.01, 0.02, 0.95)
	)
	boss_name_label.modulate = Color(1.0, 0.78, 0.92, 1.0)
	boss_name_label.hide()
	content.add_child(boss_name_label)

	boss_health_bar = ProgressBar.new()
	boss_health_bar.name = "BossHealthBar"
	boss_health_bar.custom_minimum_size = Vector2(420.0, 20.0)
	boss_health_bar.min_value = 0.0
	boss_health_bar.max_value = 100.0
	boss_health_bar.show_percentage = false
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.04, 0.03, 0.06, 0.92)
	background_style.border_color = Color(0.56, 0.28, 0.72, 0.9)
	background_style.set_border_width_all(2)
	background_style.corner_radius_top_left = 6
	background_style.corner_radius_top_right = 6
	background_style.corner_radius_bottom_left = 6
	background_style.corner_radius_bottom_right = 6
	boss_health_bar.add_theme_stylebox_override("background", background_style)
	boss_health_fill_style = StyleBoxFlat.new()
	boss_health_fill_style.bg_color = Color(0.82, 0.20, 0.46, 1.0)
	boss_health_fill_style.corner_radius_top_left = 5
	boss_health_fill_style.corner_radius_top_right = 5
	boss_health_fill_style.corner_radius_bottom_left = 5
	boss_health_fill_style.corner_radius_bottom_right = 5
	boss_health_bar.add_theme_stylebox_override("fill", boss_health_fill_style)
	boss_health_bar.hide()
	content.add_child(boss_health_bar)

	boss_warning_label = Label.new()
	boss_warning_label.name = "BossWarningLabel"
	boss_warning_label.custom_minimum_size = Vector2(420.0, 20.0)
	boss_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_warning_label.add_theme_font_size_override("font_size", 16)
	boss_warning_label.add_theme_constant_override("outline_size", 3)
	boss_warning_label.add_theme_color_override(
		"font_outline_color",
		Color(0.01, 0.01, 0.02, 0.95)
	)
	boss_warning_label.modulate = Color(1.0, 0.44, 0.24, 1.0)
	boss_warning_label.hide()
	content.add_child(boss_warning_label)

func _create_combat_announcement() -> void:
	combat_announcement = CombatAnnouncement.new()
	combat_announcement.name = "CombatAnnouncement"
	add_child(combat_announcement)

func _create_exploration_map() -> void:
	exploration_map_panel = ExplorationMapPanel.new()
	exploration_map_panel.name = "ExplorationMapPanel"
	add_child(exploration_map_panel)

func _refresh_boss_hud() -> void:
	if (
		boss_panel == null
		or
		boss_name_label == null
		or boss_health_bar == null
		or boss_warning_label == null
	):
		return
	var boss_system := get_tree().get_first_node_in_group("boss_system") as BossSystem
	var boss := boss_system.get_active_boss() if boss_system != null else null
	if boss == null:
		boss_panel.hide()
		boss_name_label.hide()
		boss_health_bar.hide()
		boss_warning_label.hide()
		boss_warning_timer = 0.0
		return

	_connect_boss_feedback(boss)
	var health_component := boss.get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null:
		boss_panel.hide()
		boss_name_label.hide()
		boss_health_bar.hide()
		boss_warning_label.hide()
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
	boss_health_fill_style.bg_color = (
		Color(0.94, 0.24, 0.40, 1.0)
		if phase_index >= 2
		else Color(0.82, 0.20, 0.46, 1.0)
	)
	boss_panel.show()
	boss_name_label.show()
	boss_health_bar.show()
	boss_warning_label.visible = boss_warning_timer > 0.0

func _connect_boss_system() -> void:
	var boss_system := get_tree().get_first_node_in_group("boss_system") as BossSystem
	if boss_system == null:
		return
	var callback := Callable(self, "_on_boss_spawned")
	if not boss_system.boss_spawned.is_connected(callback):
		boss_system.boss_spawned.connect(callback)
	var defeated_callback := Callable(self, "_on_boss_defeated")
	if not boss_system.boss_defeated.is_connected(defeated_callback):
		boss_system.boss_defeated.connect(defeated_callback)
	_connect_boss_feedback(boss_system.get_active_boss())

func _connect_boss_feedback(boss: Node) -> void:
	if boss == null:
		return
	var telegraph_callback := Callable(self, "_on_boss_telegraph_started")
	if (
		boss.has_signal("attack_telegraph_started")
		and not boss.is_connected(
			"attack_telegraph_started",
			telegraph_callback
		)
	):
		boss.connect("attack_telegraph_started", telegraph_callback)
	var phase_callback := Callable(self, "_on_boss_phase_changed")
	if (
		boss.has_signal("phase_changed")
		and not boss.is_connected("phase_changed", phase_callback)
	):
		boss.connect("phase_changed", phase_callback)

func _on_boss_spawned(boss: Node) -> void:
	_connect_boss_feedback(boss)
	last_boss_display_name = str(boss.get("display_name"))
	_refresh_boss_hud()
	if combat_announcement != null:
		combat_announcement.show_announcement(
			&"boss_spawn",
			last_boss_display_name.to_upper(),
			"BOSS INCOMING",
			Color(0.96, 0.24, 0.70, 1.0),
			2.0
		)

func _on_boss_defeated(_mode_id: StringName) -> void:
	if combat_announcement != null:
		combat_announcement.show_announcement(
			&"boss_defeated",
			"%s DOWN" % last_boss_display_name.to_upper(),
			"SPECIAL DROP AVAILABLE",
			Color(0.34, 0.92, 0.72, 1.0),
			2.1
		)

func _on_boss_telegraph_started(
	pattern_id: StringName,
	duration: float,
	_direction: Vector2
) -> void:
	match pattern_id:
		&"radial_burst":
			boss_warning_label.text = "RADIAL BURST - FIND A GAP"
		&"lane_sweep":
			boss_warning_label.text = "LANE SWEEP - FIND THE GAP"
		&"cross_burst":
			boss_warning_label.text = "CROSS BURST - ROTATE"
		_:
			boss_warning_label.text = "AIMED VOLLEY - MOVE"
	boss_warning_label.modulate = Color(1.0, 0.44, 0.24, 1.0)
	boss_warning_timer = maxf(duration, 0.15)

func _on_boss_phase_changed(phase_index: int) -> void:
	boss_warning_label.text = "PHASE %d - OVERDRIVE" % phase_index
	boss_warning_label.modulate = Color(1.0, 0.30, 0.68, 1.0)
	boss_warning_timer = 1.20
	if combat_announcement != null:
		combat_announcement.show_announcement(
			&"boss_phase",
			"OVERDRIVE",
			"PHASE %d" % phase_index,
			Color(1.0, 0.28, 0.62, 1.0),
			1.35
		)

func _connect_run_feedback() -> void:
	var wave_manager := get_tree().get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	if wave_manager != null:
		var intermission_callback := Callable(
			self,
			"_on_intermission_started"
		)
		if not wave_manager.intermission_started.is_connected(
			intermission_callback
		):
			wave_manager.intermission_started.connect(intermission_callback)
		var wave_callback := Callable(self, "_on_wave_started")
		if not wave_manager.wave_started.is_connected(wave_callback):
			wave_manager.wave_started.connect(wave_callback)
		var reward_callback := Callable(self, "_on_wave_reward_granted")
		if not wave_manager.wave_reward_granted.is_connected(reward_callback):
			wave_manager.wave_reward_granted.connect(reward_callback)

	var survival_mode := get_tree().get_first_node_in_group(
		"survival_mode"
	) as SurvivalMode
	if survival_mode != null:
		var defeat_callback := Callable(self, "_on_survival_defeated")
		if not survival_mode.survival_defeated.is_connected(defeat_callback):
			survival_mode.survival_defeated.connect(defeat_callback)
	var biome_manager := get_tree().get_first_node_in_group(
		"biome_manager"
	) as BiomeManager
	if biome_manager != null:
		var biome_callback := Callable(self, "_on_current_biome_changed")
		if not biome_manager.current_biome_changed.is_connected(
			biome_callback
		):
			biome_manager.current_biome_changed.connect(biome_callback)
		_apply_biome_hud_theme(biome_manager.get_current_biome())

func _connect_world_runtime() -> void:
	var world_runtime := get_tree().get_first_node_in_group(
		"world_runtime"
	) as WorldRuntime
	if world_runtime == null:
		return
	var callback := Callable(self, "_on_exploration_changed")
	if not world_runtime.exploration_changed.is_connected(callback):
		world_runtime.exploration_changed.connect(callback)
	_refresh_exploration_map()

func _on_exploration_changed(_state: WorldExplorationState) -> void:
	_refresh_exploration_map()

func _toggle_exploration_map() -> void:
	if exploration_map_panel == null:
		return
	_refresh_exploration_map()
	exploration_map_panel.toggle()

func _refresh_exploration_map() -> void:
	if exploration_map_panel == null:
		return
	var world_runtime := get_tree().get_first_node_in_group(
		"world_runtime"
	) as WorldRuntime
	if world_runtime == null:
		exploration_map_panel.hide_map()
		return
	exploration_map_panel.configure(
		world_runtime.graph,
		world_runtime.get_exploration_state()
	)

func _on_intermission_started(
	next_wave_index: int,
	duration: float
) -> void:
	if combat_announcement == null or duration <= 0.25:
		return
	if (
		combat_announcement.is_active()
		and combat_announcement.announcement_id in [
			&"wave_clear",
			&"boss_phase",
			&"boss_defeated",
			&"run_over"
		]
	):
		return
	combat_announcement.show_announcement(
		&"intermission",
		"GET READY",
		"WAVE %d" % next_wave_index,
		Color(0.30, 0.78, 1.0, 1.0),
		minf(duration, 1.5)
	)

func _on_wave_started(wave_index: int) -> void:
	if combat_announcement == null:
		return
	var wave_manager := get_tree().get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var is_boss_wave := (
		wave_manager != null
		and wave_manager.current_wave_is_boss
	)
	combat_announcement.show_announcement(
		&"boss_wave" if is_boss_wave else &"wave_started",
		"BOSS WAVE" if is_boss_wave else "WAVE %d" % wave_index,
		"STAY TOGETHER" if is_boss_wave else "SURVIVE",
		Color(1.0, 0.30, 0.58, 1.0)
		if is_boss_wave
		else Color(1.0, 0.72, 0.24, 1.0),
		1.65
	)

func _on_wave_reward_granted(
	wave_index: int,
	reward: Dictionary
) -> void:
	if combat_announcement == null:
		return
	if (
		combat_announcement.is_active()
		and combat_announcement.announcement_id == &"boss_defeated"
	):
		return
	combat_announcement.show_announcement(
		&"wave_clear",
		"WAVE %d CLEAR" % wave_index,
		"+%d CREDITS  +%d AMMO  +%d HP  +%d XP" % [
			int(reward.get("money", 0)),
			int(reward.get("ammo", 0)),
			int(reward.get("health", 0)),
			int(reward.get("experience", 0))
		],
		Color(0.34, 0.92, 0.58, 1.0),
		1.8
	)

func _on_survival_defeated(wave_index: int) -> void:
	if combat_announcement != null:
		combat_announcement.show_announcement(
			&"run_over",
			"RUN OVER",
			"REACHED WAVE %d" % wave_index,
			Color(1.0, 0.34, 0.28, 1.0),
			2.4
		)

func _on_current_biome_changed(
	_biome_id: StringName,
	display_name: String
) -> void:
	var biome_manager := get_tree().get_first_node_in_group(
		"biome_manager"
	) as BiomeManager
	var biome: BiomeDefinition = (
		biome_manager.get_current_biome()
		if biome_manager != null
		else null
	)
	_apply_biome_hud_theme(biome)
	if combat_announcement != null and biome != null:
		combat_announcement.show_announcement(
			&"biome_entered",
			display_name.to_upper(),
			biome.danger_summary,
			biome.palette.gate_color
			if biome.palette != null
			else Color(0.42, 0.90, 0.58, 1.0),
			2.2
		)

func _apply_biome_hud_theme(biome) -> void:
	if status_panel_style == null or not biome is BiomeDefinition:
		return
	var definition := biome as BiomeDefinition
	if definition.palette == null:
		return
	status_panel_style.border_color = Color(
		definition.palette.gate_color,
		0.90
	)
	status_panel_style.bg_color = Color(
		definition.palette.background_color.darkened(0.45),
		0.92
	)

func _connect_drop_feedback() -> void:
	var drop_system := get_tree().get_first_node_in_group("drop_system") as DropSystem
	if drop_system == null:
		return
	var callback := Callable(self, "_on_drop_collected")
	if not drop_system.drop_collected.is_connected(callback):
		drop_system.drop_collected.connect(callback)

func _on_drop_collected(drop_data: Dictionary, _collector: Node) -> void:
	var drop_type := StringName(drop_data.get("type", &"unknown"))
	var resource_tag := StringName(drop_data.get("resource_tag", &""))
	if not resource_tag.is_empty():
		pickup_feedback_text = "%s +%d" % [
			String(resource_tag).replace("_", " ").to_upper(),
			int(drop_data.get("amount", 0))
		]
	elif drop_type == GameConstants.DROP_AMMO:
		pickup_feedback_text = "AMMO SHARED +%d" % int(
			drop_data.get("amount", 0)
		)
	else:
		return
	pickup_feedback_timer = 1.75
