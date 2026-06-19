extends RefCounted
class_name PlayerQuery

## Helper condiviso per le query ricorrenti sui player locali.
##
## Centralizza il pattern duplicato in 20+ sistemi: iterare il gruppo
## `players`, leggere il loro `HealthComponent` e filtrare per stato vivo/downed
## o trovare il piu vicino. Funzioni statiche, nessun nodo o autoload: i
## chiamanti passano la `SceneTree` corrente.
##
## Semantica vivo: un player e considerato "vivo" solo se possiede un
## `HealthComponent` e `HealthComponent.is_alive()` e vero. Un player nel gruppo
## senza `HealthComponent` (caso anomalo: i player reali lo hanno sempre) e
## trattato come non vivo.

const PLAYERS_GROUP: StringName = &"players"
const HEALTH_COMPONENT_NODE: String = "HealthComponent"

## Tutti i nodi nel gruppo `players` (vivi e non).
static func all(tree: SceneTree) -> Array[Node]:
	if tree == null:
		return []
	return tree.get_nodes_in_group(PLAYERS_GROUP)

## Il `HealthComponent` figlio del player, o null se assente.
static func health_component(player: Node) -> HealthComponent:
	if player == null:
		return null
	return player.get_node_or_null(HEALTH_COMPONENT_NODE) as HealthComponent

static func is_alive(player: Node) -> bool:
	var health := health_component(player)
	return health != null and health.is_alive()

static func is_downed(player: Node) -> bool:
	var health := health_component(player)
	return health != null and health.is_downed

static func is_incapacitated(player: Node) -> bool:
	var health := health_component(player)
	return health != null and health.is_incapacitated()

## True se almeno un player e vivo (short-circuit, senza allocare un array).
static func any_alive(tree: SceneTree) -> bool:
	for player in all(tree):
		if is_alive(player):
			return true
	return false

## Player vivi (HealthComponent.is_alive()).
static func alive(tree: SceneTree) -> Array[Node]:
	var result: Array[Node] = []
	for player in all(tree):
		if is_alive(player):
			result.append(player)
	return result

## Player a terra (downed) in attesa di rianimazione.
static func downed(tree: SceneTree) -> Array[Node]:
	var result: Array[Node] = []
	for player in all(tree):
		if is_downed(player):
			result.append(player)
	return result

## Il player `Node2D` piu vicino a `position`; per default solo tra i vivi.
## Ritorna null se nessun candidato e disponibile.
static func nearest(
	tree: SceneTree, position: Vector2, alive_only: bool = true
) -> Node2D:
	var best: Node2D = null
	var best_distance_squared := INF
	for player in all(tree):
		var node2d := player as Node2D
		if node2d == null:
			continue
		if alive_only and not is_alive(player):
			continue
		var distance_squared := position.distance_squared_to(node2d.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best = node2d
	return best

## Distanza al quadrato dal player piu vicino, o INF se nessuno.
static func nearest_distance_squared(
	tree: SceneTree, position: Vector2, alive_only: bool = true
) -> float:
	var nearest_node := nearest(tree, position, alive_only)
	if nearest_node == null:
		return INF
	return position.distance_squared_to(nearest_node.global_position)

## Il player con `player_slot` corrispondente, o null.
static func by_slot(tree: SceneTree, player_slot: int) -> Node:
	for player in all(tree):
		if "player_slot" in player and player.player_slot == player_slot:
			return player
	return null
