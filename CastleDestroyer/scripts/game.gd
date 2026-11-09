extends Control

const FLOOR_Y := 555.0
const PLAYER_CANNON := Vector2(205.0, 505.0)
const ENEMY_CANNON := Vector2(1075.0, 505.0)

var blocks: Array = []
var projectiles: Array = []
var particles: Array = []
var score := 0
var elapsed := 0.0
var game_over := false
var paused := false
var message := "DESTROY THE ENEMY CASTLE!"
var enemy_cooldown := 2.5
var score_label: Label
var status_label: Label
var player_label: Label
var enemy_label: Label

func _ready() -> void:
	_build_ui()
	_new_game()
	set_process(true)

func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_top = 14
	top.offset_right = -22
	top.offset_bottom = 62
	add_child(top)

	player_label = _make_label("YOUR CASTLE 100%", 22)
	top.add_child(player_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	score_label = _make_label("SCORE 0", 22)
	top.add_child(score_label)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer2)
	enemy_label = _make_label("ENEMY CASTLE 100%", 22)
	top.add_child(enemy_label)

	status_label = _make_label(message, 25)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status_label.offset_left = -350
	status_label.offset_top = 75
	status_label.offset_right = 350
	status_label.offset_bottom = 112
	add_child(status_label)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 22)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 20
	controls.offset_top = -82
	controls.offset_right = -20
	controls.offset_bottom = -12
	add_child(controls)

	var normal := _make_button("FIRE  •  NORMAL", Color("#2878b9"))
	normal.pressed.connect(func(): _fire(false))
	controls.add_child(normal)
	var heavy := _make_button("HEAVY  •  POWER", Color("#b45309"))
	heavy.pressed.connect(func(): _fire(true))
	controls.add_child(heavy)
	var pause_button := _make_button("PAUSE", Color("#475569"))
	pause_button.pressed.connect(_toggle_pause)
	controls.add_child(pause_button)
	var reset_button := _make_button("RESTART", Color("#166534"))
	reset_button.pressed.connect(_new_game)
	controls.add_child(reset_button)

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
	button.custom_minimum_size = Vector2(210, 58)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(color))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.15)))
	return button

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style

func _new_game() -> void:
	blocks.clear()
	projectiles.clear()
	particles.clear()
	score = 0
	elapsed = 0.0
	enemy_cooldown = 2.5
	game_over = false
	paused = false
	message = "DESTROY THE ENEMY CASTLE!"
	_add_castle(95.0, "player")
	_add_castle(1010.0, "enemy")
	_update_hud()
	queue_redraw()

func _add_castle(origin_x: float, team: String) -> void:
	for row in range(5):
		for col in range(5):
			blocks.append({
				"rect": Rect2(origin_x + float(col) * 24.0, FLOOR_Y - 25.0 - float(row) * 25.0, 23.0, 24.0),
				"team": team,
				"hp": 2 if row == 4 else 1,
				"max_hp": 2 if row == 4 else 1
			})
	# Keep a tower cap and a small flag mast.
	blocks.append({"rect": Rect2(origin_x + 25.0, FLOOR_Y - 160.0, 72.0, 15.0), "team": team, "hp": 3, "max_hp": 3})
	blocks.append({"rect": Rect2(origin_x + 49.0, FLOOR_Y - 205.0, 22.0, 45.0), "team": team, "hp": 2, "max_hp": 2})

func _fire(heavy: bool) -> void:
	if game_over or paused:
		return
	var velocity := Vector2(17.0, -15.0) if not heavy else Vector2(15.5, -13.0)
	projectiles.append({
		"pos": PLAYER_CANNON + Vector2(12.0, -10.0),
		"vel": velocity,
		"power": 3 if heavy else 1,
		"team": "player",
		"radius": 12.0 if heavy else 8.0
	})
	message = "HEAVY SHOT!" if heavy else "FIRE!"
	_update_hud()

func _enemy_fire() -> void:
	if game_over:
		return
	projectiles.append({
		"pos": ENEMY_CANNON + Vector2(-12.0, -10.0),
		"vel": Vector2(-15.5, -14.0),
		"power": 1,
		"team": "enemy",
		"radius": 8.0
	})

func _toggle_pause() -> void:
	paused = not paused
	message = "PAUSED" if paused else "BATTLE RESUMED"
	_update_hud()

func _process(delta: float) -> void:
	if paused or game_over:
		return
	elapsed += delta
	enemy_cooldown -= delta
	if enemy_cooldown <= 0.0:
		_enemy_fire()
		enemy_cooldown = randf_range(3.0, 4.5)
	_step_projectiles(delta)
	_step_particles(delta)
	_check_winner()
	_update_hud()
	queue_redraw()

func _step_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var pos: Vector2 = shot["pos"]
		var vel: Vector2 = shot["vel"]
		vel.y += 25.0 * delta
		pos += vel * delta * 60.0
		shot["pos"] = pos
		shot["vel"] = vel
		var hit_index := -1
		for j in range(blocks.size()):
			var block: Dictionary = blocks[j]
			if block["team"] == shot["team"]:
				continue
			var rect: Rect2 = block["rect"]
			if rect.grow(float(shot["radius"]) * 0.45).has_point(pos):
				hit_index = j
				break
		if hit_index >= 0:
			var target: Dictionary = blocks[hit_index]
			_spawn_burst(pos, 9 if shot["power"] > 1 else 5)
			target["hp"] = int(target["hp"]) - int(shot["power"])
			if target["hp"] <= 0:
				blocks.remove_at(hit_index)
			if shot["team"] == "player":
				score += 15 * int(shot["power"])
			projectiles.remove_at(i)
		elif pos.x < -30.0 or pos.x > 1310.0 or pos.y > 590.0 or pos.y < -30.0:
			projectiles.remove_at(i)
		else:
			projectiles[i] = shot

func _spawn_burst(pos: Vector2, amount: int) -> void:
	for n in range(amount):
		particles.append({
			"pos": pos,
			"vel": Vector2(randf_range(-4.5, 4.5), randf_range(-7.0, 1.0)),
			"life": randf_range(0.35, 0.8),
			"size": randf_range(4.0, 9.0)
		})

func _step_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p["life"] = float(p["life"]) - delta
		var velocity: Vector2 = p["vel"]
		velocity.y += 18.0 * delta
		p["vel"] = velocity
		p["pos"] = (p["pos"] as Vector2) + velocity
		if float(p["life"]) <= 0.0:
			particles.remove_at(i)
		else:
			particles[i] = p

func _team_health(team: String) -> int:
	var total := 0
	for block in blocks:
		if block["team"] == team:
			total += int(block["hp"])
	return total

func _check_winner() -> void:
	if _team_health("enemy") <= 0:
		game_over = true
		message = "VICTORY! THE ENEMY CASTLE FELL!"
	elif _team_health("player") <= 0:
		game_over = true
		message = "DEFEAT! YOUR CASTLE WAS DESTROYED."

func _update_hud() -> void:
	if not is_instance_valid(score_label):
		return
	player_label.text = "YOUR CASTLE  %d%%" % roundi(float(_team_health("player")) / 60.0 * 100.0)
	enemy_label.text = "ENEMY CASTLE  %d%%" % roundi(float(_team_health("enemy")) / 60.0 * 100.0)
	score_label.text = "SCORE  %d" % score
	status_label.text = message

func _draw() -> void:
	var size := get_viewport_rect().size
	var sky := Color("#8bd0ef")
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	draw_circle(Vector2(1080.0, 125.0), 48.0, Color("#ffe58a"))
	for cloud_x in [100.0, 430.0, 780.0]:
		draw_circle(Vector2(cloud_x, 120.0), 25.0, Color("#f4fbff"))
		draw_circle(Vector2(cloud_x + 25.0, 110.0), 31.0, Color("#f4fbff"))
		draw_circle(Vector2(cloud_x + 52.0, 122.0), 23.0, Color("#f4fbff"))
	draw_rect(Rect2(0.0, FLOOR_Y, size.x, size.y - FLOOR_Y), Color("#77b957"))
	draw_rect(Rect2(0.0, FLOOR_Y + 14.0, size.x, 18.0), Color("#568b42"))
	# Distant hills
	draw_circle(Vector2(350.0, 575.0), 160.0, Color("#91c875"))
	draw_circle(Vector2(900.0, 580.0), 190.0, Color("#91c875"))
	for block in blocks:
		var rect: Rect2 = block["rect"]
		var team_color := Color("#c78b4c") if block["team"] == "player" else Color("#969eae")
		draw_rect(rect, team_color)
		draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 4)), team_color.lightened(0.35))
		draw_rect(rect, Color("#614c3b"), false, 2.0)
		if int(block["hp"]) > 1:
			draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 5), Vector2(rect.size.x - 8, 3)), Color("#6c302b"))
	# Cannons
	_draw_cannon(PLAYER_CANNON, Color("#245b8c"), false)
	_draw_cannon(ENEMY_CANNON, Color("#9c3434"), true)
	for shot in projectiles:
		var color := Color("#ed563b") if shot["team"] == "enemy" else Color("#27384b")
		draw_circle(shot["pos"], float(shot["radius"]), color)
		draw_circle(shot["pos"] + Vector2(-2, -2), float(shot["radius"]) * 0.35, Color("#f8d58a"))
	for p in particles:
		draw_rect(Rect2(p["pos"], Vector2.ONE * float(p["size"])), Color("#9a6842", clampf(float(p["life"]) * 2.0, 0.0, 1.0)))

func _draw_cannon(pos: Vector2, color: Color, flip: bool) -> void:
	draw_circle(pos + Vector2(0, 12), 24.0, Color("#364451"))
	var barrel := Rect2(pos.x - 5.0, pos.y - 16.0, 48.0, 17.0)
	if flip:
		barrel.position.x = pos.x - 43.0
	draw_rect(barrel, color)
	draw_rect(barrel, Color("#172b3b"), false, 3.0)
	draw_circle(pos, 20.0, color)
	draw_circle(pos, 9.0, Color("#172b3b"))
