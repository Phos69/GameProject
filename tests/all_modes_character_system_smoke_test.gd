extends SceneTree

# Verifica che il sistema personaggi RPG sia condiviso da tutte le modalita di
# gioco e non solo da Zombie Survival. La logica di applicazione vive ora in
# BaseGameMode (modes/shared), quindi avviando Dungeon o Tower Defense con un
# personaggio nel context, il player riceve stat/super/passiva di quel
# personaggio. Avviando senza personaggio, il player viene riportato al profilo
# generico (clear).
#
# Survival e Infinite Arena (che delega a Survival) sono coperti da
# milestone_rpg_1_character_select_smoke_test e build_runtime_smoke.

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded")
	if main_scene == null:
		_finish()
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await physics_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(player_manager != null, "player manager is available")
	if game_mode_manager == null or player_manager == null:
		_finish()
		return

	# Dungeon applica il personaggio scelto come Zombie Survival.
	await _verify_mode_applies_character(
		game_mode_manager,
		player_manager,
		GameConstants.MODE_DUNGEON,
		&"berserker",
		{"character_id": &"berserker", "seed": 4242, "room_count": 6}
	)

	# Tower Defense applica il personaggio scelto come Zombie Survival.
	await _verify_mode_applies_character(
		game_mode_manager,
		player_manager,
		GameConstants.MODE_TOWER_DEFENSE,
		&"mago",
		{"character_id": &"mago", "initial_delay": 0.0, "starting_credits": 75}
	)

	# Avvio senza personaggio: il player torna generico (nessun personaggio).
	await _verify_mode_clears_character(
		game_mode_manager,
		player_manager,
		GameConstants.MODE_DUNGEON,
		{"seed": 4242, "room_count": 6}
	)

	game_mode_manager.set_mode(GameConstants.MODE_MENU)
	await process_frame
	_finish()

func _verify_mode_applies_character(
	game_mode_manager: GameModeManager,
	player_manager: PlayerManager,
	mode_id: StringName,
	character_id: StringName,
	context: Dictionary
) -> void:
	var started := game_mode_manager.set_mode(mode_id, context)
	_expect(started, "%s starts from a character context" % String(mode_id))
	await process_frame
	await physics_frame
	var rpg := _player_rpg_component(player_manager)
	_expect(rpg != null, "%s keeps player one with an RPG component" % String(mode_id))
	if rpg == null:
		return
	_expect(
		rpg.has_character(),
		"%s applies a character to the player" % String(mode_id)
	)
	_expect(
		rpg.character_id == character_id,
		"%s applies the selected character (%s)" % [
			String(mode_id),
			String(character_id)
		]
	)

func _verify_mode_clears_character(
	game_mode_manager: GameModeManager,
	player_manager: PlayerManager,
	mode_id: StringName,
	context: Dictionary
) -> void:
	var started := game_mode_manager.set_mode(mode_id, context)
	_expect(started, "%s restarts without a character context" % String(mode_id))
	await process_frame
	await physics_frame
	var rpg := _player_rpg_component(player_manager)
	_expect(rpg != null, "%s keeps player one with an RPG component" % String(mode_id))
	if rpg == null:
		return
	_expect(
		not rpg.has_character(),
		"%s without a roster falls back to the generic survivor" % String(mode_id)
	)

func _player_rpg_component(player_manager: PlayerManager) -> RpgPlayerComponent:
	var player_one := player_manager.players.get(1) as PlayerController
	if player_one == null:
		return null
	return player_one.get_node_or_null("RpgPlayerComponent") as RpgPlayerComponent

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ALL_MODES_CHARACTER_SYSTEM_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"ALL_MODES_CHARACTER_SYSTEM_SMOKE_TEST: FAIL (%d)" % failures.size()
	)
	quit(1)
