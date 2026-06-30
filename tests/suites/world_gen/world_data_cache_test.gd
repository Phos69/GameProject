extends GutTest
## World Generation — WorldDataCache: firme canoniche, evizione LRU, indipendenza
## del clone e riuso end-to-end del mondo via BiomeManager.
##
## Verifica il cuore del riuso: lo stesso mondo viene servito (clone indipendente)
## a prescindere dalle chiavi di gameplay, con un tetto a numero di mondi (LRU).

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")

func before_each() -> void:
	# Questa suite verifica la semantica LRU IN MEMORIA (has/size/hits). Il tier
	# disco e' gia spento per tutta la suite dal pre_run hook, cosi store/fetch non
	# scrivono ne' leggono snapshot su user://.
	WorldDataCache.clear()
	WorldDataCache.set_enabled(true)
	WorldDataCache.set_max_worlds(WorldDataCache.DEFAULT_MAX_WORLDS)

func after_all() -> void:
	WorldDataCache.clear()
	WorldDataCache.set_enabled(true)
	WorldDataCache.set_max_worlds(WorldDataCache.DEFAULT_MAX_WORLDS)

# --- Firme -----------------------------------------------------------------

func test_canonical_key_ignores_gameplay_keys() -> void:
	var base := {"world_seed": 4242, "biome_map_width": 2}
	var with_character := base.duplicate()
	with_character["selected_character_id"] = &"alpha"
	with_character["run_seed"] = 777
	with_character["async_world_build"] = true
	assert_eq(
		WorldDataCache.canonical_key(with_character),
		WorldDataCache.canonical_key(base),
		"le chiavi di gameplay non cambiano l'identita dei dati"
	)

func test_canonical_key_ignores_render_runtime_keys() -> void:
	var base := {"world_seed": 4242}
	var with_render := base.duplicate()
	with_render["disable_world_runtime"] = true
	with_render["disable_region_streaming"] = true
	with_render["arena_id"] = &"ruins"
	assert_eq(
		WorldDataCache.canonical_key(with_render),
		WorldDataCache.canonical_key(base),
		"i toggle di render/runtime non cambiano i DATI generati"
	)

func test_canonical_key_changes_with_generation_keys() -> void:
	assert_ne(
		WorldDataCache.canonical_key({"world_seed": 1}),
		WorldDataCache.canonical_key({"world_seed": 2}),
		"un seed diverso e un mondo diverso"
	)
	assert_ne(
		WorldDataCache.canonical_key({"world_seed": 1, "biome_map_width": 1}),
		WorldDataCache.canonical_key({"world_seed": 1, "biome_map_width": 3}),
		"dimensioni mappa diverse sono mondi diversi"
	)

func test_build_signature_keeps_render_but_not_gameplay() -> void:
	var base := {"world_seed": 9, "disable_region_streaming": true}
	var gameplay_only := base.duplicate()
	gameplay_only["selected_character_id"] = &"beta"
	assert_eq(
		WorldDataCache.build_signature(gameplay_only),
		WorldDataCache.build_signature(base),
		"la firma-scena ignora il gameplay (il park riusa il mondo)"
	)
	var render_changed := base.duplicate()
	render_changed["disable_region_streaming"] = false
	assert_ne(
		WorldDataCache.build_signature(render_changed),
		WorldDataCache.build_signature(base),
		"la firma-scena cambia se cambia cosa viene bakeato/streamato"
	)

# --- LRU / evizione --------------------------------------------------------

func test_lru_evicts_least_recently_used() -> void:
	WorldDataCache.set_max_worlds(2)
	WorldDataCache.store({"world_seed": 1001}, _make_world(1001, &"c1"))
	WorldDataCache.store({"world_seed": 1002}, _make_world(1002, &"c2"))
	WorldDataCache.store({"world_seed": 1003}, _make_world(1003, &"c3"))
	assert_eq(WorldDataCache.size(), 2, "il cap a 2 mondi sfratta i piu vecchi")
	assert_false(WorldDataCache.has({"world_seed": 1001}), "il piu vecchio e sfrattato")
	assert_true(WorldDataCache.has({"world_seed": 1003}), "il piu recente resta")

func test_fetch_promotes_to_most_recently_used() -> void:
	WorldDataCache.set_max_worlds(2)
	WorldDataCache.store({"world_seed": 2001}, _make_world(2001, &"a"))
	WorldDataCache.store({"world_seed": 2002}, _make_world(2002, &"b"))
	# Riusa il piu vecchio: torna MRU e non deve essere il prossimo sfrattato.
	assert_false(WorldDataCache.fetch({"world_seed": 2001}).is_empty(), "hit su 2001")
	WorldDataCache.store({"world_seed": 2003}, _make_world(2003, &"c"))
	assert_true(WorldDataCache.has({"world_seed": 2001}), "2001 promosso sopravvive")
	assert_false(WorldDataCache.has({"world_seed": 2002}), "2002 (ora LRU) e sfrattato")

func test_clear_empties_cache() -> void:
	WorldDataCache.store({"world_seed": 1}, _make_world(1, &"x"))
	WorldDataCache.clear()
	assert_eq(WorldDataCache.size(), 0, "clear svuota la cache")
	assert_false(WorldDataCache.has({"world_seed": 1}), "niente entry dopo clear")

func test_disabled_cache_is_noop() -> void:
	WorldDataCache.set_enabled(false)
	WorldDataCache.store({"world_seed": 1}, _make_world(1, &"x"))
	assert_false(WorldDataCache.has({"world_seed": 1}), "store e no-op da disabilitata")
	assert_true(WorldDataCache.fetch({"world_seed": 1}).is_empty(), "fetch e vuoto da disabilitata")

# --- Indipendenza del clone ------------------------------------------------

func test_fetch_returns_independent_clone() -> void:
	var ctx := {"world_seed": 3003}
	var world := _make_world(3003, &"cell_a")
	WorldDataCache.store(ctx, world)
	# Mutare l'originale non deve toccare il master in cache (store ha clonato).
	(world["cells"][0] as BiomeCell).clear_runtime_links()
	var first := WorldDataCache.fetch(ctx)
	var first_cell := first["cells"][0] as BiomeCell
	assert_eq(first_cell.id, &"cell_a", "il clone conserva la cella")
	assert_ne(first_cell, world["cells"][0], "il clone e un'istanza diversa dall'originale")
	# Ogni fetch e un clone distinto e integro.
	var second := WorldDataCache.fetch(ctx)
	assert_ne(second["cells"][0], first_cell, "ogni fetch e un clone nuovo")

# --- Integrazione end-to-end via BiomeManager ------------------------------

func test_clone_preserves_rich_layout_content() -> void:
	var ctx := _arena_context(8800555)
	var manager := WorldGen.start_biome_manager(self, ctx, "CacheContent")
	var original_cell := manager.get_current_biome_cell()
	assert_not_null(original_cell, "il build produce una cella corrente")
	var original_layout: BiomeEnvironmentLayout = (
		original_cell.generated_layout if original_cell != null else null
	)
	assert_not_null(original_layout, "la cella ha un layout generato")

	var cached := WorldDataCache.fetch(ctx)
	assert_false(cached.is_empty(), "il mondo e in cache dopo il primo build")
	var clone_cell := (cached.get("cells", []) as Array)[0] as BiomeCell
	var clone_layout := clone_cell.generated_layout
	assert_not_null(clone_layout, "il clone porta il layout generato")
	if clone_layout == null or original_layout == null:
		WorldGen.free_biome_manager(manager)
		return
	assert_eq(clone_layout.get_generation_signature(), original_layout.get_generation_signature(),
		"il clone ha la stessa firma di layout")
	assert_eq(clone_layout.rock_rects.size(), original_layout.rock_rects.size(),
		"il clone preserva i rock_rects void-first")
	assert_eq(clone_layout.road_cell_tags.size(), original_layout.road_cell_tags.size(),
		"il clone preserva le road_cell_tags")
	assert_eq(
		clone_layout.perimeter_visual_style,
		BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF,
		"il clone preserva lo stile cliff del perimetro walled"
	)
	assert_eq(
		clone_layout.wall_height_cells,
		BiomeEnvironmentLayout.RAISED_CLIFF_HEIGHT_CELLS,
		"il clone preserva l'altezza del cliff perimetrale"
	)
	# La cache di classificazione (PackedByteArray) e copiata: stessa classe al centro.
	var spawn := original_layout.player_spawn_cell
	assert_eq(
		clone_layout.get_terrain_class_at_cell(spawn, clone_cell),
		original_layout.get_terrain_class_at_cell(spawn, original_cell),
		"il clone classifica il terreno come l'originale"
	)
	# Indipendenza: svuotare l'originale non tocca il clone.
	var rocks_before := clone_layout.rock_rects.size()
	original_layout.rock_rects.clear()
	assert_eq(clone_layout.rock_rects.size(), rocks_before,
		"il clone resta integro dopo aver mutato l'originale")
	WorldGen.free_biome_manager(manager)

func test_same_world_reused_across_gameplay_change() -> void:
	var base := _arena_context(8800123)
	var first_ctx := base.duplicate()
	first_ctx["selected_character_id"] = &"alpha"
	var first := WorldGen.start_biome_manager(self, first_ctx, "CacheE2E_1")
	var first_signature := first.get_generation_signature()
	assert_eq(WorldDataCache.size(), 1, "il primo build popola la cache")

	var second_ctx := base.duplicate()
	second_ctx["selected_character_id"] = &"beta"  # solo gameplay diverso
	second_ctx["run_seed"] = 999
	var hits_before := int(WorldDataCache.stats().get("hits", 0))
	var second := WorldGen.start_biome_manager(self, second_ctx, "CacheE2E_2")
	var second_signature := second.get_generation_signature()

	assert_eq(int(WorldDataCache.stats().get("hits", 0)), hits_before + 1,
		"il secondo build riusa il mondo dalla cache nonostante il gameplay diverso")
	assert_eq(second_signature, first_signature,
		"il mondo servito dalla cache ha la stessa firma del primo")
	assert_eq(WorldDataCache.size(), 1,
		"nessun mondo extra: la chiave canonica ignora il gameplay")

	WorldGen.free_biome_manager(first)
	WorldGen.free_biome_manager(second)

# --- helper ----------------------------------------------------------------

func _arena_context(seed_value: int) -> Dictionary:
	return {
		"world_seed": seed_value,
		"single_biome_arena": true,
		"biome_map_width": 1,
		"biome_map_height": 1,
		"arena_boundary_mode": "walled"
	}

func _make_world(seed_value: int, cell_id: StringName) -> Dictionary:
	var cell := BiomeCell.new()
	cell.configure(cell_id, &"infected_plains", Vector2i.ZERO, Vector2i(8, 8), seed_value)
	var cells: Array[BiomeCell] = [cell]
	return {
		"seed": seed_value,
		"cells": cells,
		"world_graph": null,
		"start_cell": cell,
		"signature": "sig-%d" % seed_value,
		"seed_record": {"global_seed": seed_value}
	}
