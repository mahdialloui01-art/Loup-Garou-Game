extends Node3D

const TARGET := Vector3(0.0, 1.5, 0.0)
const MIN_DISTANCE := 9.0
const MAX_DISTANCE := 25.0

var camera: Camera3D
var yaw := 0.0
var pitch := -0.48
var distance := 17.0
var dragging := false
var last_pointer := Vector2.ZERO
var hint_label: Label

func _ready() -> void:
	_build_world()
	_build_castle()
	_build_hud()
	_update_camera()

func _build_world() -> void:
	var world := WorldEnvironment.new()
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
	environment.ambient_light_color = Color("#b7c8d5")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(60.0, 60.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("#718b54")
	ground_mat.roughness = 1.0
	ground_mesh.material = ground_mat
	ground.mesh = ground_mesh
	ground.position.y = -0.12
	add_child(ground)

	camera = Camera3D.new()
	camera.name = "AngledTopDownCamera"
	camera.current = true
	camera.fov = 55.0
	add_child(camera)

func _build_castle() -> void:
	# A raised foundation and authentic Kenney wall modules.
	_add_box(Vector3(0.0, 0.15, 0.0), Vector3(13.0, 0.5, 10.0), Color("#8b806c"))
	_add_box(Vector3(0.0, 0.48, 0.0), Vector3(11.8, 0.18, 8.8), Color("#b6a58a"))
	var wall_y := 0.57

	# One-metre wall modules make a consistent perimeter at the chosen scale.
	for x in range(-4, 5):
		_add_kenney_model("models/wall.glb", Vector3(float(x), wall_y, -3.5))
		_add_kenney_model("models/wall.glb", Vector3(float(x), wall_y, 3.5))
	for z in range(-2, 3):
		_add_kenney_model("models/wall.glb", Vector3(-4.5, wall_y, float(z)), Vector3.ONE, 90.0)
		_add_kenney_model("models/wall.glb", Vector3(4.5, wall_y, float(z)), Vector3.ONE, 90.0)

	# Four square towers are assembled from low-poly blocks and roof meshes.
	for x in [-4.5, 4.5]:
		for z in [-3.5, 3.5]:
			_add_box(Vector3(x, 1.45, z), Vector3(1.35, 2.0, 1.35), Color("#b9aa91"))
			_add_roof(Vector3(x, 2.75, z), Vector3(1.7, 1.15, 1.7), Color("#536d83"))
			_add_box(Vector3(x, 3.6, z), Vector3(0.08, 0.8, 0.08), Color("#493d32"))
			_add_box(Vector3(x + 0.25, 3.82, z), Vector3(0.55, 0.28, 0.04), Color("#c14942"))

	# Central keep and a simple gate give the walls a clear focal point.
	_add_box(Vector3(0.0, 1.8, -0.5), Vector3(3.3, 2.7, 2.8), Color("#a99a82"))
	_add_roof(Vector3(0.0, 3.65, -0.5), Vector3(3.8, 1.25, 3.2), Color("#536d83"))
	_add_box(Vector3(0.0, 1.25, 3.58), Vector3(1.7, 1.45, 0.18), Color("#493d32"))

	# Kenney catapult is represented by a simple siege prop until its model is added.
	_add_box(Vector3(0.0, 0.78, 7.0), Vector3(1.25, 0.3, 0.95), Color("#493c31"))
	_add_cylinder(Vector3(0.0, 1.1, 6.8), 0.12, 1.35, Color("#806142"), Vector3(-38.0, 0.0, 0.0))

	for p in [Vector3(-8.0, 0.0, -4.5), Vector3(8.0, 0.0, -4.5), Vector3(-8.0, 0.0, 5.0), Vector3(8.0, 0.0, 5.0)]:
		_add_cylinder(p + Vector3(0.0, 0.8, 0.0), 0.18, 1.6, Color("#6b4a32"))
		_add_sphere(p + Vector3(0.0, 2.0, 0.0), 1.15, Color("#47764a"))

func _add_kenney_model(relative_path: String, pos: Vector3, scale_value := Vector3.ONE, yaw_degrees := 0.0) -> void:
	var resource_path := "res://assets/vendor/kenney-runtime/" + relative_path
	var packed := load(resource_path) as PackedScene
	if packed == null:
		push_warning("Missing Kenney model: " + resource_path)
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_warning("Kenney model is not a Node3D scene: " + resource_path)
		return
	instance.position = pos
	instance.scale = scale_value
	instance.rotation.y = deg_to_rad(yaw_degrees)
	add_child(instance)

func _add_tower(base: Vector3) -> void:
	_add_box(base + Vector3(0.0, 1.55, 0.0), Vector3(1.5, 3.1, 1.5), Color("#a99a82"))
	_add_roof(base + Vector3(0.0, 3.45, 0.0), Vector3(1.9, 1.4, 1.9), Color("#536d83"))

func _add_box(pos: Vector3, dimensions: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material = material
	node.mesh = mesh
	node.position = pos
	add_child(node)

func _add_roof(pos: Vector3, dimensions: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	node.mesh = mesh
	node.position = pos
	add_child(node)

func _add_cylinder(pos: Vector3, radius: float, height: float, color: Color, tilt := Vector3.ZERO) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = tilt
	add_child(node)

func _add_sphere(pos: Vector3, radius: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	node.mesh = mesh
	node.position = pos
	add_child(node)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 14.0
	panel.offset_top = 14.0
	panel.offset_right = -14.0
	panel.offset_bottom = 76.0
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var back := Button.new()
	back.text = "BACK TO GAME"
	back.custom_minimum_size = Vector2(170.0, 42.0)
	back.pressed.connect(_return_to_game)
	_apply_kenney_button(back, Color("#244e70"))
	row.add_child(back)
	var zoom_out := Button.new()
	zoom_out.text = "−"
	zoom_out.custom_minimum_size = Vector2(48.0, 42.0)
	zoom_out.pressed.connect(func(): _zoom(1.5))
	_apply_kenney_button(zoom_out, Color("#315c78"))
	row.add_child(zoom_out)
	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.custom_minimum_size = Vector2(48.0, 42.0)
	zoom_in.pressed.connect(func(): _zoom(-1.5))
	_apply_kenney_button(zoom_in, Color("#315c78"))
	row.add_child(zoom_in)
	hint_label = Label.new()
	hint_label.text = "CAMERA A  |  DRAG TO ORBIT  |  USE +/- TO ZOOM"
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint_label)

func _apply_kenney_button(button: Button, tint: Color) -> void:
	var button_texture := load("res://assets/vendor/kenney-runtime/ui/button_rectangle_depth_flat.png") as Texture2D
	if button_texture == null:
		return
	for entry in [
		{"name": "normal", "tint": tint},
		{"name": "hover", "tint": tint.lightened(0.12)},
		{"name": "pressed", "tint": tint.darkened(0.12)}
	]:
		var style := StyleBoxTexture.new()
		style.texture = button_texture
		style.modulate_color = entry["tint"]
		style.texture_margin_left = 16.0
		style.texture_margin_right = 16.0
		style.texture_margin_top = 12.0
		style.texture_margin_bottom = 12.0
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0
		button.add_theme_stylebox_override(entry["name"], style)

func _update_camera() -> void:
	if not is_instance_valid(camera):
		return
	var horizontal := cos(pitch) * distance
	var vertical := -sin(pitch) * distance
	camera.position = TARGET + Vector3(sin(yaw) * horizontal, vertical, cos(yaw) * horizontal)
	camera.look_at(TARGET, Vector3.UP)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		dragging = touch.pressed
		last_pointer = touch.position
	elif event is InputEventScreenDrag and dragging:
		var drag := event as InputEventScreenDrag
		_orbit(drag.relative)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			dragging = mouse.pressed
			last_pointer = mouse.position
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(MIN_DISTANCE, distance - 1.0)
			_update_camera()
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(MAX_DISTANCE, distance + 1.0)
			_update_camera()
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		_orbit(motion.relative)

func _zoom(amount: float) -> void:
	distance = clampf(distance + amount, MIN_DISTANCE, MAX_DISTANCE)
	_update_camera()

func _orbit(delta: Vector2) -> void:
	yaw -= delta.x * 0.006
	pitch = clampf(pitch - delta.y * 0.004, -0.95, -0.16)
	_update_camera()

func _return_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
