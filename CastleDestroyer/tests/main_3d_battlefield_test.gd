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
	if game.main_menu == null or not game.main_menu.visible or game.game_started:
		push_error("Game must launch on a separate visible main menu before battle")
		quit(1)
		return
	for hud_item in game.game_hud:
		if hud_item.visible:
			push_error("Battle HUD must be hidden while the main menu is active")
			quit(1)
			return
	if game.battlefield_viewport.size.x <= 0 or game.battlefield_viewport.size.y <= 0:
		push_error("Full-screen battlefield viewport has invalid dimensions")
		quit(1)
		return
	if game.battlefield_viewport.get_camera_3d() == null:
		push_error("Main 3D battlefield has no active camera")
		quit(1)
		return
	var tactical_camera: Camera3D = game.battlefield_viewport.get_camera_3d()
	if tactical_camera.projection != Camera3D.PROJECTION_ORTHOGONAL or tactical_camera.position.y < 4.0 or tactical_camera.size < 8.0:
		push_error("Main battlefield camera is not using the elevated tactical overview framing")
		quit(1)
		return
	if game.battlefield_viewport.get_texture() == null:
		push_error("Main 3D battlefield has no render texture")
		quit(1)
		return
	game._start_game()
	await process_frame
	if not game.game_started or game.main_menu.visible:
		push_error("Start button flow did not enter the battle screen")
		quit(1)
		return
	for hud_item in game.game_hud:
		if not hud_item.visible:
			push_error("Battle HUD must be visible after pressing Start")
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
