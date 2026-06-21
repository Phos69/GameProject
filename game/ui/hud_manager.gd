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
var offscreen_enemy_markers: OffscreenEnemyMarkers
var player_cards_container: Control
var player_cards: Dictionary = {}
var pickup_feedback_text: String = ""
var pickup_feedback_timer: float = 0.0
var boss_warning_timer: float = 0.0
var last_boss_display_name: String = "BOSS"
var hud_text_scale: float = 1.0
var high_contrast: bool = false

@export var game_mode_manager_path: NodePath = NodePath("../GameModeManager")
@export var wave_manager_path: NodePath = NodePath("../Systems/WaveManager")
@export var boss_system_path: NodePath = NodePath("../Systems/BossSystem")
@export var drop_system_path: NodePath = NodePath("../Systems/DropSystem")
@export var survival_mode_path: NodePath = NodePath("../Modes/SurvivalMode")
@export var dungeon_mode_path: NodePath = NodePath("../Modes/DungeonMode")
@export var tower_defense_mode_path: NodePath = NodePath(
	"../Modes/TowerDefenseMode"
)
@export var survival_arena_manager_path: NodePath = NodePath(
	"../Systems/SurvivalArenaManager"
)
@export var biome_manager_path: NodePath = NodePath(
	"../Modes/SurvivalMode/ZombieModeController/BiomeManager"
)
@export var hazard_system_path: NodePath = NodePath(
	"../Modes/SurvivalMode/ZombieModeController/HazardSystem"
)
@export var world_runtime_path: NodePath = NodePath(
	"../Modes/SurvivalMode/ZombieModeController/WorldRuntime"
)

var game_mode_manager: GameModeManager
var wave_manager: WaveManager
var boss_system: BossSystem
var drop_system: DropSystem
var survival_mode: SurvivalMode
var dungeon_mode: DungeonMode
var tower_defense_mode: TowerDefenseMode
var survival_arena_manager: SurvivalArenaManager
var biome_manager: BiomeManager
var hazard_system: HazardSystem
var world_runtime: WorldRuntime

const SLOT_COLORS: Array[Color] = [
	Color(0.18, 0.74, 0.95, 1.0),
	Color(0.95, 0.42, 0.34, 1.0),
	Color(0.52, 0.86, 0.32, 1.0),
	Color(0.94, 0.78, 0.28, 1.0)
]
const PLAYER_CARD_SIZE: Vector2 = Vector2(276.0, 184.0)
const PLAYER_CARD_MARGIN: Vector2 = Vector2(18.0, 16.0)
const STATUS_PANEL_WIDTH: float = 340.0

func _ready() -> void:
	add_to_group("hud_manager")
	add_to_group("visual_settings_consumers")
	_resolve_runtime_dependencies()
	_create_status_hud()
	_create_offscreen_markers()
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
	status_panel.custom_minimum_size = Vector2(STATUS_PANEL_WIDTH, 0.0)
	status_panel.anchor_left = 0.5
	status_panel.anchor_top = 0.0
	status_panel.anchor_right = 0.5
	status_panel.anchor_bottom = 0.0
	status_panel.offset_left = -STATUS_PANEL_WIDTH * 0.5
	status_panel.offset_top = 112.0
	status_panel.offset_right = STATUS_PANEL_WIDTH * 0.5
	status_panel.offset_bottom = 0.0
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
	status_label.custom_minimum_size = Vector2(STATUS_PANEL_WIDTH - 28.0, 0.0)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.modulate = Color(0.90, 0.96, 1.0, 1.0)
	status_panel.add_child(status_label)
	status_panel.hide()

func _process(delta: float) -> void:
	pickup_feedback_timer = maxf(pickup_feedback_timer - delta, 0.0)
	if pickup_feedback_timer <= 0.0:
		pickup_feedback_text = ""
	boss_warning_timer = maxf(boss_warning_timer - delta, 0.0)
	var map_open := exploration_map_panel != null and exploration_map_panel.visible
	if map_open:
		_refresh_exploration_map()
	if offscreen_enemy_markers != null:
		offscreen_enemy_markers.visible = not map_open
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"world_map"):
		return
	_resolve_runtime_dependencies()
	if (
		game_mode_manager != null
		and (
			not game_mode_manager.is_gameplay_active()
			or game_mode_manager.active_mode_id != GameConstants.MODE_SURVIVAL
		)
	):
		return
	_toggle_exploration_map()
	get_viewport().set_input_as_handled()

func _refresh() -> void:
	if status_label == null:
		return
	_resolve_runtime_dependencies()
	visible = (
		game_mode_manager == null
		or game_mode_manager.active_mode_id != GameConstants.MODE_MENU
	)
	if not visible:
		return

	var players := PlayerQuery.all(get_tree())
	_refresh_player_cards(players)
	var status_parts := PackedStringArray()
	var biome_status := _format_biome_status()
	if not biome_status.is_empty():
		status_parts.append(biome_status)
	var mode_status := _format_mode_status()
	if not mode_status.is_empty():
		status_parts.append(mode_status)
	if not pickup_feedback_text.is_empty():
		status_parts.append(pickup_feedback_text)
	status_label.text = "\n".join(status_parts)
	if status_panel != null:
		status_panel.visible = (
			_should_show_status_panel(game_mode_manager)
			and not status_label.text.is_empty()
		)
	_refresh_boss_hud()

func _create_player_hud() -> void:
	player_cards_container = Control.new()
	player_cards_container.name = "PlayerCards"
	player_cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_cards_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(player_cards_container)
	for player_slot in range(1, 5):
		var card := PlayerHudCard.new()
		card.name = "Player%dCard" % player_slot
		card.configure(player_slot, SLOT_COLORS[player_slot - 1])
		card.custom_minimum_size = PLAYER_CARD_SIZE
		_place_player_card(card, player_slot)
		card.hide()
		player_cards_container.add_child(card)
		player_cards[player_slot] = card

func _refresh_player_cards(players: Array[Node]) -> void:
	for player_slot in range(1, 5):
		var card := player_cards.get(player_slot) as PlayerHudCard
		if card == null:
			continue
		_place_player_card(card, player_slot)
		card.refresh(_find_player_by_slot(players, player_slot))

func _place_player_card(card: Control, player_slot: int) -> void:
	if card == null:
		return
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var left := PLAYER_CARD_MARGIN.x
	var top := PLAYER_CARD_MARGIN.y
	match player_slot:
		2:
			left = -PLAYER_CARD_MARGIN.x - PLAYER_CARD_SIZE.x
			card.anchor_left = 1.0
			card.anchor_right = 1.0
		3:
			top = -PLAYER_CARD_MARGIN.y - PLAYER_CARD_SIZE.y
			card.anchor_top = 1.0
			card.anchor_bottom = 1.0
		4:
			left = -PLAYER_CARD_MARGIN.x - PLAYER_CARD_SIZE.x
			top = -PLAYER_CARD_MARGIN.y - PLAYER_CARD_SIZE.y
			card.anchor_left = 1.0
			card.anchor_right = 1.0
			card.anchor_top = 1.0
			card.anchor_bottom = 1.0
		_:
			pass
	card.offset_left = left
	card.offset_top = top
	card.offset_right = left + PLAYER_CARD_SIZE.x
	card.offset_bottom = top + PLAYER_CARD_SIZE.y

func _find_player_by_slot(players: Array[Node], player_slot: int) -> Node:
	for player in players:
		if int(player.get("player_slot")) == player_slot:
			return player
	return null

func _get_mode_title() -> String:
	_resolve_runtime_dependencies()
	if game_mode_manager != null:
		match game_mode_manager.active_mode_id:
			GameConstants.MODE_INFINITE_ARENA:
				return "Infinite Arena"
			GameConstants.MODE_DUNGEON:
				return "Procedural Dungeon"
			GameConstants.MODE_TOWER_DEFENSE:
				return "Tower Defense"
			GameConstants.MODE_SURVIVAL:
				if survival_arena_manager != null:
					return survival_arena_manager.get_active_display_name()
	return "Survival Arena"

func _format_mode_status() -> String:
	_resolve_runtime_dependencies()
	if game_mode_manager != null:
		if game_mode_manager.active_mode_id == GameConstants.MODE_INFINITE_ARENA:
			return _format_infinite_arena_status()
		if game_mode_manager.active_mode_id == GameConstants.MODE_DUNGEON:
			if dungeon_mode == null:
				return "Dungeon idle"
			return "%s\n%s  Seed %d\nMap %s" % [
				_get_mode_title(),
				dungeon_mode.get_status_text(),
				dungeon_mode.run_seed,
				dungeon_mode.get_map_text()
			]
		if game_mode_manager.active_mode_id == GameConstants.MODE_TOWER_DEFENSE:
			if tower_defense_mode == null:
				return "Tower Defense\nDefense idle"
			return "%s\n%s" % [
				_get_mode_title(),
				tower_defense_mode.get_status_text()
			]
	return ""

func _should_show_status_panel(game_mode_manager: GameModeManager) -> bool:
	return (
		game_mode_manager != null
		and game_mode_manager.active_mode_id == GameConstants.MODE_TOWER_DEFENSE
	)

func _format_infinite_arena_status() -> String:
	_resolve_runtime_dependencies()
	if wave_manager == null or not wave_manager.run_active:
		return "Infinite Arena\nPreparing arena"
	if wave_manager.wave_running:
		return "Infinite Arena\nWave %d  Enemies %d" % [
			wave_manager.current_wave,
			wave_manager.get_enemies_remaining()
		]
	return "Infinite Arena\nNext wave in %.1fs" % wave_manager.get_intermission_time_left()

func _format_biome_status() -> String:
	_resolve_runtime_dependencies()
	if (
		game_mode_manager != null
		and game_mode_manager.active_mode_id != GameConstants.MODE_SURVIVAL
	):
		return ""
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
	_resolve_runtime_dependencies()
	if hazard_system == null:
		return ""
	var labels := PackedStringArray()
	for player in PlayerQuery.all(get_tree()):
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

func _create_offscreen_markers() -> void:
	offscreen_enemy_markers = OffscreenEnemyMarkers.new()
	offscreen_enemy_markers.name = "OffscreenEnemyMarkers"
	add_child(offscreen_enemy_markers)

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
	_resolve_runtime_dependencies()
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
	_resolve_runtime_dependencies()
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
	_resolve_runtime_dependencies()
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

	if survival_mode != null:
		var defeat_callback := Callable(self, "_on_survival_defeated")
		if not survival_mode.survival_defeated.is_connected(defeat_callback):
			survival_mode.survival_defeated.connect(defeat_callback)
	if biome_manager != null:
		var biome_callback := Callable(self, "_on_current_biome_changed")
		if not biome_manager.current_biome_changed.is_connected(
			biome_callback
		):
			biome_manager.current_biome_changed.connect(biome_callback)
		_apply_biome_hud_theme(biome_manager.get_current_biome())

func _connect_world_runtime() -> void:
	_resolve_runtime_dependencies()
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
	_resolve_runtime_dependencies()
	if (
		game_mode_manager != null
		and game_mode_manager.active_mode_id != GameConstants.MODE_SURVIVAL
	):
		exploration_map_panel.hide_map()
		return
	if world_runtime == null:
		exploration_map_panel.hide_map()
		return
	exploration_map_panel.configure(
		world_runtime.graph,
		world_runtime.get_exploration_state(),
		world_runtime.get_active_region_ids()
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
	_resolve_runtime_dependencies()
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
	_resolve_runtime_dependencies()
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
	_resolve_runtime_dependencies()
	if drop_system == null:
		return
	var callback := Callable(self, "_on_drop_collected")
	if not drop_system.drop_collected.is_connected(callback):
		drop_system.drop_collected.connect(callback)

func _on_drop_collected(drop_data: Dictionary, _collector: Node) -> void:
	var drop_type := StringName(drop_data.get("type", &"unknown"))
	var resource_tag := StringName(drop_data.get("resource_tag", &""))
	if drop_type == GameConstants.DROP_WEAPON:
		var definition := drop_data.get("weapon_data") as WeaponData
		pickup_feedback_text = "NUOVA ARMA: %s" % (
			definition.display_name if definition != null else "SCONOSCIUTA"
		)
	elif not resource_tag.is_empty():
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

func _resolve_runtime_dependencies() -> void:
	if game_mode_manager == null:
		game_mode_manager = _resolve_node(
			game_mode_manager_path,
			&"game_mode_manager"
		) as GameModeManager
	if wave_manager == null:
		wave_manager = _resolve_node(wave_manager_path, &"wave_manager") as WaveManager
	if boss_system == null:
		boss_system = _resolve_node(boss_system_path, &"boss_system") as BossSystem
	if drop_system == null:
		drop_system = _resolve_node(drop_system_path, &"drop_system") as DropSystem
	if survival_mode == null:
		survival_mode = _resolve_node(
			survival_mode_path,
			&"survival_mode"
		) as SurvivalMode
	if dungeon_mode == null:
		dungeon_mode = _resolve_node(dungeon_mode_path, &"dungeon_mode") as DungeonMode
	if tower_defense_mode == null:
		tower_defense_mode = _resolve_node(
			tower_defense_mode_path,
			&"tower_defense_mode"
		) as TowerDefenseMode
	if survival_arena_manager == null:
		survival_arena_manager = _resolve_node(
			survival_arena_manager_path,
			&"survival_arena_manager"
		) as SurvivalArenaManager
	if biome_manager == null:
		biome_manager = _resolve_node(
			biome_manager_path,
			&"biome_manager"
		) as BiomeManager
	if hazard_system == null:
		hazard_system = _resolve_node(
			hazard_system_path,
			&"hazard_system"
		) as HazardSystem
	if world_runtime == null:
		world_runtime = _resolve_node(
			world_runtime_path,
			&"world_runtime"
		) as WorldRuntime

func _resolve_node(path: NodePath, group_name: StringName) -> Node:
	if not path.is_empty():
		var node := get_node_or_null(path)
		if node != null:
			return node
	return get_tree().get_first_node_in_group(group_name)
