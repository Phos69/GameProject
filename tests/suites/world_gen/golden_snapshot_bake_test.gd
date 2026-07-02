extends GutTest
## World Generation — Produce e valida lo SNAPSHOT GOLDEN persistito su disco che
## il gameplay riusa (WorldDataCache tier disco, user://), con guardia di
## correttezza del codec di serializzazione e del tile-bake.
##
## A differenza delle altre suite (tier disco spenti dal pre_run hook), questa li
## riaccende SOLO per se' per scrivere lo snapshot e li rispegne in after_all,
## lasciando i file su disco: e' esattamente cio' che il gioco deve riusare.

const GoldenWorld = preload("res://tests/support/golden_world.gd")
const WorldGen = preload("res://tests/support/world_gen_helpers.gd")
const WorldSnapshotCodec = preload(
	"res://game/procedural/world_generation/world_snapshot_codec.gd"
)

# Contesto con cui il GIOCO genera il mondo golden di default: vuoto. Il seed e gli
# altri parametri di generazione restano ai default golden, e canonical_key({})
# combacia con quello usato a runtime (le chiavi di gameplay sono escluse), quindi
# il gameplay riusa proprio questo snapshot.
const GAMEPLAY_CONTEXT := {}

func before_all() -> void:
	WorldDataCache.set_enabled(true)
	WorldDataCache.clear()

func after_all() -> void:
	# Ripristina l'invariante della suite (tier disco spenti) MA lascia lo snapshot
	# su disco: e' cio' che il gameplay deve riusare al prossimo avvio.
	WorldDataCache.set_disk_enabled(false)
	TileBakeCache.set_enabled(false)
	WorldDataCache.clear()

func test_gameplay_key_ignores_gameplay_context() -> void:
	# Lo snapshot va scritto sotto canonical_key({}); il gioco lo fetcha con un
	# contesto che porta personaggio/run_seed: la chiave canonica deve combaciare.
	assert_eq(
		WorldDataCache.canonical_key(GAMEPLAY_CONTEXT),
		WorldDataCache.canonical_key({
			"character_id": &"alpha",
			"character_ids_by_slot": {"1": &"alpha"},
			"run_seed": 4242,
			"async_world_build": true
		}),
		"il contesto runtime (personaggio+async) ha la stessa chiave dello snapshot golden"
	)

func test_codec_roundtrips_compact_golden() -> void:
	# Veloce: valida la serializzazione (codec + to_dict/from_dict) su un mondo
	# golden compatto, con cache off (generazione vera, non hit).
	WorldDataCache.set_enabled(false)
	WorldDataCache.set_disk_enabled(false)
	var manager := WorldGen.start_biome_manager(
		self, GoldenWorld.compact_context(), "CodecRoundtrip"
	)
	var world_data: Dictionary = manager.active_world_data
	var signature := String(world_data.get("signature", ""))
	assert_ne(signature, "", "il mondo golden compatto produce una firma")

	var decoded := WorldSnapshotCodec.world_data_from_dict(
		WorldSnapshotCodec.world_data_to_dict(world_data)
	)
	assert_false(decoded.is_empty(), "il codec decodifica lo snapshot")
	assert_eq(String(decoded.get("signature", "")), signature,
		"la firma del mondo sopravvive al round-trip")
	var src_cells := world_data.get("cells", []) as Array
	var dec_cells := decoded.get("cells", []) as Array
	assert_eq(dec_cells.size(), src_cells.size(), "tutte le celle sopravvivono")
	if not dec_cells.is_empty() and not src_cells.is_empty():
		var dec_cell := dec_cells[0] as BiomeCell
		var src_cell := src_cells[0] as BiomeCell
		assert_eq(dec_cell.id, src_cell.id, "l'id della cella sopravvive")
		assert_not_null(dec_cell.generated_layout, "il layout generato sopravvive")
		if dec_cell.generated_layout != null and src_cell.generated_layout != null:
			assert_eq(
				dec_cell.generated_layout.get_generation_signature(),
				src_cell.generated_layout.get_generation_signature(),
				"la firma del layout sopravvive al round-trip"
			)
	WorldDataCache.release_world_data(decoded)
	WorldGen.free_biome_manager(manager)

func test_golden_snapshot_written_for_gameplay() -> void:
	# Ground truth: genera il mondo golden del GAMEPLAY (contesto vuoto) con cache
	# off, cosi e' una generazione vera.
	WorldDataCache.set_enabled(false)
	WorldDataCache.set_disk_enabled(false)
	var manager := WorldGen.start_biome_manager(
		self, GAMEPLAY_CONTEXT.duplicate(), "GoldenBake"
	)
	var world_data: Dictionary = manager.active_world_data
	var signature := String(world_data.get("signature", ""))
	assert_ne(signature, "", "il mondo golden di gameplay produce una firma")
	assert_eq(manager.get_generation_seed(), GameConstants.GOLDEN_WORLD_SEED,
		"il contesto di gameplay genera col seed golden")

	# Scrive lo snapshot SEMPRE FRESCO (nessun drift: e' la generazione corrente)
	# sotto la stessa chiave canonica usata dal gioco.
	WorldDataCache.set_enabled(true)
	WorldDataCache.set_disk_enabled(true)
	WorldDataCache.clear()
	WorldDataCache.clear_disk()
	WorldDataCache.store(GAMEPLAY_CONTEXT, world_data)
	assert_true(WorldDataCache.has_on_disk(GAMEPLAY_CONTEXT),
		"lo snapshot golden e' persistito su user:// per il gameplay")

	# Il gioco (nuovo processo, memoria vuota) lo riusa: fetch dal SOLO disco.
	WorldDataCache.clear()
	var from_disk := WorldDataCache.fetch(GAMEPLAY_CONTEXT)
	assert_false(from_disk.is_empty(), "hit dal tier disco a memoria vuota")
	assert_eq(String(from_disk.get("signature", "")), signature,
		"lo snapshot su disco combacia col mondo golden generato")
	assert_eq(
		(from_disk.get("cells", []) as Array).size(),
		(world_data.get("cells", []) as Array).size(),
		"lo snapshot su disco conserva tutte le celle"
	)
	WorldDataCache.release_world_data(from_disk)
	WorldGen.free_biome_manager(manager)

func test_tile_bake_cache_roundtrips() -> void:
	# Valida il meccanismo del tile-bake su disco senza un bake completo: store ->
	# fetch ritorna le mappe risolte; guardie su cell_count.
	TileBakeCache.set_enabled(true)
	TileBakeCache.clear()
	var key := TileBakeCache.make_key(&"infected_plains", &"balanced", "layout-sig", 10)
	var payload := {
		"tile_id": {0: &"forest_grass", 1: &"forest_path"},
		"tile_section": {0: &"ground"},
		"tile_role": {0: &"walkable"},
		"asset_path": {0: "res://tile.svg"},
		"missing_asset_count": 2
	}
	TileBakeCache.store(key, 2, payload)
	var loaded := TileBakeCache.fetch(key, 2)
	assert_false(loaded.is_empty(), "il tile-bake e' servito da disco")
	assert_eq(int(loaded.get("missing_asset_count", -1)), 2,
		"il conteggio asset mancanti sopravvive")
	var tile_id_map := loaded.get("tile_id", {}) as Dictionary
	assert_eq(StringName(tile_id_map.get(1, &"")), &"forest_path",
		"la mappa tile_id sopravvive al round-trip")
	assert_true(TileBakeCache.fetch(key, 999).is_empty(),
		"cell_count diverso -> niente hit (guardia)")
	var legacy_path := (
		"user://world_cache/bake/"
		+ key.sha256_text()
		+ ".bin"
	)
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	assert_not_null(legacy_file, "la fixture cache legacy e scrivibile")
	if legacy_file != null:
		legacy_file.store_var({
			"format_version": 3,
			"key": key,
			"cell_count": 2,
			"payload": payload
		})
		legacy_file.close()
	assert_true(TileBakeCache.fetch(key, 2).is_empty(),
		"TileBakeCache invalida automaticamente un formato legacy")
	TileBakeCache.clear()
	TileBakeCache.set_enabled(false)
