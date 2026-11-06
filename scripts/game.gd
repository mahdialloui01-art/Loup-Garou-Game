extends Control

const ROLE_DATA := {
	"werewolf": {"ar": "مستذئب", "fr": "Loup-garou", "en": "Werewolf", "team": "wolves"},
	"seer": {"ar": "العراف", "fr": "Voyant", "en": "Seer", "team": "village"},
	"witch": {"ar": "الساحرة", "fr": "Sorcière", "en": "Witch", "team": "village"},
	"hunter": {"ar": "الصياد", "fr": "Chasseur", "en": "Hunter", "team": "village"},
	"guard": {"ar": "الحارس", "fr": "Garde", "en": "Guard", "team": "village"},
	"villager": {"ar": "قروي", "fr": "Villageois", "en": "Villager", "team": "village"}
}
const ROLE_COUNTS := {
	6: ["werewolf", "seer", "witch", "hunter", "villager", "villager"],
	7: ["werewolf", "werewolf", "seer", "witch", "guard", "hunter", "villager"],
	8: ["werewolf", "werewolf", "seer", "witch", "guard", "hunter", "villager", "villager"],
	9: ["werewolf", "werewolf", "seer", "witch", "guard", "hunter", "villager", "villager", "villager"],
	10: ["werewolf", "werewolf", "werewolf", "seer", "witch", "guard", "hunter", "villager", "villager", "villager"]
}

var players: Array[Dictionary] = []
var language := "ar"
var phase := "lobby"
var round_number := 0
var selected_player := -1
var protected_player := -1
var attacked_player := -1
var witch_heal_used := true
var witch_poison_used := true
var hunter_pending := -1
var hunter_return_to_night := false
var log_lines: Array[String] = []
var player_count := 8
var last_guard_target := -1
var music_player: AudioStreamPlayer
var music_enabled := true
var music_volume := 0.55
var settings := ConfigFile.new()

var root_box: VBoxContainer
var status_label: Label
var log_label: Label
var action_box: VBoxContainer

func _ready() -> void:
	randomize()
	_build_shell()
	_load_settings()
	_setup_ambience()
	_show_home()

func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#090e1b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sky_shader := Shader.new()
	sky_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 sky = mix(vec3(0.025, 0.045, 0.085), vec3(0.12, 0.16, 0.23), smoothstep(0.0, 0.9, uv.y));
	vec2 moon_uv = uv - vec2(0.78, 0.19);
	moon_uv.x *= 0.72;
	float moon_d = length(moon_uv);
	float moon = 1.0 - smoothstep(0.105, 0.118, moon_d);
	float halo = 1.0 - smoothstep(0.11, 0.42, moon_d);
	sky += vec3(0.88, 0.72, 0.48) * moon * 0.92;
	sky += vec3(0.42, 0.35, 0.26) * halo * 0.18;
	vec2 cell = floor(uv * vec2(72.0, 128.0));
	float star_hash = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float stars = step(0.992, star_hash) * (0.35 + 0.65 * sin(TIME * (1.0 + star_hash * 2.0) + star_hash * 30.0));
	sky += vec3(0.72, 0.79, 0.92) * stars * (1.0 - smoothstep(0.2, 0.95, uv.y)) * 0.7;
	float mist_a = sin(uv.x * 8.0 + TIME * 0.12 + uv.y * 5.0);
	float mist_b = sin(uv.x * 13.0 - TIME * 0.08 + uv.y * 8.0);
	float mist = smoothstep(0.18, 0.95, mist_a * 0.5 + mist_b * 0.5) * smoothstep(0.48, 0.92, uv.y);
	sky = mix(sky, vec3(0.22, 0.29, 0.37), mist * 0.16);
	float vignette = smoothstep(0.95, 0.18, length((uv - 0.5) * vec2(0.8, 1.0)));
	sky *= 0.72 + vignette * 0.28;
	COLOR = vec4(sky, 1.0);
}
"""
	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	bg.material = sky_material
	add_child(bg)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 18)
	frame.add_theme_constant_override("margin_right", 18)
	frame.add_theme_constant_override("margin_top", 18)
	frame.add_theme_constant_override("margin_bottom", 18)
	add_child(frame)
	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	root_box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	frame.add_child(root_box)
	var header := HBoxContainer.new()
	root_box.add_child(header)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	var title := Label.new()
	title.text = "LOUP GAROU"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#f4d58a"))
	brand.add_child(title)
	var subtitle := Label.new()
	subtitle.text = _tr("أسطورة القرية", "LA LÉGENDE DU VILLAGE", "THE VILLAGE LEGEND")
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color("#8fa2c4"))
	brand.add_child(subtitle)
	var lang := OptionButton.new()
	lang.add_item("العربية", 0)
	lang.add_item("Français", 1)
	lang.add_item("English", 2)
	lang.custom_minimum_size = Vector2(104, 42)
	lang.item_selected.connect(_change_language)
	header.add_child(lang)
	var accent := ColorRect.new()
	accent.color = Color("#c99b52")
	accent.custom_minimum_size = Vector2(0, 2)
	root_box.add_child(accent)
	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#17243a"), Color("#354865"), 18))
	root_box.add_child(status_panel)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 48)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color("#f5d99c"))
	status_panel.add_child(status_label)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#111a2b"), Color("#263852"), 20))
	root_box.add_child(panel)
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 15)
	inner.add_theme_constant_override("margin_right", 15)
	inner.add_theme_constant_override("margin_top", 14)
	inner.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(inner)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	inner.add_child(content)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	log_label = Label.new()
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 16)
	log_label.add_theme_color_override("font_color", Color("#e2e9f5"))
	log_label.add_theme_constant_override("line_spacing", 5)
	scroll.add_child(log_label)
	var actions_scroll := ScrollContainer.new()
	actions_scroll.custom_minimum_size = Vector2(0, 205)
	actions_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(actions_scroll)
	action_box = VBoxContainer.new()
	action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_box.add_theme_constant_override("separation", 9)
	actions_scroll.add_child(action_box)

func _make_panel_style(fill: Color, outline: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _change_language(index: int) -> void:
	language = ["ar", "fr", "en"][index]
	root_box.layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	match phase:
		"home":
			_show_home()
		"lobby":
			_show_lobby()
		"settings":
			_show_settings()
		"guide":
			_show_role_guide()
		"reveal":
			_show_role_reveal()
		"night":
			_render_night_actions()
		"day":
			_begin_day()
		"hunter":
			_hunter_revenge()
		"finished":
			_check_winner()
		_:
			_refresh()

func _tr(ar: String, fr: String, en: String) -> String:
	match language:
		"fr": return fr
		"en": return en
		_: return ar

func _button(caption: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color("#f5f7fc"))
	b.add_theme_color_override("font_hover_color", Color("#101827"))
	b.add_theme_color_override("font_pressed_color", Color("#101827"))
	var normal := _make_panel_style(Color("#243650"), Color("#3d5575"), 16)
	var hover := _make_panel_style(Color("#d4aa65"), Color("#f0d39c"), 16)
	var pressed := _make_panel_style(Color("#b88b4b"), Color("#e7c58a"), 16)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(callback)
	action_box.add_child(b)

func _clear_actions() -> void:
	for child in action_box.get_children():
		child.queue_free()


func _show_home() -> void:
	phase = "home"
	status_label.text = _tr("🌕  حين يكتمل القمر… تبدأ الحكاية", "🌕  Quand la lune se lève… le jeu commence", "🌕  When the moon rises… the story begins")
	log_label.text = "                         ☾\n\n" + _tr("لــــوب غــــارو", "LOUP GAROU", "LOUP GAROU") + "\n" + _tr("أسطورة القرية المنسية", "La légende du village oublié", "LEGEND OF THE FORGOTTEN VILLAGE") + "\n\n" + _tr("في قرية يلفّها الضباب، تختبئ الذئاب بين الوجوه…\nهل تكتشف الحقيقة قبل فوات الأوان؟", "Dans un village noyé de brume, les loups se cachent parmi les villageois…\nSaurez-vous découvrir la vérité ?", "In a village wrapped in mist, wolves hide among familiar faces…\nCan you uncover the truth before dawn?") + "\n\n" + _tr("✦  تجربة غامرة • لعب فردي ضد الذكاء الاصطناعي  ✦", "✦  Ambiance immersive • Solo contre l’IA  ✦", "✦  Immersive atmosphere • Solo vs AI  ✦")
	_clear_actions()
	_button(_tr("▶  ادخل إلى القرية", "▶  Entrer dans le village", "▶  Enter the village"), _show_lobby)
	_button(_tr("⚙  الإعدادات", "⚙  Paramètres", "⚙  Settings"), _show_settings)
	_button(_tr("📖  دليل الأدوار", "📖  Guide des rôles", "📖  Role guide"), _show_role_guide)
	var pulse := create_tween().set_loops()
	pulse.tween_property(status_label, "modulate:a", 0.72, 1.4)
	pulse.tween_property(status_label, "modulate:a", 1.0, 1.4)

func _show_settings() -> void:
	phase = "settings"
	status_label.text = "⚙  " + _tr("إعدادات التجربة", "Paramètres", "Game settings")
	log_label.text = _tr("اضبط أجواء القرية كما تحب. الموسيقى لحن غامض هادئ صُنع داخل اللعبة.", "Personnalisez l’ambiance du village. La musique est une nappe mystérieuse générée dans le jeu.", "Tune the village atmosphere. The eerie ambient soundtrack is generated in-game.")
	_clear_actions()
	var music_toggle := CheckButton.new()
	music_toggle.text = _tr("الموسيقى والأجواء", "Musique et ambiance", "Ambient music")
	music_toggle.button_pressed = music_enabled
	music_toggle.add_theme_font_size_override("font_size", 17)
	music_toggle.toggled.connect(_set_music_enabled)
	action_box.add_child(music_toggle)
	var volume_label := Label.new()
	volume_label.text = _tr("مستوى الصوت", "Volume", "Music volume")
	volume_label.add_theme_color_override("font_color", Color("#f0d39c"))
	action_box.add_child(volume_label)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = music_volume
	volume.custom_minimum_size = Vector2(0, 42)
	volume.value_changed.connect(_set_music_volume)
	action_box.add_child(volume)
	_button(_tr("حفظ والعودة", "Enregistrer et revenir", "Save and return"), _show_home)

func _load_settings() -> void:
	settings.load("user://loup_settings.cfg")
	music_enabled = bool(settings.get_value("audio", "music_enabled", true))
	music_volume = float(settings.get_value("audio", "music_volume", 0.55))

func _save_settings() -> void:
	settings.set_value("audio", "music_enabled", music_enabled)
	settings.set_value("audio", "music_volume", music_volume)
	settings.save("user://loup_settings.cfg")

func _setup_ambience() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "VillageAmbience"
	add_child(music_player)
	music_player.stream = _make_ambient_track()
	music_player.volume_db = linear_to_db(maxf(music_volume, 0.001))
	if music_enabled:
		music_player.play()

func _make_ambient_track() -> AudioStreamWAV:
	var rate := 11025
	var seconds := 12
	var count := rate * seconds
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(rate)
		var fade := minf(1.0, minf(t / 1.2, (float(seconds) - t) / 1.2))
		var drone := sin(TAU * 55.0 * t) * 0.12 + sin(TAU * 82.4 * t) * 0.055 + sin(TAU * 110.0 * t) * 0.035
		var shimmer := sin(TAU * 220.0 * t + sin(TAU * 0.09 * t) * 2.0) * 0.018
		var bell_env := pow(maxf(0.0, sin(TAU * 0.083 * t)), 10.0)
		var bell := sin(TAU * 392.0 * t) * bell_env * 0.045
		var sample := clampf((drone + shimmer + bell) * fade, -0.95, 0.95)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav

func _set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if enabled:
		if music_player and not music_player.playing:
			music_player.play()
	else:
		if music_player:
			music_player.stop()
	_save_settings()

func _set_music_volume(value: float) -> void:
	music_volume = value
	if music_player:
		music_player.volume_db = linear_to_db(maxf(value, 0.001))
	_save_settings()

func _show_lobby() -> void:
	phase = "lobby"
	status_label.text = _tr("قرية غامضة تنتظر شجاعتك", "Un village mystérieux vous attend", "A mysterious village awaits you")
	log_label.text = _tr("لعبة أوفلاين ضد الذكاء الاصطناعي. اختر عدد اللاعبين وابدأ مغامرتك.\n\nلا يوجد طور أونلاين حالياً؛ لن نظهره كميزة متاحة قبل بناء لعب جماعي حقيقي.", "Mode hors ligne contre l’intelligence artificielle. Le multijoueur en ligne n’est pas encore disponible.", "Offline game against AI. Online multiplayer is not available yet.")
	_clear_actions()
	for count in [6, 7, 8, 9, 10]:
		_button(str(count) + " " + _tr("لاعبين — أوفلاين", "joueurs — hors ligne", "players — offline"), func(): _start_offline(count))
	_button(_tr("دليل الأدوار والقواعد", "Guide des rôles et des règles", "Roles and rules guide"), _show_role_guide)
	_button(_tr("العودة للشاشة الرئيسية", "Retour à l’accueil", "Back to title screen"), _show_home)

func _show_role_guide() -> void:
	phase = "guide"
	status_label.text = "📖 " + _tr("دليل القرية", "Guide du village", "Village guide")
	var entries: Array[String] = []
	for role in ["werewolf", "seer", "witch", "guard", "hunter", "villager"]:
		entries.append("◆ " + _role_name(role) + "\n" + _role_description(role))
	log_label.text = "\n\n".join(PackedStringArray(entries))
	_clear_actions()
	_button(_tr("العودة للشاشة الرئيسية", "Retour à l’accueil", "Back to title screen"), _show_home)

func _start_offline(count: int) -> void:
	player_count = count
	players.clear()
	var roles: Array = ROLE_COUNTS[count].duplicate()
	roles.shuffle()
	for i in range(count):
		players.append({
			"name": _tr("أنت", "Vous", "You") if i == 0 else _tr("لاعب", "Joueur", "Player") + " " + str(i + 1),
			"role": roles[i],
			"alive": true,
			"human": i == 0
		})
	round_number = 1
	selected_player = -1
	protected_player = -1
	attacked_player = -1
	hunter_pending = -1
	hunter_return_to_night = false
	witch_heal_used = false
	witch_poison_used = false
	last_guard_target = -1
	log_lines.clear()
	log_lines.append(_tr("بدأت المباراة — دورك السري: ", "La partie commence — votre rôle secret : ", "The match begins — your secret role: ") + _role_name(players[0].role))
	_show_role_reveal()

func _role_description(role: String) -> String:
	match role:
		"werewolf":
			return _tr("استيقظ كل ليلة واختر لاعباً لإقصائه مع فريق الذئاب.", "Chaque nuit, choisissez une victime avec les loups.", "Each night, choose a victim with the wolves.")
		"seer":
			return _tr("افحص لاعباً كل ليلة لتعرف هل هو مستذئب أم لا.", "Chaque nuit, découvrez si un joueur est un loup-garou.", "Each night, learn whether one player is a werewolf.")
		"witch":
			return _tr("تملك جرعة شفاء واحدة وجرعة سم واحدة طوال المباراة.", "Vous avez une potion de soin et une potion de poison pour toute la partie.", "You have one healing potion and one poison potion for the whole match.")
		"guard":
			return _tr("احمِ لاعباً كل ليلة. لا يمكنك حماية نفس اللاعب ليلتين متتاليتين.", "Protégez un joueur chaque nuit. Pas deux nuits de suite la même personne.", "Protect one player each night. You cannot protect the same player on consecutive nights.")
		"hunter":
			return _tr("إذا أُقصيت، اختر لاعباً واحداً ليخرج معك.", "Si vous êtes éliminé, choisissez un joueur à emporter.", "If eliminated, choose one player to take down with you.")
		_:
			return _tr("راقب تصرفات الآخرين، ناقشهم وصوّت لإخراج المستذئبين.", "Observez les autres, débattez et votez pour éliminer les loups.", "Watch the others, discuss and vote to eliminate the werewolves.")

func _show_role_reveal() -> void:
	phase = "reveal"
	_clear_actions()
	status_label.text = "🃏 " + _tr("دورك السري", "Votre rôle secret", "Your secret role")
	var briefing := "━━━━━━━━━━━━━━━━━━━━\n" + _role_name(players[0].role) + "\n\n" + _role_description(players[0].role)
	if players[0].role == "werewolf":
		var allies: Array[String] = []
		for i in range(1, players.size()):
			if players[i].alive and players[i].role == "werewolf":
				allies.append(str(players[i].name))
		if not allies.is_empty():
			briefing += "\n\n🐺 " + _tr("حلفاؤك من الذئاب: ", "Vos alliés loups : ", "Your fellow werewolves: ") + ", ".join(PackedStringArray(allies))
	briefing += "\n\n" + _tr("لا تكشف دورك للآخرين!", "Ne révélez pas votre rôle !", "Keep your role secret!") + "\n━━━━━━━━━━━━━━━━━━━━"
	log_label.text = briefing
	_button(_tr("ابدأ الليلة الأولى", "Commencer la première nuit", "Begin the first night"), _begin_night)

func _role_name(role: String) -> String:
	return str(ROLE_DATA[role][language])

func _alive_indices() -> Array[int]:
	var result: Array[int] = []
	for i in range(players.size()):
		if players[i].alive:
			result.append(i)
	return result

func _begin_night() -> void:
	phase = "night"
	selected_player = -1
	protected_player = -1
	attacked_player = -1
	_run_ai_night()
	_refresh()
	_render_night_actions()

func _render_night_actions() -> void:
	_clear_actions()
	status_label.text = "🌑 " + _tr("الليلة رقم ", "Nuit numéro ", "Night ") + str(round_number)
	var role: String = players[0].role
	if role == "werewolf":
		status_label.text += " — " + _tr("فريق الذئاب: اختر ضحية", "Choisissez une victime", "Choose a victim")
		_show_targets("wolf")
	elif role == "seer":
		status_label.text += " — " + _tr("اكشف حقيقة لاعب", "Inspectez un joueur", "Inspect a player")
		_show_targets("seer")
	elif role == "guard":
		status_label.text += " — " + _tr("احمِ لاعباً هذه الليلة", "Protégez un joueur", "Protect a player")
		_show_targets("guard")
	elif role == "witch":
		_witch_choices()
	else:
		_button(_tr("انتظر طلوع النهار", "Attendre le matin", "Wait for sunrise"), _finish_night)

func _run_ai_night() -> void:
	var wolf_targets: Array[int] = []
	for i in range(1, players.size()):
		if players[i].alive and players[i].role == "werewolf":
			for candidate in range(players.size()):
				if candidate != i and players[candidate].alive and players[candidate].role != "werewolf":
					wolf_targets.append(candidate)
	if not wolf_targets.is_empty():
		attacked_player = wolf_targets[randi() % wolf_targets.size()]
	if players[0].role != "guard":
		var guards := []
		for i in range(1, players.size()):
			if players[i].alive and players[i].role == "guard":
				guards.append(i)
		if not guards.is_empty():
			var choices := _alive_indices()
			if choices.size() > 1:
				choices.erase(last_guard_target)
				if not choices.is_empty():
					protected_player = choices[randi() % choices.size()]
					last_guard_target = protected_player
	if players[0].role != "witch":
		var witches := []
		for i in range(1, players.size()):
			if players[i].alive and players[i].role == "witch":
				witches.append(i)
		if not witches.is_empty() and attacked_player >= 0 and attacked_player != protected_player and not witch_heal_used:
			if randf() < 0.55:
				attacked_player = -1
				witch_heal_used = true
		if not witches.is_empty() and not witch_poison_used and randf() < 0.12:
			var targets := _alive_indices()
			if not targets.is_empty():
				selected_player = targets[randi() % targets.size()]
				witch_poison_used = true

func _show_targets(kind: String) -> void:
	_clear_actions()
	if kind == "guard" and players[0].alive:
		_button(_tr("احمِ نفسك", "Se protéger", "Protect yourself"), func(): _night_target("guard", 0))
	for i in range(players.size()):
		if i == 0 or not players[i].alive:
			continue
		if kind == "wolf" and players[i].role == "werewolf":
			continue
		_button(str(players[i].name), func(): _night_target(kind, i))

func _night_target(kind: String, index: int) -> void:
	match kind:
		"wolf":
			attacked_player = index
			_finish_night()
		"seer":
			var result := _tr("مستذئب", "est un loup-garou", "is a werewolf") if players[index].role == "werewolf" else _tr("ليس مستذئباً", "n'est pas un loup-garou", "is not a werewolf")
			log_lines.append("🔮 " + str(players[index].name) + " " + result)
			_finish_night()
		"guard":
			if index == last_guard_target:
				log_lines.append(_tr("لا يمكنك حماية نفس اللاعب ليلتين متتاليتين.", "Vous ne pouvez pas protéger la même personne deux nuits de suite.", "You cannot protect the same player two nights in a row."))
				_show_targets("guard")
				return
			protected_player = index
			last_guard_target = index
			_finish_night()

func _witch_choices() -> void:
	_clear_actions()
	status_label.text = "🧪 " + _tr("الساحرة — لديك جرعتان طوال المباراة", "Sorcière — deux potions pour toute la partie", "Witch — two potions for the whole match")
	if attacked_player >= 0 and attacked_player != protected_player and not witch_heal_used:
		_button(_tr("استخدم جرعة الشفاء", "Utiliser la potion de soin", "Use healing potion"), func():
			witch_heal_used = true
			attacked_player = -1
			_witch_choices())
	if not witch_poison_used:
		_button(_tr("استخدم السم", "Utiliser le poison", "Use poison"), _show_poison_targets)
	_button(_tr("إنهاء دور الساحرة", "Terminer le tour de la sorcière", "Finish witch turn"), _finish_night)

func _show_poison_targets() -> void:
	_clear_actions()
	status_label.text = "☠ " + _tr("اختر هدف جرعة السم", "Choisissez la cible du poison", "Choose a poison target")
	for i in range(1, players.size()):
		if players[i].alive:
			_button(str(players[i].name), func():
				selected_player = i
				witch_poison_used = true
				_witch_choices())
	_button(_tr("رجوع", "Retour", "Back"), _witch_choices)

func _finish_night() -> void:
	var deaths: Array[int] = []
	if attacked_player >= 0 and attacked_player != protected_player:
		deaths.append(attacked_player)
	if selected_player >= 0 and selected_player != 0 and not deaths.has(selected_player):
		deaths.append(selected_player)
	for victim in deaths:
		if players[victim].alive:
			players[victim].alive = false
			log_lines.append("☠ " + str(players[victim].name) + " " + _tr("قُتل أثناء الليل — دوره: ", "a été éliminé cette nuit — rôle : ", "was killed tonight — role: ") + _role_name(players[victim].role))
			if players[victim].role == "hunter":
				hunter_pending = victim
	if hunter_pending >= 0:
		hunter_return_to_night = false
		_hunter_revenge()
		return
	_check_winner()
	if phase != "finished":
		_begin_day()

func _hunter_revenge() -> void:
	phase = "hunter"
	_clear_actions()
	status_label.text = "🎯 " + _tr("الصياد قبل رحيله يختار من يأخذه معه", "Le chasseur choisit une dernière cible", "The hunter chooses one final target")
	var available_targets := 0
	for i in range(players.size()):
		if i != hunter_pending and players[i].alive:
			available_targets += 1
			_button(str(players[i].name), func():
				players[i].alive = false
				log_lines.append("🎯 " + str(players[i].name) + " " + _tr("أُصيب برصاصة الصياد — دوره: ", "a été touché par le chasseur — rôle : ", "was shot by the hunter — role: ") + _role_name(players[i].role))
				hunter_pending = -1
				_check_winner()
				if phase != "finished":
					if hunter_return_to_night:
						hunter_return_to_night = false
						round_number += 1
						_begin_night()
					else:
						_begin_day()
			)
	if available_targets == 0:
		hunter_pending = -1
		_check_winner()

func _begin_day() -> void:
	phase = "day"
	_refresh()
	_clear_actions()
	status_label.text = "☀️ " + _tr("الصباح — ناقشوا وصوّتوا", "Le jour — débattez et votez", "Day — discuss and vote")
	if players[0].alive:
		_button(_tr("ابدأ التصويت", "Lancer le vote", "Start voting"), _show_vote_targets)
	else:
		status_label.text += " — " + _tr("أنت متفرج بعد خروجك", "Vous observez après votre élimination", "You are spectating after elimination")
		_button(_tr("تابع تصويت القرية", "Continuer le vote du village", "Continue village vote"), _cast_spectator_vote)

func _show_vote_targets() -> void:
	_clear_actions()
	for i in range(players.size()):
		if i != 0 and players[i].alive:
			_button(_tr("صوّت ضد ", "Voter contre ", "Vote against ") + str(players[i].name), func(): _cast_vote(i))

func _cast_spectator_vote() -> void:
	_cast_vote(-1)

func _cast_vote(target: int) -> void:
	var votes: Dictionary = {}
	if target >= 0:
		votes[target] = 1
	for i in range(1, players.size()):
		if not players[i].alive:
			continue
		var options: Array[int] = []
		for j in range(players.size()):
			if j != i and players[j].alive:
				options.append(j)
		if options.is_empty():
			continue
		var choice := options[randi() % options.size()]
		if players[i].role == "werewolf":
			var village_options: Array[int] = []
			for option in options:
				if players[option].role != "werewolf":
					village_options.append(option)
			if not village_options.is_empty():
				choice = village_options[randi() % village_options.size()]
		votes[choice] = int(votes.get(choice, 0)) + 1
	if votes.is_empty():
		return
	var highest := -1
	var leaders: Array[int] = []
	for key in votes:
		var count := int(votes[key])
		if count > highest:
			highest = count
			leaders = [int(key)]
		elif count == highest:
			leaders.append(int(key))
	if leaders.size() > 1:
		log_lines.append("🤝 " + _tr("تعادل في الأصوات — تم كسر التعادل عشوائياً.", "Égalité des votes — départage aléatoire.", "Vote tied — a random tie-break was used."))
	for key in votes:
		log_lines.append("🗳 " + str(players[int(key)].name) + ": " + str(votes[key]) + " " + _tr("صوت", "voix", "votes"))
	var eliminated := leaders[randi() % leaders.size()]
	players[eliminated].alive = false
	log_lines.append("⚖ " + str(players[eliminated].name) + " " + _tr("أُخرج بالتصويت — دوره: ", "a été éliminé par vote — rôle : ", "was voted out — role: ") + _role_name(players[eliminated].role))
	if players[eliminated].role == "hunter":
		hunter_pending = eliminated
		hunter_return_to_night = true
		_hunter_revenge()
		return
	_check_winner()
	if phase != "finished":
		round_number += 1
		_begin_night()

func _check_winner() -> bool:
	var wolves := 0
	var village := 0
	for p in players:
		if p.alive:
			if p.role == "werewolf":
				wolves += 1
			else:
				village += 1
	if wolves == 0:
		phase = "finished"
		status_label.text = "🏆 " + _tr("فاز أهل القرية!", "Le village a gagné !", "The village wins!")
	elif wolves >= village:
		phase = "finished"
		status_label.text = "🐺 " + _tr("فاز المستذئبون!", "Les loups ont gagné !", "The werewolves win!")
	else:
		return false
	_refresh()
	_clear_actions()
	_button(_tr("مباراة جديدة بنفس العدد", "Nouvelle partie avec le même nombre", "New match with same player count"), func(): _start_offline(player_count))
	_button(_tr("العودة للقائمة", "Retour au menu", "Back to menu"), _show_lobby)
	return true

func _refresh() -> void:
	var lines := log_lines.duplicate()
	lines.append("")
	lines.append(_tr("اللاعبون:", "Joueurs :", "Players:"))
	for p in players:
		var marker := "🟢 " if p.alive else "⚫ "
		lines.append(marker + str(p.name) + ("  ★" if p.human else "") + ("" if p.alive else " — " + _tr("مُقصى", "éliminé", "eliminated")))
	log_label.text = "\n".join(PackedStringArray(lines))
