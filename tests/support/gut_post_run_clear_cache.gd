extends GutHookScript
## Post-run hook GUT: svuota le cache statiche a fine suite.
##
## Le cache sono singleton di processo (static): senza questo cleanup i mondi,
## manifest e texture costruiti dalle ultime suite resterebbero referenziati fino
## all'uscita del processo, gonfiando i warning "resources still in use at exit".
## Azzerarle qui non toglie nulla al riuso cross-suite (avviene gia durante il
## run) e mantiene il cleanup confinato ai test.

const SVG_TEXTURE_LOADER = preload(
	"res://game/modes/zombie/environment_texture_loader.gd"
)
const GENERATED_TEXTURE_TOOLS = preload(
	"res://game/modes/zombie/generated_biome_texture_tools.gd"
)

func run() -> void:
	for _index in range(3):
		await gut.get_tree().process_frame
		await gut.get_tree().physics_frame
	WorldDataCache.clear()
	EnvironmentAssetManifest.clear_shared()
	SVG_TEXTURE_LOADER.clear_cache()
	GENERATED_TEXTURE_TOOLS.clear_cache()
	EnvironmentObject.clear_content_metrics_cache()
