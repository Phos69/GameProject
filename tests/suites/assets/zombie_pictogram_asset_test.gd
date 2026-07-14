extends GutTest
## Asset contract for regular and elite zombie raster pictograms.

const PICTOGRAM_PATHS: Array[String] = [
	"res://assets/sprites/enemies/zombie/basic_zombie.png",
	"res://assets/sprites/enemies/zombie/runner_zombie.png",
	"res://assets/sprites/enemies/zombie/tank_zombie.png",
	"res://assets/sprites/enemies/zombie/shooter_zombie.png",
	"res://assets/sprites/enemies/zombie/toxic_reaver.png",
	"res://assets/sprites/enemies/zombie/ember_hound.png",
	"res://assets/sprites/enemies/zombie/glacial_bulwark.png",
	"res://assets/sprites/enemies/zombie/mire_stalker.png"
]

func test_zombie_pictograms_are_loadable_rgba_assets() -> void:
	for path in PICTOGRAM_PATHS:
		assert_true(FileAccess.file_exists(path), "%s exists" % path)
		var texture := ResourceLoader.load(path) as Texture2D
		assert_not_null(texture, "%s loads as Texture2D" % path)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s loads as Image" % path)
		if image.is_empty():
			continue
		assert_eq(image.get_size(), Vector2i(512, 512), "%s uses the canonical canvas" % path)
		assert_eq(image.detect_alpha(), Image.ALPHA_BLEND, "%s has blended alpha edges" % path)
		for corner in [Vector2i.ZERO, Vector2i(511, 0), Vector2i(0, 511), Vector2i(511, 511)]:
			assert_lt(image.get_pixelv(corner).a, 0.01, "%s has a transparent corner" % path)

func test_zombie_pictogram_manifest_lists_the_full_roster() -> void:
	var path := "res://assets/sprites/enemies/zombie/manifest.json"
	assert_true(FileAccess.file_exists(path), "zombie pictogram manifest exists")
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Dictionary, "zombie pictogram manifest parses")
	if parsed is Dictionary:
		assert_eq((parsed as Dictionary).get("assets", {}).size(), 8, "manifest lists four base archetypes and four elites")
