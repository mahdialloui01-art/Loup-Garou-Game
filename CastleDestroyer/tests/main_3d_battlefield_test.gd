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
	print("Main 3D battlefield integration tests passed.")
	game.queue_free()
	quit(0)
