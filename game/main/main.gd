extends Node2D

const BUILD_RUNTIME_SMOKE := preload(
	"res://game/debug/build_runtime_smoke.gd"
)

func _ready() -> void:
	add_to_group("game_root")
	if OS.get_cmdline_user_args().has("--build-smoke"):
		var smoke_runner := Node.new()
		smoke_runner.name = "BuildRuntimeSmoke"
		smoke_runner.set_script(BUILD_RUNTIME_SMOKE)
		add_child(smoke_runner)
