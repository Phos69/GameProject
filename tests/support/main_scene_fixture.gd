extends RefCounted
## Fixture condivisa per le suite GUT che devono bootare `main.tscn` per intero.
##
## Pensata per `before_all()`: la scena principale viene istanziata UNA volta e
## riusata da tutti i `test_*` della suite, eliminando il cold-start ripetuto che
## i vecchi test `extends SceneTree` pagavano (un boot per file). I singoli test
## (ri)avviano survival via `start_survival()` per isolare lo stato del mondo.
##
## Uso tipico:
##   const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")
##   var _scene: MainSceneFixture
##   func before_all():
##       _scene = MainSceneFixture.new()
##       assert_true(_scene.boot(self))
##       await wait_frames(3)
##   func after_each():
##       _scene.stop_survival()
##   func after_all():
##       _scene.teardown()
##
## NB: `set_mode(SURVIVAL)` ricostruisce il mondo solo se la modalita NON e gia in
## esecuzione (vedi GameModeManager.set_mode). Per questo i test devono fermare
## survival in `after_each` prima che il test successivo la riavvii.

const MAIN_SCENE_PATH := "res://game/main/main.tscn"

var main: Node
var _host: Node
var _previous_current_scene: Node

## Istanzia `main.tscn` come figlio di `host` (di norma il nodo GutTest). Dopo la
## chiamata attendere alcuni frame (`await wait_frames(...)`) prima di leggere i
## system node o avviare survival.
##
## La scena viene agganciata alla root (non al nodo GutTest) e impostata come
## `current_scene`: lo streaming regioni risolve i container `World/EnvironmentProps`
## / `World/Pickups` via `get_tree().current_scene`, e il setter accetta solo un
## figlio diretto della root (come facevano i vecchi test `extends SceneTree`).
func boot(host: Node) -> bool:
	_host = host
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	main = packed.instantiate()
	var tree := host.get_tree()
	tree.root.add_child(main)
	_previous_current_scene = tree.current_scene
	tree.current_scene = main
	return true

## Primo nodo registrato nel gruppo indicato (mirror di get_first_node_in_group).
func node(group: StringName) -> Node:
	return _host.get_tree().get_first_node_in_group(group)

## Tutti i nodi del gruppo indicato.
func nodes(group: StringName) -> Array:
	return _host.get_tree().get_nodes_in_group(group)

func game_mode_manager() -> GameModeManager:
	return node(&"game_mode_manager") as GameModeManager

func survival_mode() -> SurvivalMode:
	return node(&"survival_mode") as SurvivalMode

## Avvia (o riavvia) la modalita survival con il contesto dato. Disattiva sempre
## lo spawn delle ondate spostando in avanti l'initial_delay del wave manager,
## cosi i test lavorano su un mondo stabile senza nemici random.
func start_survival(context: Dictionary = {}) -> bool:
	var gmm := game_mode_manager()
	if gmm == null:
		return false
	var wave_manager := node(&"wave_manager") as WaveManager
	if wave_manager != null:
		wave_manager.initial_delay = 100.0
	return gmm.set_mode(GameConstants.MODE_SURVIVAL, context)

## Ferma survival senza distruggere la scena: necessario in after_each perche il
## prossimo start_survival ricostruisca davvero il mondo invece di no-oppare.
func stop_survival() -> void:
	var survival := survival_mode()
	if survival != null and bool(survival.get("is_running")):
		survival.stop_mode()

func teardown() -> void:
	if _host != null and is_instance_valid(_host):
		var tree := _host.get_tree()
		if tree != null and tree.current_scene == main:
			# Evita un riferimento penzolante a main dopo la free; la root non
			# accetta come current_scene un nodo non suo figlio diretto, quindi
			# si azzera invece di ripristinare il precedente (che era null).
			tree.current_scene = null
	if main != null and is_instance_valid(main):
		var parent := main.get_parent()
		if parent != null:
			parent.remove_child(main)
		main.free()
	main = null
	_host = null
	_previous_current_scene = null
