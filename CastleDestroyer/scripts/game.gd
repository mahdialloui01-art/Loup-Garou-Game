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
var battlefield_base_size := Vector2i.ZERO
var battlefield_max_size := Vector2i.ZERO
var battlefield_render_scale := 1.0
var fps_smoothed := 60.0
var quality_check_timer := 0.0
var main_camera: Camera3D
var player_cannon_node: Node3D
var sun_light: DirectionalLight3D
var sun_disc: MeshInstance3D
var animated_flags: Array[Node3D] = []
var gobkit_insect_count := 0
var camera_mode := 0
var camera_zoom := 1.0
var camera_orbit_yaw := 0.0
var camera_orbit_pitch := 0.0
var camera_touches: Dictionary = {}
var previous_pinch_distance := 0.0
var battlefield_time := 0.0
var floor_body: StaticBody3D
var projectiles: Array = []
var particles: Array = []
var fx_particles_3d: Array = []
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
var game_hud: Array[Control] = []
var main_menu: Control
var settings_panel: PanelContainer
var game_started := false
var camera_sensitivity := 1.0

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
	_build_main_menu()
	_set_game_hud_visible(false)
	set_process(true)


func _build_3d_battlefield() -> void:
	# The battlefield and destructible castle geometry are rendered in 3D.
	# The current hit-testing and structural graph remain authoritative.
	battlefield_viewport = SubViewport.new()
	battlefield_viewport.name = "Battlefield3DViewport"
	var initial_size := get_viewport_rect().size
	# Ultra 4K render target: keep the UI/touch coordinate space native while
	# rendering the 3D battlefield at up to 3840x2160 (portrait: 2160x3840).
	# The scale is capped to prevent pathological allocations on unusual displays.
	var target_size := Vector2(3840.0, 2160.0)
	if initial_size.y > initial_size.x:
		target_size = Vector2(2160.0, 3840.0)
	battlefield_base_size = Vector2i(maxi(roundi(initial_size.x), 1), maxi(roundi(initial_size.y), 1))
	battlefield_render_scale = minf(4.0, minf(
		target_size.x / maxf(initial_size.x, 1.0),
		target_size.y / maxf(initial_size.y, 1.0)
	))
	battlefield_max_size = Vector2i(
		maxi(roundi(initial_size.x * battlefield_render_scale), 1),
		maxi(roundi(initial_size.y * battlefield_render_scale), 1)
	)
	battlefield_viewport.size = battlefield_max_size
	battlefield_viewport.disable_3d = false
	battlefield_viewport.transparent_bg = false
	battlefield_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(battlefield_viewport)

	var world := Node3D.new()
	world.name = "Battlefield3D"
	battlefield_viewport.add_child(world)

	var environment_node := WorldEnvironment.new()
	environment_node.name = "WorldEnvironment"
	var environment := Environment.new()
	# Cinematic but mobile-friendly image-based ambience.
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#347fbd")
	sky_material.sky_horizon_color = Color("#d9e9f2")
	sky_material.ground_bottom_color = Color("#344b39")
	sky_material.ground_horizon_color = Color("#8b9b83")
	# Render a visible solar disc in the procedural sky, aligned with the sun light.
	sky_material.sun_angle_max = 0.8
	sky_material.sun_curve = 0.18
	sky_material.use_debanding = true
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c4d4df")
	environment.ambient_light_energy = 1.25
	environment.glow_enabled = true
	environment.glow_intensity = 0.65
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.08
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.18
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#a9bac0")
	environment.fog_density = 0.0045
	# Volumetric fog is disabled on mobile: it is expensive at 4K.
	# The high-quality distance fog remains enabled for atmospheric depth.
	environment.volumetric_fog_enabled = false
	environment_node.environment = environment
	world.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.5
	sun.light_color = Color("#fff0d5")
	sun.shadow_enabled = true
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	# Two cascades retain clear castle shadows with substantially less GPU work.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 22.0
	world.add_child(sun)
	sun_light = sun

	# A continuous world-sized ground replaces the old narrow floating slab.
	# The playable lane sits on this terrain, which continues far beyond the camera view.
	var ground := MeshInstance3D.new()
	ground.name = "ContinuousWorldGround"
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(240.0, 0.5, 240.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#71864d")
	ground_material.roughness = 1.0
	ground_mesh.material = ground_material
	ground.mesh = ground_mesh
	ground.position = Vector3(6.4, -(FLOOR_Y + 8.0) * 0.01 - 0.25, -45.0)
	world.add_child(ground)
	_build_terrain_detail(world)
	_build_distant_landscape(world)
	_add_gobkit_ambient_insects(world)

	_add_battlefield_prop(world, "models/siege-catapult.glb", Vector3(6.4, -5.45, -0.7), Vector3(0.55, 0.55, 0.55), 180.0)
	_add_battlefield_prop(world, "models/rocks-large.glb", Vector3(0.45, -5.46, -1.2), Vector3(0.75, 0.75, 0.75))
	_add_battlefield_prop(world, "models/rocks-large.glb", Vector3(12.25, -5.46, -1.1), Vector3(0.9, 0.9, 0.9))
	for tree_position in [
		Vector3(-0.25, -5.45, -0.9), Vector3(12.9, -5.45, -0.9)
	]:
		_add_battlefield_prop(world, "models/tree-large.glb", tree_position, Vector3(0.55, 0.55, 0.55))
	_add_battlefield_castle_details(90.0, "player")
	_add_battlefield_castle_details(1010.0, "enemy")

	var camera := Camera3D.new()
	camera.name = "MainBattlefieldCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Tactical elevated 3D overview: the camera looks down across the full siege lane.
	camera.size = 8.4
	# Lower, shallower camera angle deliberately exposes the sky above the horizon.
	camera.position = Vector3(6.4, 7.5, 14.5)
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3(6.4, -3.6, 0.0), Vector3.UP)
	main_camera = camera

	# A dedicated emissive solar disc guarantees a visible sun on mobile renderers,
	# while the procedural sky sun continues to provide the matching directional light.
	sun_disc = MeshInstance3D.new()
	sun_disc.name = "VisibleSunDisc"
	var sun_disc_mesh := SphereMesh.new()
	sun_disc_mesh.radius = 0.30
	sun_disc_mesh.height = 0.60
	var sun_disc_material := StandardMaterial3D.new()
	sun_disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_disc_material.albedo_color = Color("#fff1bd")
	sun_disc_material.emission_enabled = true
	sun_disc_material.emission = Color("#ffd77a")
	sun_disc_material.emission_energy_multiplier = 2.4
	sun_disc_material.disable_fog = true
	sun_disc_mesh.material = sun_disc_material
	sun_disc.mesh = sun_disc_mesh
	world.add_child(sun_disc)
	sun_disc.global_transform = camera.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, -32.0))
	_add_3d_cannon(world, Vector3(2.05, -5.05, 0.28), Color("#c28a45"), false)
	player_cannon_node = world.get_node_or_null("3DCannon")
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
	# Continue the textured ground to the horizon in every direction.
	terrain_mesh.size = Vector2(240.0, 240.0)
	terrain.mesh = terrain_mesh
	terrain.position = Vector3(6.4, -(FLOOR_Y + 8.0) * 0.01 - 0.245, -45.0)
	var terrain_shader := Shader.new()
	terrain_shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
void fragment() {
	vec2 cell = floor(UV * vec2(2700.0, 2700.0));
	float grain = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float broad = sin(UV.x * 465.0) * cos(UV.y * 876.0);
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
	grass_multi.instance_count = 1600
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
	pebbles.instance_count = 240
	for i in range(pebbles.instance_count):
		var pebble_position := Vector3(randf_range(0.0, 12.8), terrain.position.y + 0.012, randf_range(-2.3, 2.3))
		var pebble_scale := Vector3(randf_range(0.7, 1.8), randf_range(0.55, 1.0), randf_range(0.7, 1.5))
		pebbles.set_instance_transform(i, Transform3D(Basis().scaled(pebble_scale), pebble_position))
	var pebble_instance := MultiMeshInstance3D.new()
	pebble_instance.name = "ScatteredGravel"
	pebble_instance.multimesh = pebbles
	world.add_child(pebble_instance)


func _build_distant_landscape(world: Node3D) -> void:
	# Layered 3D hills, tree lines and rock clusters give the battlefield real depth.
	var hill_colors := [Color("#536d45"), Color("#687b4c"), Color("#7c8654")]
	for i in range(8):
		var hill := MeshInstance3D.new()
		hill.name = "DistantRollingHill_%02d" % i
		var hill_mesh := SphereMesh.new()
		hill_mesh.radius = 1.0
		hill_mesh.height = 1.0
		var hill_material := StandardMaterial3D.new()
		hill_material.albedo_color = hill_colors[i % hill_colors.size()]
		hill_material.roughness = 1.0
		hill_mesh.material = hill_material
		hill.mesh = hill_mesh
		hill.scale = Vector3(randf_range(1.3, 2.2), randf_range(0.55, 0.9), randf_range(0.45, 0.75))
		hill.position = Vector3(-1.1 + float(i) * 2.0, -4.95 + randf_range(-0.15, 0.18), -3.5 - randf_range(0.0, 0.8))
		world.add_child(hill)
	for tree_position in [
		Vector3(1.8, -5.25, -2.8), Vector3(3.4, -5.25, -3.0),
		Vector3(5.4, -5.25, -3.2), Vector3(7.8, -5.25, -3.0),
		Vector3(9.4, -5.25, -2.8), Vector3(11.0, -5.25, -3.1)
	]:
		_add_battlefield_prop(world, "models/tree-large.glb", tree_position, Vector3(0.38, 0.42, 0.38), randf_range(-18.0, 18.0))
	for rock_position in [
		Vector3(2.7, -5.5, -1.9), Vector3(4.3, -5.5, -2.0),
		Vector3(8.8, -5.5, -1.8), Vector3(10.2, -5.5, -2.1)
	]:
		_add_battlefield_prop(world, "models/rocks-large.glb", rock_position, Vector3(0.24, 0.24, 0.24), randf_range(0.0, 360.0))
	# A broad natural ridgeline closes the distant horizon without exposing a platform edge.
	for i in range(14):
		var ridge := MeshInstance3D.new()
		ridge.name = "FarHorizonHill_%02d" % i
		var ridge_mesh := SphereMesh.new()
		ridge_mesh.radius = 1.0
		ridge_mesh.height = 1.0
		var ridge_material := StandardMaterial3D.new()
		ridge_material.albedo_color = hill_colors[(i + 1) % hill_colors.size()].lightened(0.08)
		ridge_material.roughness = 1.0
		ridge_mesh.material = ridge_material
		ridge.mesh = ridge_mesh
		ridge.scale = Vector3(randf_range(4.5, 7.5), randf_range(2.4, 3.8), randf_range(3.0, 5.0))
		ridge.position = Vector3(-20.0 + float(i) * 4.0, -2.0 - randf_range(0.0, 0.7), -43.0 - randf_range(0.0, 5.0))
		world.add_child(ridge)
	# Distant tree silhouettes add depth along the new horizon.
	for i in range(12):
		var far_tree_x := -17.0 + float(i) * 4.2
		_add_battlefield_prop(world, "models/tree-large.glb", Vector3(far_tree_x, -5.45, -27.0), Vector3(0.52, 0.62, 0.52), randf_range(-22.0, 22.0))


func _add_gobkit_ambient_insects(parent: Node3D) -> void:
	# Load at most two animated CC0 insects. Keeping the count low protects
	# mobile frame time while adding genuine animated 3D life to the scenery.
	const ASSET_ROOT := "res://assets/vendor/gobkit-runtime"
	var directory := DirAccess.open(ASSET_ROOT)
	if directory == null:
		push_warning("Gobkit runtime assets are not staged; skipping ambient insects.")
		return

	var filenames: Array[String] = []
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.get_extension().to_lower() == "glb":
			filenames.append(filename)
		filename = directory.get_next()
	directory.list_dir_end()
	filenames.sort()

	var insect_root := Node3D.new()
	insect_root.name = "GobkitAmbientInsects"
	parent.add_child(insect_root)
	for i in range(mini(2, filenames.size())):
		var resource_path := ASSET_ROOT + "/" + filenames[i]
		var packed := load(resource_path) as PackedScene
		if packed == null:
			push_warning("Could not load Gobkit model: " + resource_path)
			continue
		var insect := packed.instantiate() as Node3D
		if insect == null:
			push_warning("Gobkit model root is not Node3D: " + resource_path)
			continue
		insect.name = "GobkitAmbientInsect_%02d" % i

		# Normalize unknown source-model dimensions to a small, readable
		# background scale; disable insect shadows to avoid extra mobile GPU cost.
		var combined_bounds := AABB()
		var has_bounds := false
		for mesh_node in insect.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			var mesh_bounds: AABB = (insect.global_transform.affine_inverse() * mesh_instance.global_transform) * mesh_instance.get_aabb()
			if has_bounds:
				combined_bounds = combined_bounds.merge(mesh_bounds)
			else:
				combined_bounds = mesh_bounds
				has_bounds = true
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var largest_extent := maxf(combined_bounds.size.x, maxf(combined_bounds.size.y, combined_bounds.size.z)) if has_bounds else 1.0
		var normalized_scale := clampf(0.42 / maxf(largest_extent, 0.001), 0.001, 1.0)
		insect.scale = Vector3.ONE * normalized_scale
		insect.position = Vector3(2.4 + float(i) * 7.1, -4.78 + float(i) * 0.10, -3.05)
		insect.rotation.y = deg_to_rad(24.0 if i == 0 else -18.0)
		insect_root.add_child(insect)

		# Prefer the authored idle loop; fall back to the first available clip.
		for animation_node in insect.find_children("*", "AnimationPlayer", true, false):
			var animation_player := animation_node as AnimationPlayer
			var animation_names := animation_player.get_animation_list()
			var selected_animation := ""
			for animation_name in animation_names:
				if String(animation_name).to_lower().contains("idle"):
					selected_animation = String(animation_name)
					break
			if selected_animation.is_empty() and not animation_names.is_empty():
				selected_animation = String(animation_names[0])
			if not selected_animation.is_empty():
				animation_player.play(selected_animation)
		gobkit_insect_count += 1

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
	if not mirrored:
		cannon.name = "Player3DCannon"
		player_cannon_node = cannon
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.24
	base_mesh.bottom_radius = 0.3
	base_mesh.height = 0.22
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = tint.darkened(0.28)
	base_mat.metallic = 0.12
	base_mat.roughness = 0.68
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
		uniform.roughness = 0.76
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
	game_hud.append(top)

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
	game_hud.append(status_label)

	var controls := GridContainer.new()
	controls.columns = 4
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 6)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 12
	controls.offset_top = -118
	controls.offset_right = -12
	controls.offset_bottom = -8
	add_child(controls)
	game_hud.append(controls)

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
	camera_test_button = _make_button("CAMERA 3D • OVERVIEW", Color("#475569"))
	camera_test_button.custom_minimum_size = Vector2(130.0, 48.0)
	camera_test_button.pressed.connect(_open_camera_test)
	controls.add_child(camera_test_button)
	for control_button in controls.get_children():
		if control_button is Button:
			control_button.custom_minimum_size = Vector2(130.0, 48.0)
			control_button.add_theme_font_size_override("font_size", 12)

func _set_game_hud_visible(is_visible: bool) -> void:
	for item in game_hud:
		if is_instance_valid(item):
			item.visible = is_visible

func _build_main_menu() -> void:
	main_menu = Control.new()
	main_menu.name = "MainMenuScreen"
	main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(main_menu)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.035, 0.055, 0.075, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_menu.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360.0, 0.0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _menu_panel_style())
	center.add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(content)

	var title := Label.new()
	title.text = "CASTLE\nDESTROYER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#f4d49b"))
	title.add_theme_color_override("font_shadow_color", Color("#171d26"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "3D MEDIEVAL SIEGE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("#cbd5e1"))
	content.add_child(subtitle)

	var start_button := _make_button("START BATTLE", Color("#9b642d"))
	start_button.custom_minimum_size = Vector2(280.0, 62.0)
	start_button.pressed.connect(_start_game)
	content.add_child(start_button)

	var settings_button := _make_button("SETTINGS", Color("#475569"))
	settings_button.custom_minimum_size = Vector2(280.0, 54.0)
	settings_button.pressed.connect(_show_settings)
	content.add_child(settings_button)

	var exit_button := _make_button("EXIT GAME", Color("#7f3434"))
	exit_button.custom_minimum_size = Vector2(280.0, 54.0)
	exit_button.pressed.connect(_exit_game)
	content.add_child(exit_button)

	var footer := Label.new()
	footer.text = "BUILD • DEFEND • DESTROY"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color("#aab7c5"))
	content.add_child(footer)

	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.visible = false
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -175
	settings_panel.offset_top = -135
	settings_panel.offset_right = 175
	settings_panel.offset_bottom = 135
	settings_panel.add_theme_stylebox_override("panel", _menu_panel_style())
	main_menu.add_child(settings_panel)

	var settings_content := VBoxContainer.new()
	settings_content.add_theme_constant_override("separation", 14)
	settings_panel.add_child(settings_content)
	var settings_title := Label.new()
	settings_title.text = "SETTINGS"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 28)
	settings_title.add_theme_color_override("font_color", Color("#f4d49b"))
	settings_content.add_child(settings_title)

	var sensitivity_label := Label.new()
	sensitivity_label.text = "TOUCH CAMERA SENSITIVITY"
	sensitivity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sensitivity_label.add_theme_color_override("font_color", Color("#e2e8f0"))
	settings_content.add_child(sensitivity_label)
	var sensitivity_slider := HSlider.new()
	sensitivity_slider.min_value = 0.5
	sensitivity_slider.max_value = 2.0
	sensitivity_slider.step = 0.1
	sensitivity_slider.value = camera_sensitivity
	sensitivity_slider.value_changed.connect(func(value: float): camera_sensitivity = value)
	settings_content.add_child(sensitivity_slider)

	var back_button := _make_button("BACK", Color("#8b5e34"))
	back_button.pressed.connect(func(): settings_panel.visible = false)
	settings_content.add_child(back_button)

func _menu_panel_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202b36")
	style.border_color = Color("#b58a52")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	return style

func _start_game() -> void:
	game_started = true
	main_menu.visible = false
	_set_game_hud_visible(true)
	_new_game()

func _show_settings() -> void:
	settings_panel.visible = true

func _set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	audio_manager.set_music_enabled(enabled)
	_save_progress()

func _set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	audio_manager.set_sfx_enabled(enabled)
	_save_progress()

func _set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	audio_manager.set_music_volume(music_volume)
	_save_progress()

func _set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	audio_manager.set_sfx_volume(sfx_volume)
	_save_progress()

func _exit_game() -> void:
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(battlefield_viewport):
		var viewport_size := get_viewport_rect().size
		battlefield_viewport.size = Vector2i(maxi(roundi(viewport_size.x), 1), maxi(roundi(viewport_size.y), 1))
		queue_redraw()

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
	mesh_instance.name = "DestructibleStoneMesh"
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
	var labels := ["TACTICAL 3D OVERVIEW", "PLAYER FORT CLOSE-UP", "CINEMATIC 3D VIEW"]
	message = "CAMERA: " + labels[camera_mode]
	_update_hud()

func _cycle_weapon() -> void:
	weapon_index = (weapon_index + 1) % WEAPONS.size()
	_update_hud()

func _spawn_projectile_visual(kind: String, team: String) -> MeshInstance3D:
	var world := battlefield_viewport.get_child(0) as Node3D
	if world == null:
		return null
	var visual := MeshInstance3D.new()
	visual.name = "3DProjectile_" + kind
	var sphere := SphereMesh.new()
	var radius := 0.075 if kind == "stone" else 0.105
	sphere.radius = radius
	sphere.height = radius * 2.0
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color("#334155") if team == "player" else Color("#b91c1c")
	if kind == "fire":
		surface.albedo_color = Color("#ff6b24")
		surface.emission_enabled = true
		surface.emission = Color("#ff4b12")
		surface.emission_energy_multiplier = 1.8
	elif kind == "bomb":
		surface.albedo_color = Color("#292929")
		surface.metallic = 0.55
	surface.roughness = 0.58
	sphere.material = surface
	visual.mesh = sphere
	world.add_child(visual)
	return visual

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
	var launch_position := PLAYER_CANNON + Vector2(15.0, -12.0)
	var projectile_visual := _spawn_projectile_visual(weapon_id, "player")
	if is_instance_valid(projectile_visual):
		projectile_visual.position = Vector3(launch_position.x * 0.01, -launch_position.y * 0.01, 0.0)
	if is_instance_valid(player_cannon_node):
		player_cannon_node.rotation.z = atan2(-direction.y, direction.x) - deg_to_rad(55.0)
	projectiles.append({
		"pos": launch_position,
		"visual": projectile_visual,
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
	var launch_position := ENEMY_CANNON + Vector2(-15.0, -12.0)
	var projectile_visual := _spawn_projectile_visual("stone", "enemy")
	if is_instance_valid(projectile_visual):
		projectile_visual.position = Vector3(launch_position.x * 0.01, -launch_position.y * 0.01, 0.0)
	projectiles.append({
		"pos": launch_position,
		"visual": projectile_visual,
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

func _screen_to_battlefield(screen_position: Vector2) -> Vector2:
	if not is_instance_valid(main_camera) or not is_instance_valid(battlefield_viewport):
		return screen_position
	var control_size := get_viewport_rect().size
	if control_size.x <= 0.0 or control_size.y <= 0.0:
		return screen_position
	var viewport_position := screen_position * Vector2(battlefield_viewport.size) / control_size
	var ray_origin := main_camera.project_ray_origin(viewport_position)
	var ray_direction := main_camera.project_ray_normal(viewport_position)
	if absf(ray_direction.z) < 0.0001:
		return screen_position
	var distance := -ray_origin.z / ray_direction.z
	if distance < 0.0:
		return screen_position
	var world_point := ray_origin + ray_direction * distance
	return Vector2(world_point.x * 100.0, -world_point.y * 100.0)

func _input(event: InputEvent) -> void:
	if not game_started:
		return
	if event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		camera_zoom = clampf(camera_zoom / maxf(magnify.factor, 0.1), 0.62, 1.55)
		return
	if game_over or paused:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			camera_touches[touch.index] = touch.position
			if camera_touches.size() == 1:
				_begin_aim(_screen_to_battlefield(touch.position))
			else:
				aiming = false
				previous_pinch_distance = _touch_distance()
				queue_redraw()
		else:
			camera_touches.erase(touch.index)
			if camera_touches.size() < 2:
				previous_pinch_distance = 0.0
			if camera_touches.is_empty():
				_end_aim(_screen_to_battlefield(touch.position))
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if camera_touches.has(drag.index):
			var old_centroid := _touch_centroid()
			camera_touches[drag.index] = drag.position
			if camera_touches.size() >= 2:
				var new_centroid := _touch_centroid()
				var distance := _touch_distance()
				if previous_pinch_distance > 0.0 and distance > 0.0:
					camera_zoom = clampf(camera_zoom * previous_pinch_distance / distance, 0.62, 1.55)
				previous_pinch_distance = distance
				# Two-finger drag orbits the 3D camera around the fixed battlefield.
				var orbit_delta := new_centroid - old_centroid
				camera_orbit_yaw -= orbit_delta.x * 0.006 * camera_sensitivity
				camera_orbit_pitch = clampf(camera_orbit_pitch + orbit_delta.y * 0.004 * camera_sensitivity, -0.55, 0.55)
				queue_redraw()
			elif aiming:
				aim_point = _screen_to_battlefield(drag.position)
				queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_aim(_screen_to_battlefield(event.position))
		else:
			_end_aim(_screen_to_battlefield(event.position))
	elif event is InputEventMouseMotion and aiming and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		aim_point = _screen_to_battlefield(event.position)
		queue_redraw()

func _touch_centroid() -> Vector2:
	var center := Vector2.ZERO
	for point in camera_touches.values():
		center += point
	return center / maxf(float(camera_touches.size()), 1.0)

func _touch_distance() -> float:
	if camera_touches.size() < 2:
		return 0.0
	var points: Array = camera_touches.values()
	return points[0].distance_to(points[1])

func _begin_aim(pos: Vector2) -> void:
	var cannon_distance := pos.distance_to(PLAYER_CANNON)
	if cannon_distance < 175.0 and pos.x < 430.0 and pos.y > 300.0 and pos.y < 610.0:
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

func _update_render_quality(delta: float) -> void:
	# Preserve the 4K ceiling, but dynamically lower only the render target
	# when the phone GPU is overloaded, then restore it when performance recovers.
	if battlefield_viewport == null or battlefield_base_size == Vector2i.ZERO:
		return
	fps_smoothed = lerpf(fps_smoothed, 1.0 / maxf(delta, 0.001), 0.08)
	quality_check_timer += delta
	if quality_check_timer < 1.25:
		return
	quality_check_timer = 0.0
	var previous_scale := battlefield_render_scale
	if fps_smoothed < 48.0:
		battlefield_render_scale = maxf(1.5, battlefield_render_scale - 0.25)
	elif fps_smoothed > 58.0:
		var max_scale := minf(
			float(battlefield_max_size.x) / float(battlefield_base_size.x),
			float(battlefield_max_size.y) / float(battlefield_base_size.y)
		)
		battlefield_render_scale = minf(max_scale, battlefield_render_scale + 0.15)
	if not is_equal_approx(previous_scale, battlefield_render_scale):
		battlefield_viewport.size = Vector2i(
			maxi(roundi(float(battlefield_base_size.x) * battlefield_render_scale), 1),
			maxi(roundi(float(battlefield_base_size.y) * battlefield_render_scale), 1)
		)

func _process(delta: float) -> void:
	_update_render_quality(delta)
	if not game_started:
		return
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
	_step_3d_impact_particles(delta)
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
		var target := Vector3(6.4, 7.5, 14.5)
		var target_size := 8.4
		if camera_mode == 1:
			target = Vector3(3.2, 7.5, 12.0)
			target_size = 5.4
		elif camera_mode == 2:
			target = Vector3(6.4 + sin(battlefield_time * 0.22) * 0.75, 8.0, 15.5)
			target_size = 7.2
		var focus := Vector3(6.4, -1.0, 0.0)
		var base_offset := target - focus
		var radius := base_offset.length()
		var yaw := atan2(base_offset.x, base_offset.z) + camera_orbit_yaw
		var pitch := asin(clampf(base_offset.y / maxf(radius, 0.001), -1.0, 1.0)) + camera_orbit_pitch
		pitch = clampf(pitch, 0.12, 1.32)
		var orbit_offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * radius
		main_camera.position = main_camera.position.lerp(focus + orbit_offset, minf(1.0, delta * 2.8))
		main_camera.size = lerpf(main_camera.size, target_size * camera_zoom, minf(1.0, delta * 2.8))
		main_camera.look_at(focus, Vector3.UP)
		if is_instance_valid(sun_disc):
			sun_disc.global_transform = main_camera.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, -32.0))

func _step_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var previous_pos: Vector2 = shot["pos"]
		var pos: Vector2 = previous_pos
		var vel: Vector2 = shot["vel"]
		vel.y += 0.34 * delta * 60.0
		pos += vel * delta * 60.0
		shot["pos"] = pos
		shot["vel"] = vel
		var projectile_visual: MeshInstance3D = shot.get("visual")
		if is_instance_valid(projectile_visual):
			projectile_visual.position = Vector3(pos.x * 0.01, -pos.y * 0.01, 0.0)

		# Sweep the projectile through the actual 3D castle colliders. Friendly
		# fort pieces and the ground are excluded so enemy shots pass their own wall.
		var exclude_rids: Array[RID] = []
		if is_instance_valid(floor_body):
			exclude_rids.append(floor_body.get_rid())
		for block in blocks:
			if block["team"] == shot["team"]:
				var friendly_body: StaticBody3D = block.get("body")
				if is_instance_valid(friendly_body):
					exclude_rids.append(friendly_body.get_rid())
		var world_3d := physics_root.get_world_3d()
		var from_3d := Vector3(previous_pos.x * 0.01, -previous_pos.y * 0.01, 0.0)
		var to_3d := Vector3(pos.x * 0.01, -pos.y * 0.01, 0.0)
		var ray_query := PhysicsRayQueryParameters3D.create(from_3d, to_3d, 1, exclude_rids)
		ray_query.collide_with_bodies = true
		ray_query.collide_with_areas = false
		var ray_hit := world_3d.direct_space_state.intersect_ray(ray_query)
		var hit_index := -1
		if not ray_hit.is_empty():
			var hit_body: Object = ray_hit.get("collider")
			for j in range(blocks.size()):
				var candidate: Dictionary = blocks[j]
				if candidate["body"] == hit_body and candidate["team"] != shot["team"]:
					hit_index = j
					var hit_position: Vector3 = ray_hit["position"]
					pos = Vector2(hit_position.x * 100.0, -hit_position.y * 100.0)
					shot["pos"] = pos
					break
		if hit_index >= 0:
			_explode(pos, shot, hit_index)
			var hit_visual: MeshInstance3D = shot.get("visual")
			if is_instance_valid(hit_visual):
				hit_visual.queue_free()
			projectiles.remove_at(i)
		elif pos.x < -40.0 or pos.x > 1320.0 or pos.y > 620.0 or pos.y < -50.0:
			var expired_visual: MeshInstance3D = shot.get("visual")
			if is_instance_valid(expired_visual):
				expired_visual.queue_free()
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
	_spawn_3d_impact_burst(pos, amount, kind)

func _spawn_3d_impact_burst(pos: Vector2, amount: int, kind: String) -> void:
	if not is_instance_valid(physics_root):
		return
	var fire := kind == "fire"
	var base_color := Color("#ff7a24") if fire else Color("#c5a47b")
	var count := mini(amount, 22)
	for n in range(count):
		if fx_particles_3d.size() >= 140:
			var oldest: Dictionary = fx_particles_3d.pop_front()
			var old_visual: MeshInstance3D = oldest.get("visual")
			if is_instance_valid(old_visual):
				old_visual.queue_free()
		var visual := MeshInstance3D.new()
		visual.name = "3DImpactParticle"
		var mesh := SphereMesh.new()
		var radius := randf_range(0.025, 0.065) if fire else randf_range(0.018, 0.05)
		mesh.radius = radius
		mesh.height = radius * 2.0
		var surface := StandardMaterial3D.new()
		surface.albedo_color = base_color.lightened(randf_range(0.0, 0.28))
		surface.emission_enabled = true
		surface.emission = base_color
		surface.emission_energy_multiplier = 1.8 if fire else 0.45
		surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = surface
		visual.mesh = mesh
		visual.position = Vector3(pos.x * 0.01, -pos.y * 0.01, 0.22 + randf_range(-0.08, 0.08))
		physics_root.add_child(visual)
		var direction := Vector3(randf_range(-1.0, 1.0), randf_range(-0.35, 1.0), randf_range(-0.25, 0.25)).normalized()
		var speed := randf_range(1.0, 3.2) if fire else randf_range(0.7, 2.4)
		fx_particles_3d.append({
			"visual": visual,
			"velocity": direction * speed,
			"life": randf_range(0.28, 0.72) if fire else randf_range(0.35, 0.85),
			"max_life": 0.85
		})

func _step_3d_impact_particles(delta: float) -> void:
	for i in range(fx_particles_3d.size() - 1, -1, -1):
		var particle: Dictionary = fx_particles_3d[i]
		var visual: MeshInstance3D = particle.get("visual")
		if not is_instance_valid(visual):
			fx_particles_3d.remove_at(i)
			continue
		var life := float(particle["life"]) - delta
		var velocity: Vector3 = particle["velocity"]
		velocity.y -= 2.8 * delta
		particle["velocity"] = velocity
		visual.position += velocity * delta
		visual.scale = Vector3.ONE * clampf(life / float(particle["max_life"]), 0.0, 1.0)
		if life <= 0.0:
			visual.queue_free()
			fx_particles_3d.remove_at(i)
		else:
			particle["life"] = life
			fx_particles_3d[i] = particle

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
	# Projectile meshes are rendered in the live 3D battlefield viewport.
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