extends RefCounted
class_name WaveCycle

## Helper condivisi tra le macchine a stati wave (WaveManager e
## TowerDefenseWaveController) per i pezzi realmente identici. I due
## controller restano separati per stati, spawn, reward e dipendenze:
## qui vivono solo le poche utility che erano copiate uguali.

## True se la wave e una boss wave per l'intervallo dato.
static func should_spawn_boss(wave_index: int, boss_wave_interval: int) -> bool:
	return (
		boss_wave_interval > 0
		and wave_index > 0
		and wave_index % boss_wave_interval == 0
	)

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
