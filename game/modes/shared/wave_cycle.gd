extends RefCounted
class_name WaveCycle

## Helper condivisi tra le macchine a stati wave (WaveManager e
## TowerDefenseWaveController) per i pezzi realmente identici. I due
## controller restano separati per stati, spawn, reward e dipendenze:
## qui vivono solo le poche utility che erano copiate uguali.

const STATE_INTERMISSION := 1
const STATE_SPAWNING := 2
const STATE_COMBAT := 3

## Avanza il tratto comune delle macchine a stati wave. I controller mantengono
## stati terminali, spawn e reward distinti; le callback conservano tali
## responsabilita senza duplicare il dispatch eseguito ogni frame.
static func process_state(
	run_active: bool,
	state: int,
	state_timer: float,
	delta: float,
	start_next_wave: Callable,
	process_spawning: Callable,
	check_wave_completion: Callable
) -> float:
	if not run_active:
		return state_timer
	match state:
		STATE_INTERMISSION:
			state_timer = maxf(state_timer - delta, 0.0)
			if state_timer <= 0.0:
				start_next_wave.call()
		STATE_SPAWNING:
			process_spawning.call(delta)
		STATE_COMBAT:
			check_wave_completion.call()
	return state_timer

## True se la wave e una boss wave per l'intervallo dato.
static func should_spawn_boss(wave_index: int, boss_wave_interval: int) -> bool:
	return (
		boss_wave_interval > 0
		and wave_index > 0
		and wave_index % boss_wave_interval == 0
	)

## Mantiene la stessa progressione dei minion in tutte le wave. Il boss viene
## contato separatamente dai controller e non sostituisce parte della curva.
static func get_regular_enemy_count(
	wave_index: int,
	base_enemy_count: int,
	enemy_count_growth: int
) -> int:
	var wave_offset := maxi(wave_index - 1, 0)
	return maxi(base_enemy_count + wave_offset * enemy_count_growth, 0)

## Rimuove in place dall'array i nodi non validi o in coda di cancellazione.
## Itera per indice e usa is_instance_valid sull'accesso indicizzato: cosi non
## lega mai un'istanza gia liberata a una variabile tipizzata Node.
static func prune_nodes(nodes: Array[Node]) -> void:
	var index := nodes.size() - 1
	while index >= 0:
		if not is_instance_valid(nodes[index]) or nodes[index].is_queued_for_deletion():
			nodes.remove_at(index)
		index -= 1

## Ritorna il nodo se ancora valido e non in cancellazione, altrimenti null.
## Il parametro e Variant e il controllo parte da is_instance_valid: un'istanza
## liberata non e null ma non deve mai essere restituita (errore runtime).
static func prune_node(node: Variant) -> Node:
	if not is_instance_valid(node):
		return null
	if node.is_queued_for_deletion():
		return null
	return node
