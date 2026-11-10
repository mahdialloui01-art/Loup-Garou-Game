extends SceneTree

const StructuralIntegrityGraph = preload("res://addons/castle_destruction/structural_integrity_graph.gd")

func _initialize() -> void:
	var blocks: Array = [
		{"team": "player", "rect": Rect2(0.0, 90.0, 20.0, 10.0)},
		{"team": "player", "rect": Rect2(0.0, 80.0, 20.0, 10.0)},
		{"team": "player", "rect": Rect2(80.0, 50.0, 20.0, 10.0)}
	]
	var unsupported: Array[int] = StructuralIntegrityGraph.find_unsupported(blocks, "player", 100.0)
	if unsupported != [2]:
		push_error("Expected only the floating block to be unsupported, got: %s" % [unsupported])
		quit(1)
		return

	blocks.remove_at(0)
	var collapsed: Array[int] = StructuralIntegrityGraph.find_unsupported(blocks, "player", 100.0)
	if collapsed.size() != 2:
		push_error("Expected both blocks to lose support after removing the base, got: %s" % [collapsed])
		quit(1)
		return

	print("Structural integrity graph tests passed.")
	quit(0)
