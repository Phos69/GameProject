extends SceneTree

# Milestone C - barra di caricamento.
# Copre l'API determinata di WorldLoadingScreen (set_phase/set_progress/complete)
# e l'helper show_brief usato da Dungeon e Tower Defense.

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_progress_api()
	await _test_show_brief()
	_finish()

func _test_progress_api() -> void:
	var screen := WorldLoadingScreen.new()
	root.add_child(screen)
	await process_frame

	# set_progress hard-sets the displayed value.
	screen.set_progress(0.5)
	_expect(is_equal_approx(screen.get_progress(), 0.5), "set_progress hard-sets the value")

	# set_phase floors the bar and never drops below the floor.
	screen.set_phase("Generazione", 0.2, 0.8)
	_expect(screen.get_progress() >= 0.2, "set_phase keeps progress at or above the floor")

	# A phase with a higher floor pulls the bar up immediately.
	screen.set_phase("Costruzione", 0.6, 0.9)
	_expect(screen.get_progress() >= 0.6, "a later phase raises the floor")

	# The eased fill stays within the declared band before completion.
	await process_frame
	await process_frame
	_expect(screen.get_progress() <= 0.9 + 0.0001, "eased fill never exceeds the phase ceiling")

	# Out-of-range phase values are clamped to [0, 1].
	screen.set_phase("Clamp", -1.0, 2.0)
	_expect(screen.get_progress() >= 0.0 and screen.get_progress() <= 1.0, "phase bounds are clamped")

	screen.complete()
	_expect(is_equal_approx(screen.get_progress(), 1.0), "complete fills the bar to 100%")

	screen.queue_free()
	await process_frame

func _test_show_brief() -> void:
	var host := Node.new()
	host.name = "BriefLoadingHost"
	root.add_child(host)
	await process_frame

	var screen := WorldLoadingScreen.show_brief(host, "Caricamento", 0.2)
	_expect(screen != null, "show_brief returns a loading screen")
	if screen == null:
		host.queue_free()
		return
	_expect(screen.is_inside_tree(), "show_brief adds the overlay to the tree")
	_expect(is_equal_approx(screen.get_progress(), 0.0), "show_brief starts the bar at 0%")

	# After the (short) duration plus a frame the overlay completes and frees itself.
	await create_timer(0.35).timeout
	await process_frame
	_expect(not is_instance_valid(screen), "show_brief frees the overlay after its duration")

	host.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("WORLD_LOADING_SCREEN_SMOKE_TEST: PASS")
		quit(0)
		return
	print("WORLD_LOADING_SCREEN_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
