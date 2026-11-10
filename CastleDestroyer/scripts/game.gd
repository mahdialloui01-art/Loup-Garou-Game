extends Control

class FallingFortBlock extends RigidBody2D:
	var block_size := Vector2(22.0, 23.0)
	var block_color := Color("#c68a4c")

	func _ready() -> void:
		var shape := RectangleShape2D.new()
		shape.size = block_size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		add_child(collision)
		var material := PhysicsMaterial.new()
		material.friction = 0.82
		material.bounce = 0.12
		physics_material_override = material
		contact_monitor = true
		max_contacts_reported = 4

	func _draw() -> void:
		var rect := Rect2(-block_size * 0.5, block_size)
		draw_rect(rect, block_color)
		draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2(block_size.x - 4.0, 4.0)), block_color.lightened(0.32))
		draw_rect(rect, Color("#514437"), false, 2.0)

# Castle Destroyer - campaign foundation
# All artwork is original procedural drawing; no Castle Busters assets are used.

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
var physics_root: Node2D
var floor_body: StaticBody2D
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

func _ready() -> void:
	randomize()
	_load_progress()
	physics_root = Node2D.new()
	physics_root.name = "FortPhysics"
	add_child(physics_root)
	_create_physics_floor()
	_build_ui()
	_new_game()
	set_process(true)

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

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 11
	style.corner_radius_top_right = 11
	style.corner_radius_bottom_left = 11
	style.corner_radius_bottom_right = 11
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style

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
	floor_body = StaticBody2D.new()
	floor_body.name = "GroundCollider"
	floor_body.position = Vector2(640.0, FLOOR_Y + 8.0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1500.0, 16.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	physics_root.add_child(floor_body)

func _clear_physics_castle() -> void:
	for child in physics_root.get_children():
		if child != floor_body:
			child.free()
	falling_blocks.clear()

func _make_block(rect: Rect2, team: String, hp: int, max_hp: int, kind: String) -> Dictionary:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	physics_root.add_child(body)
	return {"rect": rect, "team": team, "hp": hp, "max_hp": max_hp, "kind": kind, "body": body}

func _spawn_falling_block(block: Dictionary, impact: Vector2, incoming_velocity: Vector2) -> void:
	if falling_blocks.size() >= 70:
		var oldest: RigidBody2D = falling_blocks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var body := FallingFortBlock.new()
	var rect: Rect2 = block["rect"]
	body.block_size = rect.size
	body.block_color = Color("#c68a4c") if block["team"] == "player" else Color("#8994a6")
	body.mass = clampf(rect.size.x * rect.size.y / 500.0, 0.8, 3.5)
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 1
	var away := (rect.get_center() - impact).normalized()
	if away.length_squared() < 0.01:
		away = Vector2.UP
	body.linear_velocity = incoming_velocity * 0.12 + away * randf_range(2.5, 6.0)
	body.angular_velocity = randf_range(-2.8, 2.8)
	body.freeze = paused
	physics_root.add_child(body)
	falling_blocks.append(body)
	var old_body: StaticBody2D = block["body"]
	if is_instance_valid(old_body):
		old_body.queue_free()

func _collapse_unsupported_blocks(team: String, impact: Vector2, incoming_velocity: Vector2) -> void:
	var passes := 0
	while passes < 12:
		passes += 1
		var unsupported: Array[int] = []
		for i in range(blocks.size()):
			var block: Dictionary = blocks[i]
			if block["team"] != team:
				continue
			var rect: Rect2 = block["rect"]
			if rect.position.y >= FLOOR_Y - 28.0:
				continue
			var supported := false
			for j in range(blocks.size()):
				if i == j:
					continue
				var candidate: Dictionary = blocks[j]
				if candidate["team"] != team:
					continue
				var below: Rect2 = candidate["rect"]
				var vertical_gap := absf(below.position.y - rect.end.y)
				var horizontal_overlap := minf(rect.end.x, below.end.x) - maxf(rect.position.x, below.position.x)
				if vertical_gap <= 12.0 and horizontal_overlap >= minf(8.0, rect.size.x * 0.3):
					supported = true
					break
			if not supported:
				unsupported.append(i)
		if unsupported.is_empty():
			break
		for index in range(unsupported.size() - 1, -1, -1):
			var block: Dictionary = blocks[unsupported[index]]
			_spawn_falling_block(block, impact, incoming_velocity)
			blocks.remove_at(unsupported[index])

func _cleanup_falling_blocks() -> void:
	for i in range(falling_blocks.size() - 1, -1, -1):
		var body: RigidBody2D = falling_blocks[i]
		if not is_instance_valid(body) or body.position.y > 900.0:
			if is_instance_valid(body):
				body.queue_free()
			falling_blocks.remove_at(i)

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
	var base_force := incoming_velocity.length() * 1.8 + float(damage) * 12.0
	for body in falling_blocks:
		if not is_instance_valid(body) or body.freeze:
			continue
		var offset: Vector2 = body.global_position - center
		var distance: float = offset.length()
		if distance > radius:
			continue
		var direction: Vector2 = offset.normalized()
		if direction.length_squared() < 0.01:
			direction = Vector2.UP
		var falloff: float = 1.0 - distance / radius
		body.apply_central_impulse(direction * base_force * falloff)
		body.apply_torque_impulse(randf_range(-3.0, 3.0) * falloff)

func _spawn_burst(pos: Vector2, amount: int, kind: String) -> void:
	var particle_color := Color("#f97316") if kind == "fire" else Color("#a88b68")
	for n in range(amount):
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
	var sky := Color("#83c9eb")
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	# Distant mountains and sun.
	draw_circle(Vector2(1080.0, 125.0), 48.0, Color("#ffe58a"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 430), Vector2(190, 230), Vector2(390, 430)]), Color("#a4c8b2"))
	draw_colored_polygon(PackedVector2Array([Vector2(330, 440), Vector2(590, 190), Vector2(850, 440)]), Color("#9abca9"))
	draw_colored_polygon(PackedVector2Array([Vector2(790, 430), Vector2(1040, 220), Vector2(1280, 430)]), Color("#a4c8b2"))
	for cloud_x in [100.0, 430.0, 780.0]:
		draw_circle(Vector2(cloud_x, 120.0), 25.0, Color("#f4fbff"))
		draw_circle(Vector2(cloud_x + 25.0, 110.0), 31.0, Color("#f4fbff"))
		draw_circle(Vector2(cloud_x + 52.0, 122.0), 23.0, Color("#f4fbff"))
	draw_rect(Rect2(0.0, FLOOR_Y, size.x, size.y - FLOOR_Y), Color("#78b95a"))
	draw_rect(Rect2(0.0, FLOOR_Y + 14.0, size.x, 18.0), Color("#568b42"))
	draw_circle(Vector2(350.0, 575.0), 160.0, Color("#91c875"))
	draw_circle(Vector2(900.0, 580.0), 190.0, Color("#91c875"))
	_draw_castle_details()
	for block in blocks:
		var rect: Rect2 = block["rect"]
		var is_player: bool = block["team"] == "player"
		var base_color := Color("#c68a4c") if is_player else Color("#8994a6")
		if block["kind"] == "tower":
			base_color = Color("#a66e3e") if is_player else Color("#69788d")
		var hp_ratio := float(block["hp"]) / float(block["max_hp"])
		if hp_ratio < 0.5:
			base_color = base_color.darkened(0.25)
		draw_rect(rect, base_color)
		draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 4)), base_color.lightened(0.35))
		draw_rect(rect, Color("#514437"), false, 2.0)
		if int(block["max_hp"]) > 1:
			draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 5), Vector2(rect.size.x - 8, 3)), Color("#6c302b"))
	_draw_cannon(PLAYER_CANNON, Color("#245b8c"), false)
	_draw_cannon(ENEMY_CANNON, Color("#9c3434"), true)
	_draw_soldiers()
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
