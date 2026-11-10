extends SceneTree

const GameScript = preload("res://scripts/game.gd")

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var game = GameScript.new()
	root.add_child(game)
	await process_frame
	if game.battlefield_viewport == null:
		push_error("Main game did not create its 3D battlefield viewport")
		quit(1)
		return
	if game.battlefield_viewport.get_camera_3d() == null:
		push_error("Main 3D battlefield has no active camera")
		quit(1)
		return
	if game.battlefield_viewport.get_texture() == null:
		push_error("Main 3D battlefield has no render texture")
		quit(1)
		return
	if game.blocks.size() < 50:
		push_error("Main game castle block logic was not initialized")
		quit(1)
		return
	var mesh_count := 0
	for block in game.blocks:
		var body: StaticBody3D = block.get("body")
		if body == null or body.get_node_or_null("DestructibleStoneMesh") == null:
			push_error("A live castle block has no visible 3D mesh")
			quit(1)
			return
		mesh_count += 1
	if mesh_count < 50:
		push_error("Expected at least 50 rendered 3D destructible castle blocks")
		quit(1)
		return
	var world := game.battlefield_viewport.get_child(0) as Node3D
	if world == null or world.find_child("MainBattlefieldCamera", true, false) == null:
		push_error("Main 3D battlefield world/camera is missing")
		quit(1)
		return
	for block in game.blocks:
		var body: StaticBody3D = block.get("body")
		if body.get_viewport() != game.battlefield_viewport:
			push_error("Destructible 3D castle body is outside the battlefield SubViewport")
			quit(1)
			return
	print("Main 3D destructible castle integration tests passed: %d live 3D blocks." % mesh_count)
	game.queue_free()
	quit(0)
