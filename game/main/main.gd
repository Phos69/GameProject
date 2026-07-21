extends Node2D

const BUILD_RUNTIME_SMOKE := preload(
	"res://game/debug/build_runtime_smoke.gd"
)
const RUNTIME_DIAGNOSTICS := preload(
	"res://game/debug/runtime_diagnostics.gd"
)

func _ready() -> void:
	add_to_group("game_root")
	if (
		DisplayServer.get_name() != "headless"
		or OS.get_cmdline_user_args().has("--runtime-diagnostics")
	):
		var diagnostics := RUNTIME_DIAGNOSTICS.new() as RuntimeDiagnostics
		diagnostics.name = "RuntimeDiagnostics"
		add_child(diagnostics)
	if OS.get_cmdline_user_args().has("--build-smoke"):
		var smoke_runner := Node.new()
		smoke_runner.name = "BuildRuntimeSmoke"
		smoke_runner.set_script(BUILD_RUNTIME_SMOKE)
		add_child(smoke_runner)
