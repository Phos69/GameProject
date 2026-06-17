extends SceneTree

# Milestone 6 - Connessioni aperte tra biomi.
# Copre: dimensionamento del BiomeTransitionGate dalla larghezza del passaggio,
# orientamento corretto per i quattro lati, tipo di passaggio propagato al gate
# e clamp/fallback dello span.

const SPAN := 96.0

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_run_orientation_and_span()
	_run_passage_kind()
	_run_span_clamp_and_fallback()
	_run_containment()
	_finish()

func _run_orientation_and_span() -> void:
	var cases := {
		&"north": Vector2.UP,
		&"south": Vector2.DOWN,
		&"east": Vector2.RIGHT,
		&"west": Vector2.LEFT
	}
	for side in cases.keys():
		var gate := _make_gate(side, &"road", SPAN)
		_expect(
			gate.get_direction_vector() == cases[side],
			"%s gate points along its travel direction" % String(side)
		)
		if side == &"north" or side == &"south":
			_expect(
				is_equal_approx(gate.gate_size.x, SPAN)
				and is_equal_approx(gate.gate_size.y, BiomeTransitionGate.GATE_DEPTH),
				"%s gate opens along X with a fixed depth" % String(side)
			)
		else:
			_expect(
				is_equal_approx(gate.gate_size.y, SPAN)
				and is_equal_approx(gate.gate_size.x, BiomeTransitionGate.GATE_DEPTH),
				"%s gate opens along Y with a fixed depth" % String(side)
			)
		gate.queue_free()

func _run_passage_kind() -> void:
	for passage_type in ["road", "bridge", "snow_pass", "broken_gate", "burned_road"]:
		var gate := _make_gate(&"east", StringName(passage_type), SPAN)
		_expect(
			gate.passage_kind == StringName(passage_type),
			"gate stores the %s passage kind" % passage_type
		)
		gate.queue_free()

func _run_span_clamp_and_fallback() -> void:
	var tiny := _make_gate(&"east", &"road", 8.0)
	_expect(
		is_equal_approx(tiny.gate_size.y, BiomeTransitionGate.MIN_SPAN),
		"a passage narrower than the minimum is clamped to a readable span"
	)
	tiny.queue_free()

	var legacy := _make_gate(&"east", &"open_passage", 0.0)
	_expect(
		is_equal_approx(legacy.gate_size.y, BiomeTransitionGate.DEFAULT_SPAN),
		"a gate without a passage span keeps the legacy default size"
	)
	legacy.queue_free()

func _run_containment() -> void:
	var gate := _make_gate(&"east", &"road", SPAN)
	gate.position = Vector2(500.0, 120.0)
	_expect(
		gate.contains_global_position(gate.position),
		"gate footprint contains its own center"
	)
	_expect(
		not gate.contains_global_position(gate.position + Vector2(400.0, 0.0)),
		"gate footprint rejects a distant point"
	)
	gate.queue_free()

func _make_gate(
	side: StringName,
	passage_type: StringName,
	span: float
) -> BiomeTransitionGate:
	var gate := BiomeTransitionGate.new()
	root.add_child(gate)
	gate.configure(
		&"toxic_wastes",
		side,
		Vector2.ZERO,
		Color(0.42, 0.90, 0.58, 1.0),
		&"biome_1_1",
		passage_type,
		span
	)
	return gate

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_6_OPEN_PASSAGE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_6_OPEN_PASSAGE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
