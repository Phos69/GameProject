extends SettingsAwareVisual
class_name PatternBossVisual

# Stato e animazione condivisi dai visual dei boss a pattern (Rift Architect
# e Wave Warden): fase, mira, telegraph e timer hurt/spawn erano duplicati
# identici nei due file (gruppo 4.5 del report repo health). Le sottoclassi
# forniscono colori, get_profile_id e _draw.

var phase_index: int = 1
var aim_direction: Vector2 = Vector2.DOWN
var active_pattern: StringName = &""
var hurt_timer: float = 0.0
var spawn_timer: float = 0.0

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	hurt_timer = maxf(hurt_timer - delta, 0.0)
	spawn_timer = maxf(spawn_timer - delta, 0.0)
	queue_redraw()

func set_facing(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		aim_direction = direction.normalized()

func set_phase(value: int) -> void:
	phase_index = maxi(value, 1)
	queue_redraw()

func set_attack_charge(pattern_id: StringName) -> void:
	active_pattern = pattern_id
	queue_redraw()

func clear_attack_charge() -> void:
	active_pattern = &""
	queue_redraw()

func play_hurt() -> void:
	hurt_timer = 0.14
	queue_redraw()

func play_spawn() -> void:
	spawn_timer = 0.65
	queue_redraw()

func is_phase_two_visual() -> bool:
	return phase_index >= 2
