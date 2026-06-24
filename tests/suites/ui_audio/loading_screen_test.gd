extends GutTest
## UI/Audio — Barra di caricamento del mondo (API determinata + helper show_brief).
##
## Migra:
##   tests/world_loading_screen_smoke_test.gd  (WorldLoadingScreen, scena leggera)

func test_progress_api() -> void:
	var screen := WorldLoadingScreen.new()
	add_child(screen)
	await wait_frames(1)

	# set_progress hard-sets the displayed value.
	screen.set_progress(0.5)
	assert_almost_eq(screen.get_progress(), 0.5, 0.0001, "set_progress hard-sets the value")

	# set_phase floors the bar and never drops below the floor.
	screen.set_phase("Generazione", 0.2, 0.8)
	assert_gte(screen.get_progress(), 0.2, "set_phase keeps progress at or above the floor")

	# A phase with a higher floor pulls the bar up immediately.
	screen.set_phase("Costruzione", 0.6, 0.9)
	assert_gte(screen.get_progress(), 0.6, "a later phase raises the floor")

	# The eased fill stays within the declared band before completion.
	await wait_frames(2)
	assert_lte(screen.get_progress(), 0.9 + 0.0001, "eased fill never exceeds the phase ceiling")

	# Out-of-range phase values are clamped to [0, 1].
	screen.set_phase("Clamp", -1.0, 2.0)
	assert_between(screen.get_progress(), 0.0, 1.0, "phase bounds are clamped")

	screen.complete()
	assert_almost_eq(screen.get_progress(), 1.0, 0.0001, "complete fills the bar to 100%")

	screen.queue_free()
	await wait_frames(1)

func test_show_brief() -> void:
	var host := Node.new()
	host.name = "BriefLoadingHost"
	add_child(host)
	await wait_frames(1)

	var screen := WorldLoadingScreen.show_brief(host, "Caricamento", 0.2)
	assert_not_null(screen, "show_brief returns a loading screen")
	if screen == null:
		host.queue_free()
		return
	assert_true(screen.is_inside_tree(), "show_brief adds the overlay to the tree")
	assert_almost_eq(screen.get_progress(), 0.0, 0.0001, "show_brief starts the bar at 0%")

	# After the (short) duration plus a frame the overlay completes and frees itself.
	await get_tree().create_timer(0.35).timeout
	await wait_frames(1)
	assert_false(is_instance_valid(screen), "show_brief frees the overlay after its duration")

	host.queue_free()
	await wait_frames(1)
