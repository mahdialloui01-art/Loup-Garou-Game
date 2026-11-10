extends Control

const StructuralIntegrityGraph = preload("res://addons/castle_destruction/structural_integrity_graph.gd")

class FallingFortBlock extends RigidBody3D:
	signal impact(position: Vector3, strength: float)

	var block_size := Vector2(11.0, 12.0)
	var block_color := Color("#c68a4c")
	var impact_cooldown := 0.0

	func _ready() -> void:
		var shape := BoxShape3D.new()
		shape.size = Vector3(maxf(block_size.x * 0.01, 0.02), maxf(block_size.y * 0.01, 0.02), 0.12)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		add_child(collision)
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		var surface := StandardMaterial3D.new()
		surface.albedo_color = block_color
		mesh.material = surface
		mesh_instance.mesh = mesh
		add_child(mesh_instance)
		var material := PhysicsMaterial.new()
		material.friction = 0.82
		material.bounce = 0.12
		physics_material_override = material
		axis_lock_linear_z = true
		axis_lock_angular_x = true
		axis_lock_angular_y = true
		linear_damp = 0.18
		angular_damp = 0.35
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		impact_cooldown = maxf(0.0, impact_cooldown - delta)

	func _on_body_entered(_other: Node) -> void:
		var impact_speed := linear_velocity.length()
		if impact_cooldown <= 0.0 and impact_speed >= 2.0:
			impact.emit(global_position, impact_speed)
			impact_cooldown = 0.2

# Castle Destroyer - 3D destructible fort gameplay.
# Kenney CC0 models are used for the environment and fort details.

const FLOOR_Y := 555.0
const PLAYER_CANNON := Vector2(205.0, 505.0)
const ENEMY_CANNON := Vector2(1075.0, 505.0)
const SAVE_PATH := "user://castle_destroyer.cfg"
const WEAPONS := [
	{"id": "stone", "name": "STONE", "damage": 1, "radius": 8.0, "speed": 18.0, "splash": 0.0, "cost": 0},
	{"id": "bomb", "name": "MEGA BOMB", "damage": 4, "radius": 13.0, "speed": 15.5, "splash": 48.0, "cost": 0},
	{"id": "fire", "name": "FIRE ORB", "damage": 2, "radius": 11.0, "speed": 16.5, "splash": 30.0, "cost": 0}
]

var blocks: Array = []
var falling_blocks: Array = []
var physics_root: Node3D
var battlefield_viewport: SubViewport
var main_camera: Camera3D
var sun_light: DirectionalLight3D
var animated_flags: Array[Node3D] = []
var camera_mode := 0
var battlefield_time := 0.0
var floor_body: StaticBody3D
var projectiles: Array = []
var particles: Array = []
var score := 0
var gold := 0
var level := 1
var best_level := 1
var cannon_level := 1
var wall_level := 1
var ammo: Dictionary = {"stone": 999, "bomb": 12, "fire": 8}
var weapon_index := 0
var elapsed := 0.0
var enemy_cooldown := 2.5
var player_max_health := 1
var enemy_max_health := 1
var game_over := false
var paused := false
var reward_claimed := false
var aiming := false
var aim_origin := Vector2.ZERO
var aim_point := Vector2.ZERO
var message := "DRAG FROM YOUR CANNON TO AIM"
var score_label: Label
var status_label: Label
var player_label: Label
var enemy_label: Label
var level_label: Label
var gold_label: Label
var weapon_button: Button
var fire_button: Button
var upgrade_button: Button
var next_button: Button
var camera_test_button: Button

func _ready() -> void:
	randomize()
	_load_progress()
	_build_3d_battlefield()
	physics_root = Node3D.new()
	physics_root.name = "FortPhysics"
	var battlefield_world := battlefield_viewport.get_child(0) as Node3D
	battlefield_world.add_child(physics_root)
	_create_physics_floor()
	_build_ui()
	_new_game()
	set_process(true)


func _build_3d_battlefield() -> void:
	# The battlefield and destructible castle geometry are rendered in 3D.
	# The current hit-testing and structural graph remain authoritative.
	battlefield_viewport = SubViewport.new()
	battlefield_viewport.name = "Battlefield3DViewport"
	battlefield_viewport.size = Vector2i(1280, 720)
	battlefield_viewport.disable_3d = false
	battlefield_viewport.transparent_bg = false
	battlefield_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(battlefield_viewport)

	var world := Node3D.new()
	world.name = "Battlefield3D"
	battlefield_viewport.add_child(world)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4b86b9")
	sky_material.sky_horizon_color = Color("#d5e5ed")
	sky_material.ground_bottom_color = Color("#344b39")
	sky_material.ground_horizon_color = Color("#8b9b83")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c4d4df")
	environment.ambient_light_energy = 0.75
	environment_node.environment = environment
	world.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)
	sun_light = sun

	var ground := MeshInstance3D.new()
	ground.name = "SideViewGround"
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(16.0, 0.18, 1.2)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#719454")
	ground_material.roughness = 1.0
	ground_mesh.material = ground_material
	ground.mesh = ground_mesh
	ground.position = Vector3(6.4, -(FLOOR_Y + 8.0) * 0.01, 0.0)
	world.add_child(ground)
	_build_terrain_detail(world)

	_add_battlefield_prop(world, "models/siege-catapult.glb", Vector3(6.4, -5.45, -0.7), Vector3(0.55, 0.55, 0.55), 180.0)
	_add_battlefield_prop(world, "models/avramania-boulder.glb", Vector3(0.45, -5.46, -1.2), Vector3(0.75, 0.75, 0.75))
	_add_battlefield_prop(world, "models/avramania-boulder.glb", Vector3(12.25, -5.46, -1.1), Vector3(0.9, 0.9, 0.9))
	for tree_position in [
		Vector3(-0.25, -5.45, -0.9), Vector3(12.9, -5.45, -0.9)
	]:
		_add_battlefield_prop(world, "models/tree-large.glb", tree_position, Vector3(0.55, 0.55, 0.55))
	_add_battlefield_castle_details(90.0, "player")
	_add_battlefield_castle_details(1010.0, "enemy")

	var camera := Camera3D.new()
	camera.name = "MainBattlefieldCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.2
	camera.position = Vector3(6.4, -3.6, 18.0)
	camera.look_at(Vector3(6.4, -3.6, 0.0), Vector3.UP)
	camera.current = true
	world.add_child(camera)
	main_camera = camera
	_add_3d_cannon(world, Vector3(2.05, -5.05, 0.28), Color("#c28a45"), false)
	_add_3d_cannon(world, Vector3(10.75, -5.05, 0.28), Color("#657b9b"), true)
	_add_3d_soldiers(world, Vector3(0.72, -5.42, 0.24), Color("#2563a6"))
	_add_3d_soldiers(world, Vector3(11.55, -5.42, 0.24), Color("#b91c1c"))

func _add_battlefield_castle_details(origin_x: float, team: String) -> void:
	# Kenney tower, roof and flag models frame the live destructible 3D wall.
	var tint := Vector3.ONE
	var left_x := origin_x * 0.01 - 0.08
	var right_x := (origin_x + 5.0 * 24.0) * 0.01 + 0.08
	var base_y := -(FLOOR_Y + 8.0) * 0.01 + 0.12
	var world := battlefield_viewport.get_child(0) as Node3D
	if world == null:
		return
	for tower_x in [left_x, right_x]:
		_add_battlefield_prop(world, "models/tower-square.glb", Vector3(tower_x, base_y + 0.32, 0.16), Vector3(0.34, 0.42, 0.34))
		_add_battlefield_prop(world, "models/tower-square-roof.glb", Vector3(tower_x, base_y + 0.68, 0.16), Vector3(0.34, 0.26, 0.34))
		_add_battlefield_prop(world, "models/flag.glb", Vector3(tower_x, base_y + 1.03, 0.16), Vector3(0.3, 0.3, 0.3))
	var wall_mid := (left_x + right_x) * 0.5
	for wall_index in range(3):
		var wall_x := wall_mid + (float(wall_index) - 1.0) * 0.52
		_add_battlefield_prop(world, "models/retro/wall-fortified.glb", Vector3(wall_x, base_y + 0.02, 0.13), Vector3(0.54, 0.54, 0.54))
	_add_battlefield_prop(world, "models/retro/battlement.glb", Vector3(wall_mid, base_y + 0.55, 0.13), Vector3(0.52, 0.52, 0.52))
func _build_terrain_detail(world: Node3D) -> void:
	var terrain := MeshInstance3D.new()
	terrain.name = "GrassAndGravelTerrain"
	var terrain_mesh := PlaneMesh.new()
	terrain_mesh.size = Vector2(16.0, 5.2)
	terrain.mesh = terrain_mesh
	terrain.position = Vector3(6.4, -(FLOOR_Y + 8.0) * 0.01 + 0.095, 0.0)
	var terrain_shader := Shader.new()
	terrain_shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
void fragment() {
	vec2 cell = floor(UV * vec2(180.0, 58.0));
	float grain = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float broad = sin(UV.x * 31.0) * cos(UV.y * 19.0);
	vec3 grass_a = vec3(0.19, 0.31, 0.12);
	vec3 grass_b = vec3(0.31, 0.40, 0.17);
	vec3 gravel = vec3(0.39, 0.36, 0.28);
	vec3 base = mix(grass_a, grass_b, clamp(0.42 + broad * 0.16 + grain * 0.16, 0.0, 1.0));
	if (grain > 0.965) { base = mix(base, gravel, 0.72); }
	ALBEDO = base;
	ROUGHNESS = 1.0;
}
"""
	var terrain_material := ShaderMaterial.new()
	terrain_material.shader = terrain_shader
	terrain.material_override = terrain_material
	world.add_child(terrain)

	var grass_mesh := BoxMesh.new()
	grass_mesh.size = Vector3(0.014, 0.12, 0.014)
	var grass_shader := Shader.new()
	grass_shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 blade_color : source_color = vec4(0.30, 0.48, 0.17, 1.0);
void vertex() {
	float height_factor = clamp((VERTEX.y + 0.06) / 0.12, 0.0, 1.0);
	VERTEX.x += sin(TIME * 2.0 + VERTEX.x * 9.0 + UV.x * 2.0) * 0.025 * height_factor;
}
void fragment() {
	ALBEDO = blade_color.rgb * (0.88 + UV.y * 0.18);
	ROUGHNESS = 1.0;
}
"""
	var grass_material := ShaderMaterial.new()
	grass_material.shader = grass_shader
	grass_mesh.material = grass_material
	var grass_multi := MultiMesh.new()
	grass_multi.transform_format = MultiMesh.TRANSFORM_3D
	grass_multi.mesh = grass_mesh
	grass_multi.instance_count = 620
	for i in range(grass_multi.instance_count):
		var x := randf_range(0.05, 12.75)
		var z := randf_range(-2.45, 2.45)
		var blade_height := randf_range(0.65, 1.35)
		var blade_basis := Basis().scaled(Vector3(1.0, blade_height, 1.0)).rotated(Vector3.UP, randf_range(-PI, PI))
		grass_multi.set_instance_transform(i, Transform3D(blade_basis, Vector3(x, terrain.position.y + 0.06 * blade_height, z)))
	var grass_instance := MultiMeshInstance3D.new()
	grass_instance.name = "WindAnimatedGrass"
	grass_instance.multimesh = grass_multi
	world.add_child(grass_instance)

	var pebble_mesh := SphereMesh.new()
	pebble_mesh.radius = 0.035
	pebble_mesh.height = 0.025
	var pebble_material := StandardMaterial3D.new()
	pebble_material.albedo_color = Color("#8d8877")
	pebble_material.roughness = 1.0
	pebble_mesh.material = pebble_material
	var pebbles := MultiMesh.new()
	pebbles.transform_format = MultiMesh.TRANSFORM_3D
	pebbles.mesh = pebble_mesh
	pebbles.instance_count = 95
	for i in range(pebbles.instance_count):
		var pebble_position := Vector3(randf_range(0.0, 12.8), terrain.position.y + 0.012, randf_range(-2.3, 2.3))
		var pebble_scale := Vector3(randf_range(0.7, 1.8), randf_range(0.55, 1.0), randf_range(0.7, 1.5))
		pebbles.set_instance_transform(i, Transform3D(Basis().scaled(pebble_scale), pebble_position))
	var pebble_instance := MultiMeshInstance3D.new()
	pebble_instance.name = "ScatteredGravel"
	pebble_instance.multimesh = pebbles
	world.add_child(pebble_instance)


func _add_battlefield_prop(parent: Node3D, relative_path: String, pos: Vector3, scale_value := Vector3.ONE, yaw_degrees := 0.0) -> void:
	var resource_path := "res://assets/vendor/kenney-runtime/" + relative_path
	var packed := load(resource_path) as PackedScene
	if packed == null:
		push_warning("3D battlefield asset missing: " + resource_path)
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_warning("3D battlefield asset is not a Node3D scene: " + resource_path)
		return
	instance.position = pos
	instance.scale = scale_value
	instance.rotation.y = deg_to_rad(yaw_degrees)
	parent.add_child(instance)
	if relative_path == "models/flag.glb":
		animated_flags.append(instance)

func _add_3d_cannon(parent: Node3D, pos: Vector3, tint: Color, mirrored: bool) -> void:
	var cannon := Node3D.new()
	cannon.name = "3DCannon"
	cannon.position = pos
	parent.add_child(cannon)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.24
	base_mesh.bottom_radius = 0.3
	base_mesh.height = 0.22
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = tint.darkened(0.28)
	base_mat.roughness = 0.78
	base_mesh.material = base_mat
	base.mesh = base_mesh
	cannon.add_child(base)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.075
	barrel_mesh.bottom_radius = 0.13
	barrel_mesh.height = 0.82
	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = tint
	barrel_mat.metallic = 0.18
	barrel_mat.roughness = 0.5
	barrel_mesh.material = barrel_mat
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0.0, -0.16, 0.0)
	barrel.rotation.z = deg_to_rad(55.0 if not mirrored else -55.0)
	cannon.add_child(barrel)
	for side in [-1.0, 1.0]:
		var wheel := MeshInstance3D.new()
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.16
		wheel_mesh.bottom_radius = 0.16
		wheel_mesh.height = 0.09
		var wheel_mat := StandardMaterial3D.new()
		wheel_mat.albedo_color = Color("#493b30")
		wheel_mesh.material = wheel_mat
		wheel.mesh = wheel_mesh
		wheel.position = Vector3(side * 0.23, 0.0, 0.0)
		wheel.rotation.x = PI * 0.5
		cannon.add_child(wheel)

func _add_3d_soldiers(parent: Node3D, start: Vector3, tint: Color) -> void:
	for i in range(3):
		var soldier := Node3D.new()
		soldier.position = start + Vector3(float(i) * 0.2, 0.0, 0.0)
		parent.add_child(soldier)
		var torso := MeshInstance3D.new()
		var torso_mesh := CapsuleMesh.new()
		torso_mesh.radius = 0.065
		torso_mesh.height = 0.28
		var uniform := StandardMaterial3D.new()
		uniform.albedo_color = tint
		uniform.roughness = 0.88
		torso_mesh.material = uniform
		torso.mesh = torso_mesh
		torso.position.y = -0.13
		soldier.add_child(torso)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.055
		head_mesh.height = 0.11
		var skin := StandardMaterial3D.new()
		skin.albedo_color = Color("#e8bd91")
		head_mesh.material = skin
		head.mesh = head_mesh
		head.position.y = -0.31
		soldier.add_child(head)

func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_top = 12
	top.offset_right = -18
	top.offset_bottom = 56
	top.add_theme_constant_override("separation", 16)
	add_child(top)

	player_label = _make_label("YOUR FORT 100%", 18)
	top.add_child(player_label)
	var spacer_a := Control.new()
	spacer_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer_a)
	level_label = _make_label("LEVEL 1", 21)
	top.add_child(level_label)
	score_label = _make_label("SCORE 0", 18)
	top.add_child(score_label)
	gold_label = _make_label("GOLD 0", 18)
	top.add_child(gold_label)
	var spacer_b := Control.new()
	spacer_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer_b)
	enemy_label = _make_label("ENEMY FORT 100%", 18)
	top.add_child(enemy_label)

	status_label = _make_label(message, 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status_label.offset_left = -420
	status_label.offset_top = 65
	status_label.offset_right = 420
	status_label.offset_bottom = 102
	add_child(status_label)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 12
	controls.offset_top = -76
	controls.offset_right = -12
	controls.offset_bottom = -10
	add_child(controls)

	weapon_button = _make_button("WEAPON: STONE", Color("#334155"))
	weapon_button.pressed.connect(_cycle_weapon)
	controls.add_child(weapon_button)
	fire_button = _make_button("FIRE", Color("#2563a6"))
	fire_button.pressed.connect(_fire_selected)
	controls.add_child(fire_button)
	upgrade_button = _make_button("UPGRADE CANNON", Color("#a16207"))
	upgrade_button.pressed.connect(_upgrade_cannon)
	controls.add_child(upgrade_button)
	var wall_button := _make_button("FORTIFY WALL", Color("#854d0e"))
	wall_button.pressed.connect(_upgrade_walls)
	controls.add_child(wall_button)
	var pause_button := _make_button("PAUSE", Color("#475569"))
	pause_button.pressed.connect(_toggle_pause)
	controls.add_child(pause_button)
	next_button = _make_button("NEXT LEVEL", Color("#166534"))
	next_button.pressed.connect(_next_level)
	controls.add_child(next_button)
	camera_test_button = _make_button("CAMERA A TEST", Color("#475569"))
	camera_test_button.custom_minimum_size = Vector2(140.0, 54.0)
	camera_test_button.pressed.connect(_open_camera_test)
	controls.add_child(camera_test_button)

func _make_label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#172b3b"))
	label.add_theme_color_override("font_shadow_color", Color.WHITE)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _make_button(value: String, color: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(170, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(color))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.15)))
	return button

func _button_style(color: Color) -> StyleBox:
	var button_texture := load("res://assets/vendor/kenney-runtime/ui/button_rectangle_depth_flat.png") as Texture2D
	if button_texture != null:
		var textured := StyleBoxTexture.new()
		textured.texture = button_texture
		textured.modulate_color = color
		textured.texture_margin_left = 16.0
		textured.texture_margin_right = 16.0
		textured.texture_margin_top = 12.0
		textured.texture_margin_bottom = 12.0
		textured.content_margin_left = 10.0
		textured.content_margin_right = 10.0
		return textured
	var fallback := StyleBoxFlat.new()
	fallback.bg_color = color
	fallback.corner_radius_top_left = 11
	fallback.corner_radius_top_right = 11
	fallback.corner_radius_bottom_left = 11
	fallback.corner_radius_bottom_right = 11
	fallback.content_margin_left = 10
	fallback.content_margin_right = 10
	return fallback

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	gold = int(config.get_value("progress", "gold", 0))
	best_level = int(config.get_value("progress", "best_level", 1))
	cannon_level = int(config.get_value("upgrades", "cannon_level", 1))
	wall_level = int(config.get_value("upgrades", "wall_level", 1))
	level = clampi(best_level, 1, 20)

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "gold", gold)
	config.set_value("progress", "best_level", best_level)
	config.set_value("upgrades", "cannon_level", cannon_level)
	config.set_value("upgrades", "wall_level", wall_level)
	config.save(SAVE_PATH)

func _new_game() -> void:
	_clear_physics_castle()
	blocks.clear()
	projectiles.clear()
	particles.clear()
	score = 0
	elapsed = 0.0
	enemy_cooldown = 2.2
	game_over = false
	paused = false
	reward_claimed = false
	aiming = false
	message = "DRAG FROM YOUR CANNON TO AIM"
	ammo = {"stone": 999, "bomb": 12 + level, "fire": 8 + int(level / 2)}
	_add_castle(90.0, "player", wall_level)
	_add_castle(1010.0, "enemy", 1 + int((level - 1) / 3))
	player_max_health = _team_health("player")
	enemy_max_health = _team_health("enemy")
	next_button.disabled = true
	_update_hud()
	queue_redraw()

func _add_castle(origin_x: float, team: String, armor_level: int) -> void:
	var rows := 5 + (1 if team == "enemy" and level >= 5 else 0)
	for row in range(rows):
		for col in range(5):
			var max_hp := armor_level + (1 if row == rows - 1 else 0)
			var block_rect := Rect2(origin_x + float(col) * 24.0, FLOOR_Y - 25.0 - float(row) * 25.0, 23.0, 24.0)
			blocks.append(_make_block(block_rect, team, max_hp, max_hp, "stone"))
	# Main tower, battlements and flag mast.
	var tower_rect := Rect2(origin_x + 25.0, FLOOR_Y - 25.0 - float(rows) * 25.0, 72.0, 15.0)
	blocks.append(_make_block(tower_rect, team, armor_level + 2, armor_level + 2, "tower"))
	var mast_rect := Rect2(origin_x + 49.0, FLOOR_Y - 25.0 - float(rows) * 25.0 - 45.0, 22.0, 45.0)
	blocks.append(_make_block(mast_rect, team, armor_level + 1, armor_level + 1, "tower"))

func _create_physics_floor() -> void:
	floor_body = StaticBody3D.new()
	floor_body.name = "GroundCollider3D"
	floor_body.position = Vector3(6.4, -(FLOOR_Y + 8.0) * 0.01, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(15.0, 0.16, 1.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	physics_root.add_child(floor_body)

func _clear_physics_castle() -> void:
	for child in physics_root.get_children():
		if child != floor_body:
			child.free()
	falling_blocks.clear()

func _make_block(rect: Rect2, team: String, hp: int, max_hp: int, kind: String) -> Dictionary:
	var body := StaticBody3D.new()
	var center := rect.get_center()
	body.position = Vector3(center.x * 0.01, -center.y * 0.01, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(rect.size.x * 0.01, rect.size.y * 0.01, 0.12)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MortarBed"
	var mortar_mesh := BoxMesh.new()
	mortar_mesh.size = shape.size * Vector3(1.0, 1.0, 0.92)
	var mortar_material := StandardMaterial3D.new()
	mortar_material.albedo_color = Color("#51483d")
	mortar_material.roughness = 1.0
	mortar_mesh.material = mortar_material
	mesh_instance.mesh = mortar_mesh
	body.add_child(mesh_instance)

	var stone_base := Color("#c99a62") if team == "player" else Color("#71869f")
	var stone_tiles: Array[MeshInstance3D] = []
	for tile_y in range(2):
		for tile_x in range(2):
			var tile := MeshInstance3D.new()
			tile.name = "CarvedStoneFace"
			var tile_mesh := BoxMesh.new()
			tile_mesh.size = Vector3(maxf(0.025, shape.size.x * 0.475), maxf(0.025, shape.size.y * 0.475), 0.105)
			var tile_material := StandardMaterial3D.new()
			tile_material.albedo_color = stone_base.lightened(randf_range(-0.09, 0.07))
			tile_material.roughness = randf_range(0.82, 0.98)
			tile_material.metallic = 0.015
			tile_mesh.material = tile_material
			tile.mesh = tile_mesh
			tile.position = Vector3((float(tile_x) - 0.5) * shape.size.x * 0.5, (float(tile_y) - 0.5) * shape.size.y * 0.5, 0.025)
			body.add_child(tile)
			stone_tiles.append(tile)
	physics_root.add_child(body)
	return {"rect": rect, "team": team, "hp": hp, "max_hp": max_hp, "kind": kind, "body": body, "mesh": mesh_instance, "stone_tiles": stone_tiles}

func _update_block_visual(block: Dictionary) -> void:
	var mesh_instance: MeshInstance3D = block.get("mesh")
	if not is_instance_valid(mesh_instance):
		return
	var health_ratio := float(block["hp"]) / float(maxi(1, block["max_hp"]))
	var base := Color("#c99a62") if block["team"] == "player" else Color("#71869f")
	var damaged := base.darkened(0.32) if health_ratio < 0.5 else base
	var mortar_surface := StandardMaterial3D.new()
	mortar_surface.albedo_color = Color("#332f2a") if health_ratio < 0.5 else Color("#51483d")
	mortar_surface.roughness = 1.0
	var mortar_mesh := mesh_instance.mesh as BoxMesh
	if mortar_mesh != null:
		mortar_mesh.material = mortar_surface
	for tile in block.get("stone_tiles", []):
		if is_instance_valid(tile):
			var tile_surface := StandardMaterial3D.new()
			tile_surface.albedo_color = damaged.lightened(randf_range(-0.025, 0.025))
			tile_surface.roughness = 0.94
			tile.mesh.material = tile_surface

func _spawn_falling_block(block: Dictionary, impact: Vector2, incoming_velocity: Vector2):
	var rect: Rect2 = block["rect"]
	var base_color := Color("#c68a4c") if block["team"] == "player" else Color("#8994a6")
	# Mesh swap: replace one intact fort block with four pre-fractured 3D shards.
	var shard_size := rect.size * 0.5
	for shard_y in range(2):
		for shard_x in range(2):
			while falling_blocks.size() >= 70:
				var oldest: RigidBody3D = falling_blocks.pop_front()
				if is_instance_valid(oldest):
					oldest.queue_free()
			var body := FallingFortBlock.new()
			body.block_size = shard_size
			body.block_color = base_color
			body.mass = clampf(shard_size.x * shard_size.y / 1800.0, 0.08, 0.65)
			var shard_center := rect.position + Vector2((float(shard_x) + 0.5) * shard_size.x, (float(shard_y) + 0.5) * shard_size.y)
			body.position = Vector3(shard_center.x * 0.01, -shard_center.y * 0.01, 0.0)
			body.collision_layer = 1
			body.collision_mask = 1
			body.impact.connect(_on_debris_impact)
			var away := (shard_center - impact).normalized()
			if away.length_squared() < 0.01:
				away = Vector2.UP
			var inherited_velocity := Vector3(incoming_velocity.x * 0.072, -incoming_velocity.y * 0.072, 0.0)
			var burst_velocity := Vector3(away.x, -away.y, 0.0) * randf_range(1.2, 2.8)
			body.linear_velocity = inherited_velocity + burst_velocity + Vector3(randf_range(-0.6, 0.6), randf_range(-0.5, 0.5), randf_range(-0.8, 0.8))
			body.angular_velocity = Vector3(0.0, 0.0, randf_range(-2.8, 2.8))
			body.freeze = paused
			physics_root.add_child(body)
			falling_blocks.append(body)
	var old_body: StaticBody3D = block["body"]
	if is_instance_valid(old_body):
		old_body.queue_free()

func _collapse_unsupported_blocks(team: String, impact: Vector2, incoming_velocity: Vector2) -> void:
	# Re-evaluate the support graph after each collapse wave. Ground-connected
	# blocks remain stable; anything disconnected becomes physical debris.
	var passes := 0
	while passes < 12:
		passes += 1
		var unsupported: Array[int] = StructuralIntegrityGraph.find_unsupported(blocks, team, FLOOR_Y)
		if unsupported.is_empty():
			break
		unsupported.sort()
		for index in range(unsupported.size() - 1, -1, -1):
			var block_index: int = unsupported[index]
			if block_index < 0 or block_index >= blocks.size():
				continue
			var block: Dictionary = blocks[block_index]
			_spawn_falling_block(block, impact, incoming_velocity)
			blocks.remove_at(block_index)

func _cleanup_falling_blocks() -> void:
	for i in range(falling_blocks.size() - 1, -1, -1):
		var body: RigidBody3D = falling_blocks[i]
		if not is_instance_valid(body) or body.position.y < -9.0:
			if is_instance_valid(body):
				body.queue_free()
			falling_blocks.remove_at(i)

func _open_camera_test() -> void:
	# The camera test button cycles real camera rigs in the live 3D battle.
	camera_mode = (camera_mode + 1) % 3
	var labels := ["BATTLEFIELD OVERVIEW", "PLAYER FORT CLOSE-UP", "CINEMATIC SIEGE VIEW"]
	message = "CAMERA: " + labels[camera_mode]
	_update_hud()

func _cycle_weapon() -> void:
	weapon_index = (weapon_index + 1) % WEAPONS.size()
	_update_hud()

func _fire_selected() -> void:
	var weapon: Dictionary = WEAPONS[weapon_index]
	var weapon_id: String = weapon["id"]
	if game_over or paused:
		return
	if int(ammo.get(weapon_id, 0)) <= 0:
		message = "NO AMMO LEFT - SELECT ANOTHER WEAPON"
		_update_hud()
		return
	ammo[weapon_id] = int(ammo[weapon_id]) - 1
	var direction := Vector2(1.0, -0.72)
	if aiming:
		direction = (aim_point - PLAYER_CANNON).normalized()
	aiming = false
	if direction.x < 0.2:
		direction.x = 0.2
	direction.y = clampf(direction.y, -1.0, -0.08)
	direction = direction.normalized()
	var power := float(weapon["speed"]) * (1.0 + float(cannon_level - 1) * 0.045)
	projectiles.append({
		"pos": PLAYER_CANNON + Vector2(15.0, -12.0),
		"vel": direction * power,
		"power": int(weapon["damage"]),
		"team": "player",
		"radius": float(weapon["radius"]),
		"splash": float(weapon["splash"]),
		"kind": weapon_id
	})
	message = "%s FIRED!" % weapon["name"]
	_update_hud()

func _enemy_fire() -> void:
	if game_over:
		return
	var target_x := 180.0 + randf_range(-55.0, 55.0)
	var direction := (Vector2(target_x, 320.0) - ENEMY_CANNON).normalized()
	projectiles.append({
		"pos": ENEMY_CANNON + Vector2(-15.0, -12.0),
		"vel": direction * randf_range(14.0, 17.0),
		"power": 1 + int(level / 5),
		"team": "enemy",
		"radius": 8.0,
		"splash": 0.0,
		"kind": "enemy"
	})

func _upgrade_cannon() -> void:
	var cost := cannon_level * 80
	if cannon_level >= 10:
		message = "CANNON IS AT MAX LEVEL"
	elif gold < cost:
		message = "NEED %d MORE GOLD FOR CANNON UPGRADE" % (cost - gold)
	else:
		gold -= cost
		cannon_level += 1
		_save_progress()
		message = "CANNON UPGRADED TO LEVEL %d!" % cannon_level
	_update_hud()

func _upgrade_walls() -> void:
	var cost := wall_level * 100
	if wall_level >= 8:
		message = "FORT IS AT MAX LEVEL"
	elif gold < cost:
		message = "NEED %d MORE GOLD FOR FORTIFICATION" % (cost - gold)
	else:
		gold -= cost
		wall_level += 1
		for i in range(blocks.size()):
			var block: Dictionary = blocks[i]
			if block["team"] == "player":
				block["max_hp"] = int(block["max_hp"]) + 1
				block["hp"] = int(block["hp"]) + 1
				blocks[i] = block
		player_max_health += blocks.filter(func(block): return block["team"] == "player").size()
		_save_progress()
		message = "FORTIFIED! WALL ARMOR IS NOW LEVEL %d" % wall_level
	_update_hud()

func _next_level() -> void:
	if not game_over or _team_health("enemy") > 0:
		return
	level += 1
	best_level = maxi(best_level, level)
	_save_progress()
	_new_game()

func _toggle_pause() -> void:
	paused = not paused
	for body in falling_blocks:
		if is_instance_valid(body):
			body.freeze = paused
	message = "BATTLE PAUSED" if paused else "BATTLE RESUMED"
	_update_hud()

func _input(event: InputEvent) -> void:
	if game_over or paused:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_aim(touch.position)
		else:
			_end_aim(touch.position)
	elif event is InputEventScreenDrag and aiming:
		aim_point = (event as InputEventScreenDrag).position
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_aim(event.position)
		else:
			_end_aim(event.position)
	elif event is InputEventMouseMotion and aiming and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		aim_point = event.position
		queue_redraw()

func _begin_aim(pos: Vector2) -> void:
	if pos.x < 390.0 and pos.y > 160.0 and pos.y < 590.0:
		aiming = true
		aim_origin = PLAYER_CANNON
		aim_point = pos
		queue_redraw()

func _end_aim(pos: Vector2) -> void:
	if not aiming:
		return
	aim_point = pos
	var direction := (aim_point - aim_origin).normalized()
	if direction.x > 0.15 and direction.y < -0.05:
		_fire_selected()
	else:
		aiming = false
		message = "AIM UP AND TO THE RIGHT"
		_update_hud()
	queue_redraw()

func _process(delta: float) -> void:
	_animate_battlefield(delta)
	if paused or game_over:
		return
	elapsed += delta
	enemy_cooldown -= delta
	if enemy_cooldown <= 0.0:
		_enemy_fire()
		enemy_cooldown = maxf(1.7, randf_range(3.2, 4.4) - float(level) * 0.07)
	_step_projectiles(delta)
	_step_particles(delta)
	_cleanup_falling_blocks()
	_check_winner()
	_update_hud()
	queue_redraw()

func _animate_battlefield(delta: float) -> void:
	battlefield_time += delta
	for i in range(animated_flags.size()):
		var flag := animated_flags[i]
		if is_instance_valid(flag):
			flag.rotation.z = sin(battlefield_time * 2.2 + float(i) * 1.7) * 0.055
	if is_instance_valid(sun_light):
		sun_light.rotation_degrees.z = -32.0 + sin(battlefield_time * 0.12) * 3.0
	if is_instance_valid(main_camera):
		var target := Vector3(6.4, -3.6, 18.0)
		var target_size := 7.2
		if camera_mode == 1:
			target = Vector3(3.2, -4.3, 13.0)
			target_size = 5.4
		elif camera_mode == 2:
			target = Vector3(6.4 + sin(battlefield_time * 0.22) * 0.75, -3.0, 15.0)
			target_size = 6.2
		main_camera.position = main_camera.position.lerp(target, minf(1.0, delta * 2.8))
		main_camera.size = lerpf(main_camera.size, target_size, minf(1.0, delta * 2.8))
		main_camera.look_at(Vector3(6.4, -3.6, 0.0), Vector3.UP)

func _step_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var pos: Vector2 = shot["pos"]
		var vel: Vector2 = shot["vel"]
		vel.y += 0.34 * delta * 60.0
		pos += vel * delta * 60.0
		shot["pos"] = pos
		shot["vel"] = vel
		var hit_index := -1
		for j in range(blocks.size()):
			var block: Dictionary = blocks[j]
			if block["team"] == shot["team"]:
				continue
			var rect: Rect2 = block["rect"]
			if rect.grow(float(shot["radius"]) * 0.35).has_point(pos):
				hit_index = j
				break
		if hit_index >= 0:
			_explode(pos, shot, hit_index)
			projectiles.remove_at(i)
		elif pos.x < -40.0 or pos.x > 1320.0 or pos.y > 620.0 or pos.y < -50.0:
			projectiles.remove_at(i)
		else:
			projectiles[i] = shot

func _explode(pos: Vector2, shot: Dictionary, direct_index: int) -> void:
	var splash := float(shot["splash"])
	var damage := int(shot["power"])
	var team: String = shot["team"]
	_apply_blast_to_debris(pos, maxf(splash, 42.0), damage, shot["vel"])
	var remove_list: Array[int] = []
	for i in range(blocks.size()):
		var block: Dictionary = blocks[i]
		if block["team"] == team:
			continue
		var rect: Rect2 = block["rect"]
		var center := rect.get_center()
		var distance := center.distance_to(pos)
		if i == direct_index or (splash > 0.0 and distance <= splash):
			var applied := damage
			if i != direct_index and splash > 0.0:
				applied = maxi(1, int(round(float(damage) * (1.0 - distance / splash))))
			block["hp"] = int(block["hp"]) - applied
			_update_block_visual(block)
			if int(block["hp"]) <= 0:
				remove_list.append(i)
				_spawn_falling_block(block, pos, shot["vel"])
			if team == "player":
				score += applied * 12
			blocks[i] = block
	_spawn_burst(pos, 15 if splash > 0.0 else 7, shot["kind"])
	for i in range(remove_list.size() - 1, -1, -1):
		blocks.remove_at(remove_list[i])
	_collapse_unsupported_blocks("player" if team == "enemy" else "enemy", pos, shot["vel"])

func _apply_blast_to_debris(center: Vector2, radius: float, damage: int, incoming_velocity: Vector2) -> void:
	var base_force := incoming_velocity.length() * 0.012 + float(damage) * 0.12
	var blast_center := Vector3(center.x * 0.01, -center.y * 0.01, 0.0)
	for body in falling_blocks:
		if not is_instance_valid(body) or body.freeze:
			continue
		var offset: Vector3 = body.global_position - blast_center
		var distance: float = offset.length() * 100.0
		if distance > radius:
			continue
		var direction: Vector3 = offset.normalized()
		if direction.length_squared() < 0.01:
			direction = Vector3.UP
		var falloff: float = 1.0 - distance / radius
		body.apply_central_impulse(direction * base_force * falloff)
		body.apply_torque_impulse(Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-3.0, 3.0)) * falloff)

func _on_debris_impact(world_position: Vector3, strength: float) -> void:
	var screen_position := Vector2(world_position.x * 100.0, -world_position.y * 100.0)
	var amount := clampi(roundi(strength * 1.5), 3, 12)
	_spawn_burst(screen_position, amount, "stone")

func _spawn_burst(pos: Vector2, amount: int, kind: String) -> void:
	var particle_color := Color("#f97316") if kind == "fire" else Color("#a88b68")
	for n in range(amount):
		if particles.size() >= 260:
			particles.remove_at(0)
		particles.append({
			"pos": pos,
			"vel": Vector2(randf_range(-5.0, 5.0), randf_range(-8.0, 1.0)),
			"life": randf_range(0.35, 0.9),
			"size": randf_range(4.0, 10.0),
			"color": particle_color
		})

func _step_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle["life"] = float(particle["life"]) - delta
		var velocity: Vector2 = particle["vel"]
		velocity.y += 0.2 * delta * 60.0
		particle["vel"] = velocity
		particle["pos"] = (particle["pos"] as Vector2) + velocity * delta * 60.0
		if float(particle["life"]) <= 0.0:
			particles.remove_at(i)
		else:
			particles[i] = particle

func _team_health(team: String) -> int:
	var total := 0
	for block in blocks:
		if block["team"] == team:
			total += int(block["hp"])
	return total

func _check_winner() -> void:
	if _team_health("enemy") <= 0:
		game_over = true
		message = "VICTORY! +%d GOLD - TAP NEXT LEVEL" % (100 + level * 25)
		if not reward_claimed:
			gold += 100 + level * 25
			best_level = maxi(best_level, level + 1)
			reward_claimed = true
			_save_progress()
		next_button.disabled = false
	elif _team_health("player") <= 0:
		game_over = true
		message = "YOUR CASTLE FELL - TRY AGAIN"
		next_button.disabled = true

func _update_hud() -> void:
	if not is_instance_valid(score_label):
		return
	var player_percent := roundi(float(_team_health("player")) / float(maxi(1, player_max_health)) * 100.0)
	var enemy_percent := roundi(float(_team_health("enemy")) / float(maxi(1, enemy_max_health)) * 100.0)
	player_label.text = "YOUR FORT %d%%" % player_percent
	enemy_label.text = "ENEMY FORT %d%%" % enemy_percent
	level_label.text = "LEVEL %d" % level
	score_label.text = "SCORE %d" % score
	gold_label.text = "GOLD %d" % gold
	var weapon: Dictionary = WEAPONS[weapon_index]
	weapon_button.text = "%s  x%d" % [weapon["name"], int(ammo.get(weapon["id"], 0))]
	upgrade_button.text = "CANNON L%d • %dG" % [cannon_level, cannon_level * 80]
	fire_button.text = "FIRE %s" % weapon["name"]
	status_label.text = message

func _draw() -> void:
	var size := get_viewport_rect().size
	if battlefield_viewport != null and battlefield_viewport.get_texture() != null:
		draw_texture_rect(battlefield_viewport.get_texture(), Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#83c9eb"))
	# Only projectiles and aiming guides remain 2D HUD overlays.
	for shot in projectiles:
		var color := Color("#ed563b") if shot["team"] == "enemy" else Color("#27384b")
		if shot["kind"] == "fire":
			color = Color("#ff762e")
		draw_circle(shot["pos"], float(shot["radius"]), color)
		draw_circle(shot["pos"] + Vector2(-2, -2), float(shot["radius"]) * 0.35, Color("#f8d58a"))
	for particle in particles:
		draw_rect(Rect2(particle["pos"], Vector2.ONE * float(particle["size"])), particle["color"])
	if aiming:
		draw_line(PLAYER_CANNON, aim_point, Color("#fff3a3"), 5.0)
		draw_circle(aim_point, 9.0, Color("#fff3a3"))
		var direction := (aim_point - PLAYER_CANNON).normalized()
		var preview := PLAYER_CANNON + direction * 95.0
		draw_line(PLAYER_CANNON, preview, Color(1.0, 1.0, 1.0, 0.6), 3.0)
		_draw_trajectory_preview()

func _draw_trajectory_preview() -> void:
	var weapon: Dictionary = WEAPONS[weapon_index]
	var direction := (aim_point - PLAYER_CANNON).normalized()
	if direction.x < 0.2:
		direction.x = 0.2
	direction.y = clampf(direction.y, -1.0, -0.08)
	direction = direction.normalized()
	var speed := float(weapon["speed"]) * (1.0 + float(cannon_level - 1) * 0.045)
	var velocity := direction * speed
	var position := PLAYER_CANNON + Vector2(15.0, -12.0)
	for frame in range(1, 61):
		velocity.y += 0.34
		position += velocity
		if frame % 3 == 0:
			var alpha := 1.0 - float(frame) / 75.0
			draw_circle(position, 3.5, Color(1.0, 0.92, 0.55, alpha))
		if position.y >= FLOOR_Y or position.x >= 1320.0 or position.x < 0.0:
			break

func _draw_castle_details() -> void:
	# Flags and crenellations give the two forts distinct silhouettes.
	for team_x in [90.0, 1010.0]:
		var flag_x: float = float(team_x) + 60.0
		var flag_y: float = FLOOR_Y - 25.0 - 5.0 * 25.0 - 58.0
		draw_line(Vector2(flag_x, flag_y + 45.0), Vector2(flag_x, flag_y - 8.0), Color("#59483c"), 4.0)
		var flag_color := Color("#2563a6") if team_x < 500.0 else Color("#b91c1c")
		draw_colored_polygon(PackedVector2Array([Vector2(flag_x, flag_y - 8.0), Vector2(flag_x + 38.0, flag_y + 1.0), Vector2(flag_x, flag_y + 12.0)]), flag_color)
		for i in range(5):
			var crenel_x: float = float(team_x) + float(i) * 24.0
			draw_rect(Rect2(crenel_x + 2.0, FLOOR_Y - 25.0 - 5.0 * 25.0 - 9.0, 10.0, 10.0), Color("#b9824c") if team_x < 500.0 else Color("#8994a6"))

func _draw_soldiers() -> void:
	for i in range(4):
		_draw_soldier(Vector2(55.0 + float(i) * 24.0, 540.0), Color("#2563a6"))
		_draw_soldier(Vector2(1160.0 + float(i) * 19.0, 540.0), Color("#b91c1c"))

func _draw_soldier(pos: Vector2, color: Color) -> void:
	draw_circle(pos + Vector2(0, -14), 7.0, Color("#f0c7a0"))
	draw_rect(Rect2(pos.x - 6.0, pos.y - 8.0, 12.0, 18.0), color)
	draw_line(pos + Vector2(-3, 10), pos + Vector2(-7, 19), Color("#30343b"), 3.0)
	draw_line(pos + Vector2(3, 10), pos + Vector2(7, 19), Color("#30343b"), 3.0)
	draw_line(pos + Vector2(4, -5), pos + Vector2(13, -17), Color("#514437"), 3.0)

func _draw_cannon(pos: Vector2, color: Color, flip: bool) -> void:
	draw_circle(pos + Vector2(0, 12), 24.0, Color("#364451"))
	var barrel := Rect2(pos.x - 5.0, pos.y - 16.0, 48.0, 17.0)
	if flip:
		barrel.position.x = pos.x - 43.0
	draw_rect(barrel, color)
	draw_rect(barrel, Color("#172b3b"), false, 3.0)
	draw_circle(pos, 20.0, color)
	draw_circle(pos, 9.0, Color("#172b3b"))
