extends SceneTree

## Test unitario dell'helper condiviso PlayerQuery (Fase 1 roadmap tecnica).
## Costruisce player sintetici nel gruppo "players" con HealthComponent e
## verifica le query alive/downed/nearest/by_slot in isolamento.

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var p_alive := _make_player(1, Vector2(0, 0))
	var p_downed := _make_player(2, Vector2(100, 0))
	var p_dead := _make_player(3, Vector2(3, 0))
	(PlayerQuery.health_component(p_downed)).is_downed = true
	(PlayerQuery.health_component(p_dead)).is_dead = true
	await process_frame

	# Inventario completo.
	_expect(PlayerQuery.all(self).size() == 3, "all() ritorna tutti i player")

	# Stato per-player.
	_expect(PlayerQuery.is_alive(p_alive), "player vivo riconosciuto")
	_expect(not PlayerQuery.is_alive(p_downed), "player downed non e vivo")
	_expect(not PlayerQuery.is_alive(p_dead), "player morto non e vivo")
	_expect(PlayerQuery.is_downed(p_downed), "player downed riconosciuto")
	_expect(not PlayerQuery.is_downed(p_alive), "player vivo non e downed")
	_expect(PlayerQuery.is_incapacitated(p_downed), "downed e incapacitato")
	_expect(PlayerQuery.is_incapacitated(p_dead), "morto e incapacitato")
	_expect(not PlayerQuery.is_incapacitated(p_alive), "vivo non e incapacitato")
	_expect(PlayerQuery.any_alive(self), "any_alive vero con un vivo")

	# Collezioni filtrate.
	var alive := PlayerQuery.alive(self)
	_expect(alive.size() == 1 and alive[0] == p_alive, "alive() solo il vivo")
	var downed := PlayerQuery.downed(self)
	_expect(downed.size() == 1 and downed[0] == p_downed, "downed() solo il downed")

	# Nearest: da (4,0) il morto e piu vicino ma escluso se alive_only.
	var query_pos := Vector2(4, 0)
	_expect(
		PlayerQuery.nearest(self, query_pos) == p_alive,
		"nearest() salta i non vivi"
	)
	_expect(
		PlayerQuery.nearest(self, query_pos, false) == p_dead,
		"nearest(alive_only=false) include i non vivi"
	)
	_expect(
		is_equal_approx(
			PlayerQuery.nearest_distance_squared(self, query_pos), 16.0
		),
		"nearest_distance_squared misura il vivo"
	)

	# Lookup per slot.
	_expect(PlayerQuery.by_slot(self, 2) == p_downed, "by_slot trova lo slot")
	_expect(PlayerQuery.by_slot(self, 9) == null, "by_slot slot assente -> null")

	# Robustezza su tree nullo / gruppo vuoto.
	_expect(PlayerQuery.all(null).is_empty(), "all(null) e vuoto")
	_expect(PlayerQuery.health_component(null) == null, "health_component(null) null")

	_finish()

const PLAYER_STUB_SOURCE := "extends Node2D\nvar player_slot: int = 0\n"

func _make_player(slot: int, position: Vector2) -> Node2D:
	var stub_script := GDScript.new()
	stub_script.source_code = PLAYER_STUB_SOURCE
	stub_script.reload()
	var player := Node2D.new()
	player.set_script(stub_script)
	player.name = "Player%d" % slot
	player.position = position
	player.set("player_slot", slot)
	player.add_to_group(PlayerQuery.PLAYERS_GROUP)
	var health := HealthComponent.new()
	health.name = PlayerQuery.HEALTH_COMPONENT_NODE
	player.add_child(health)
	root.add_child(player)
	return player

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: %s" % message)

func _finish() -> void:
	if failures.is_empty():
		print("player_query_smoke_test passed")
		quit(0)
	else:
		push_error("player_query_smoke_test FAILED (%d)" % failures.size())
		quit(1)
