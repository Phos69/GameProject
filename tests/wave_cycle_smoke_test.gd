extends SceneTree

## Test unitario degli helper condivisi WaveCycle (Fase 2 roadmap tecnica).

var failures: PackedStringArray = []

func _initialize() -> void:
	# should_spawn_boss: ogni N wave, mai a wave 0, mai con intervallo <= 0.
	_expect(WaveCycle.should_spawn_boss(5, 5), "wave 5 con intervallo 5 e boss")
	_expect(WaveCycle.should_spawn_boss(10, 5), "wave 10 con intervallo 5 e boss")
	_expect(not WaveCycle.should_spawn_boss(4, 5), "wave 4 non e boss")
	_expect(not WaveCycle.should_spawn_boss(0, 5), "wave 0 non e mai boss")
	_expect(not WaveCycle.should_spawn_boss(5, 0), "intervallo 0 disabilita i boss")

	# prune_node: valido -> se stesso, null -> null, liberato -> null.
	var alive_node := Node.new()
	root.add_child(alive_node)
	_expect(WaveCycle.prune_node(alive_node) == alive_node, "nodo vivo sopravvive al prune")
	_expect(WaveCycle.prune_node(null) == null, "null resta null")
	var freed_node := Node.new()
	freed_node.free()
	_expect(WaveCycle.prune_node(freed_node) == null, "nodo liberato -> null")

	# prune_nodes: rimuove i nodi liberati MENTRE sono nell'array (scenario reale),
	# conserva i vivi, mutando in place.
	var keep := Node.new()
	root.add_child(keep)
	var drop := Node.new()
	root.add_child(drop)
	var nodes: Array[Node] = [keep, drop]
	drop.free()
	WaveCycle.prune_nodes(nodes)
	_expect(nodes.size() == 1 and nodes[0] == keep, "prune_nodes tiene solo i validi")

	alive_node.free()
	keep.free()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: %s" % message)

func _finish() -> void:
	if failures.is_empty():
		print("wave_cycle_smoke_test passed")
		quit(0)
	else:
		push_error("wave_cycle_smoke_test FAILED (%d)" % failures.size())
		quit(1)
