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

var root_box: VBoxContainer
var status_label: Label
var log_label: Label
var action_box: VBoxContainer

func _ready() -> void:
	randomize()
	_build_shell()
	_show_lobby()

func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#101522")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 22)
	frame.add_theme_constant_override("margin_right", 22)
	frame.add_theme_constant_override("margin_top", 24)
	frame.add_theme_constant_override("margin_bottom", 22)
	add_child(frame)
	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 14)
	root_box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	frame.add_child(root_box)
	var header := HBoxContainer.new()
	root_box.add_child(header)
	var title := Label.new()
	title.text = "🌙  LOUP GAROU"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#f4c96b"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var lang := OptionButton.new()
	lang.add_item("العربية", 0)
	lang.add_item("Français", 1)
	lang.add_item("English", 2)
	lang.item_selected.connect(_change_language)
	header.add_child(lang)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color("#f4c96b"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(status_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(scroll)
	log_label = Label.new()
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 17)
	log_label.add_theme_color_override("font_color", Color("#e5eaf4"))
	scroll.add_child(log_label)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 10)
	root_box.add_child(action_box)

func _change_language(index: int) -> void:
	language = ["ar", "fr", "en"][index]
	root_box.layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	match phase:
		"lobby":
			_show_lobby()
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
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color("#f4f6fb"))
	b.add_theme_color_override("font_hover_color", Color("#101522"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#27344a")
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color("#465875")
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#f4c96b")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(callback)
	action_box.add_child(b)

func _clear_actions() -> void:
	for child in action_box.get_children():
		child.queue_free()

func _show_lobby() -> void:
	phase = "lobby"
	status_label.text = _tr("قرية غامضة تنتظر شجاعتك", "Un village mystérieux vous attend", "A mysterious village awaits you")
	log_label.text = _tr("اختر عدد المقاعد. ستلعب بشخصيتك ضد سكان القرية الذين يتحكم بهم الذكاء الاصطناعي.", "Choisissez le nombre de joueurs. Affrontez les habitants contrôlés par l'IA.", "Choose the player count and face AI-controlled villagers.")
	_clear_actions()
	for count in [6, 7, 8, 9, 10]:
		_button(str(count) + " " + _tr("لاعبين — أوفلاين", "joueurs — hors ligne", "players — offline"), func(): _start_offline(count))
	_button(_tr("دليل الأدوار والقواعد", "Guide des rôles et des règles", "Roles and rules guide"), _show_role_guide)

func _show_role_guide() -> void:
	phase = "guide"
	status_label.text = "📖 " + _tr("دليل القرية", "Guide du village", "Village guide")
	var entries: Array[String] = []
	for role in ["werewolf", "seer", "witch", "guard", "hunter", "villager"]:
		entries.append("◆ " + _role_name(role) + "\n" + _role_description(role))
	log_label.text = "\n\n".join(PackedStringArray(entries))
	_clear_actions()
	_button(_tr("العودة للقائمة", "Retour au menu", "Back to menu"), _show_lobby)

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
			targets.erase(0)
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
