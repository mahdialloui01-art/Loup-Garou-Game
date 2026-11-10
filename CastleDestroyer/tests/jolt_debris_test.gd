extends SceneTree

const GameScript = preload("res://scripts/game.gd")

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var game = GameScript.new()
	root.add_child(game)
	await process_frame
	if game.physics_root == null:
		push_error("Game did not create its 3D physics root")
		quit(1)
		return

	var source_body := StaticBody3D.new()
	game.physics_root.add_child(source_body)
	var block := {
		"rect": Rect2(300.0, 400.0, 24.0, 24.0),
		"team": "player",
		"body": source_body
	}
	game.call("_spawn_falling_block", block, Vector2(312.0, 412.0), Vector2(12.0, -8.0))
	if game.falling_blocks.size() != 4:
		push_error("Expected a destroyed block to produce four physical shards")
		quit(1)
		return

	for shard in game.falling_blocks:
		if not shard is RigidBody3D:
			push_error("A fractured shard is not a RigidBody3D")
			quit(1)
			return
		if not shard.axis_lock_linear_z or not shard.axis_lock_angular_x or not shard.axis_lock_angular_y:
			push_error("A shard is not constrained to the 2D battle plane")
			quit(1)
			return

	game.call("_on_debris_impact", Vector3(3.0, -4.0, 0.0), 4.0)
	if game.particles.is_empty():
		push_error("Debris impact did not create visual particles")
		quit(1)
		return

	await physics_frame
	print("Jolt debris simulation tests passed.")
	game.queue_free()
	quit(0)
