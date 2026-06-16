extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var component := PlayerDodgeComponent.new()
	root.add_child(component)
	component.max_gap_cross_distance = 160.0
	var landing := [Rect2(Vector2(80.0, -24.0), Vector2(90.0, 48.0))]
	var gap := [Rect2(Vector2(38.0, -18.0), Vector2(34.0, 36.0))]
	var clear_report := component.validate_gap_trajectory(
		Vector2.ZERO,
		Vector2(120.0, 0.0),
		[],
		gap,
		landing
	)
	_expect(bool(clear_report.get("is_valid", false)), "dodge can cross a small valid gap")
	_expect(bool(clear_report.get("crosses_gap", false)), "small gap traversal is detected")

	var wall_report := component.validate_gap_trajectory(
		Vector2.ZERO,
		Vector2(120.0, 0.0),
		[Rect2(Vector2(52.0, -20.0), Vector2(20.0, 40.0))],
		gap,
		landing
	)
	_expect(not bool(wall_report.get("is_valid", true)), "dodge cannot cross walls")
	_expect(bool(wall_report.get("blocked", false)), "wall obstruction is reported")

	var long_gap_report := component.validate_gap_trajectory(
		Vector2.ZERO,
		Vector2(220.0, 0.0),
		[],
		[Rect2(Vector2(30.0, -18.0), Vector2(150.0, 36.0))],
		[Rect2(Vector2(200.0, -24.0), Vector2(70.0, 48.0))]
	)
	_expect(not bool(long_gap_report.get("is_valid", true)), "dodge rejects gaps beyond max distance")

	var player := CharacterBody2D.new()
	var runtime_dodge := PlayerDodgeComponent.new()
	player.add_child(runtime_dodge)
	root.add_child(player)
	_expect(runtime_dodge.try_start(Vector2.RIGHT), "runtime dodge starts on a minimal player body")
	for _frame in range(20):
		runtime_dodge.physics_process_dodge(0.02)
	_expect(not runtime_dodge.is_dodging, "runtime dodge finishes")
	_expect(runtime_dodge.get_cooldown_ratio() > 0.0, "runtime dodge starts cooldown")
	player.queue_free()
	component.queue_free()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("PLAYER_DODGE_GAP_SMOKE_TEST: PASS")
		quit(0)
		return
	print("PLAYER_DODGE_GAP_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
