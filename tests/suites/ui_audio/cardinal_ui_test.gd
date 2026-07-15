extends GutTest
## Guardrail UI per la proiezione top-down cardinale e il branding neutrale.

func test_main_menu_backdrop_grid_uses_only_cardinal_segments() -> void:
	var backdrop := MainMenuBackdrop.new()
	var segments := backdrop._get_cardinal_grid_segments(Vector2(640.0, 360.0))
	var vertical_count := 0
	var horizontal_count := 0
	assert_gt(segments.size(), 2, "il fondale espone una griglia visibile")
	for segment in segments:
		var vertical := is_equal_approx(segment[0].x, segment[1].x)
		var horizontal := is_equal_approx(segment[0].y, segment[1].y)
		assert_true(vertical or horizontal, "ogni linea della griglia e verticale o orizzontale")
		if vertical:
			vertical_count += 1
		if horizontal:
			horizontal_count += 1
	assert_gt(vertical_count, 0, "la griglia include linee verticali")
	assert_gt(horizontal_count, 0, "la griglia include linee orizzontali")
	assert_true(
		is_equal_approx(MainMenuBackdrop.GRID_CELL.x, MainMenuBackdrop.GRID_CELL.y),
		"il fondale usa celle quadrate"
	)
	backdrop.free()

func test_character_preview_floor_is_an_axis_aligned_rect_inside_the_card() -> void:
	var preview := CharacterGameplayPreview.new()
	var card_rect := Rect2(Vector2.ZERO, Vector2(268.0, 140.0))
	var floor_rect := preview._get_cardinal_floor_rect(card_rect)
	assert_true(card_rect.encloses(floor_rect), "il pavimento rettangolare resta dentro la preview")
	assert_gt(floor_rect.size.x, floor_rect.size.y, "la preview conserva un fondale orizzontale leggibile")
	assert_eq(floor_rect.get_center().x, card_rect.get_center().x, "il pavimento resta centrato sulla card")
	preview.free()

func test_exploration_map_regions_and_links_are_cardinal() -> void:
	var panel := ExplorationMapPanel.new()
	var center := Vector2(140.0, 90.0)
	var region_rect := panel._get_region_rect(center, 64.0)
	assert_eq(region_rect.get_center(), center, "la regione rettangolare resta centrata sulla coordinata griglia")
	assert_true(
		is_equal_approx(region_rect.size.x, region_rect.size.y),
		"la regione e rappresentata come cella quadrata"
	)
	var link_points := panel._get_cardinal_link_points(Vector2(0.0, 0.0), Vector2(80.0, 60.0))
	for index in range(link_points.size() - 1):
		var from := link_points[index]
		var to := link_points[index + 1]
		assert_true(
			is_equal_approx(from.x, to.x) or is_equal_approx(from.y, to.y),
			"ogni tratto di collegamento e verticale o orizzontale"
		)
	panel.free()

func test_application_and_export_use_cardinal_branding() -> void:
	assert_eq(
		str(ProjectSettings.get_setting("application/config/name", "")),
		"Local Action Sandbox",
		"il nome applicazione non vincola piu la proiezione"
	)
	assert_eq(MainMenu.PRODUCT_TITLE, "LOCAL ACTION SANDBOX", "il titolo menu segue il branding")
	var export_config := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_true(export_config.contains("build/local_action_sandbox.exe"), "il binario usa il nuovo nome")
	assert_true(export_config.contains('application/product_name="Local Action Sandbox"'), "il prodotto export usa il nuovo nome")
	assert_true(export_config.contains("top-down action sandbox"), "la descrizione export dichiara la vista top-down")
