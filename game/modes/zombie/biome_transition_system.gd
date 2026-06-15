extends Node
class_name BiomeTransitionSystem

signal transition_gate_spawned(
	gate: BiomeTransitionGate,
	target_biome_id: StringName
)
signal biome_transitioned(
	previous_biome_id: StringName,
	current_biome_id: StringName
)

const TRANSITION_GATE_SCRIPT = preload(
	"res://game/modes/zombie/biome_transition_gate.gd"
)

@export var environment_container_path: NodePath = NodePath(
	"../../../../World/EnvironmentProps"
)
@export var east_gate_position: Vector2 = Vector2(555.0, 0.0)
@export var west_gate_position: Vector2 = Vector2(-555.0, 0.0)
@export var party_entry_offset: float = 410.0
@export_range(0.1, 3.0, 0.1) var transition_cooldown: float = 0.8

var biome_manager: BiomeManager
var active_biome: BiomeDefinition
var active_gates: Array[BiomeTransitionGate] = []
var is_active: bool = false
var cooldown_timer: float = 0.0

func _ready() -> void:
	add_to_group("biome_transition_system")

func _process(delta: float) -> void:
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)

func start_run(
	biome: BiomeDefinition,
	manager: BiomeManager = null
) -> void:
	biome_manager = manager if manager != null else _resolve_biome_manager()
	is_active = true
	configure_biome(biome)

func configure_biome(biome: BiomeDefinition) -> void:
	_clear_gates()
	active_biome = biome
	if not is_active or active_biome == null:
		return
	var color := (
		active_biome.palette.gate_color
		if active_biome.palette != null
		else Color(0.42, 0.90, 0.58, 1.0)
	)
	if not active_biome.next_biome_id.is_empty():
		_spawn_gate(
			active_biome.next_biome_id,
			&"east",
			east_gate_position,
			color
		)
	if not active_biome.previous_biome_id.is_empty():
		_spawn_gate(
			active_biome.previous_biome_id,
			&"west",
			west_gate_position,
			color
		)

func stop_run() -> void:
	_clear_gates()
	active_biome = null
	biome_manager = null
	is_active = false
	cooldown_timer = 0.0

func transition_to(
	target_biome_id: StringName,
	direction_id: StringName = &"east"
) -> bool:
	if not is_active or target_biome_id.is_empty():
		return false
	if cooldown_timer > 0.0:
		return false
	if biome_manager == null:
		biome_manager = _resolve_biome_manager()
	if biome_manager == null:
		return false
	var previous_id := biome_manager.get_current_biome_id()
	if not biome_manager.set_current_biome(target_biome_id):
		return false
	_move_party_to_entry(direction_id)
	cooldown_timer = transition_cooldown
	biome_transitioned.emit(previous_id, target_biome_id)
	return true

func get_active_gates() -> Array[BiomeTransitionGate]:
	_prune_gates()
	return active_gates.duplicate()

func _spawn_gate(
	target_biome_id: StringName,
	direction_id: StringName,
	gate_position: Vector2,
	color: Color
) -> void:
	var container := _get_environment_container()
	if container == null:
		return
	var gate := TRANSITION_GATE_SCRIPT.new() as BiomeTransitionGate
	if gate == null:
		return
	gate.name = "%sTransitionGate" % String(direction_id).capitalize()
	gate.configure(target_biome_id, direction_id, gate_position, color)
	container.add_child(gate)
	gate.body_entered.connect(_on_gate_body_entered.bind(gate))
	active_gates.append(gate)
	transition_gate_spawned.emit(gate, target_biome_id)

func _on_gate_body_entered(
	body: Node2D,
	gate: BiomeTransitionGate
) -> void:
	if (
		body.is_in_group("players")
		and gate != null
		and is_instance_valid(gate)
	):
		transition_to(gate.target_biome_id, gate.direction_id)

func _move_party_to_entry(direction_id: StringName) -> void:
	var entry_x := -party_entry_offset if direction_id == &"east" else party_entry_offset
	var players := get_tree().get_nodes_in_group("players")
	players.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get("player_slot")) < int(b.get("player_slot"))
	)
	for index in range(players.size()):
		var player := players[index] as Node2D
		if player == null:
			continue
		player.global_position = Vector2(
			entry_x,
			(float(index) - float(players.size() - 1) * 0.5) * 44.0
		)
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO

func _resolve_biome_manager() -> BiomeManager:
	return get_tree().get_first_node_in_group("biome_manager") as BiomeManager

func _get_environment_container() -> Node:
	var container := get_node_or_null(environment_container_path)
	return container if container != null else get_tree().current_scene

func _clear_gates() -> void:
	for gate in active_gates:
		if is_instance_valid(gate):
			gate.queue_free()
	active_gates.clear()

func _prune_gates() -> void:
	for gate in active_gates.duplicate():
		if not is_instance_valid(gate) or gate.is_queued_for_deletion():
			active_gates.erase(gate)
