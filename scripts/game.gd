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
var log_lines: Array[String] = []
var player_count := 8

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
	root_box = VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 14)
	root_box.add_theme_constant_override("margin_left", 24)
	root_box.add_theme_constant_override("margin_right", 24)
	root_box.add_theme_constant_override("margin_top", 28)
	root_box.add_theme_constant_override("margin_bottom", 24)
	add_child(root_box)
	var header := HBoxContainer.new()
	root_box.add_child(header)
	var title := Label.new()
	title.text = "🌙  LOUP GAROU"
	title.add_theme_font_size_override("font_size", 30)
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
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(status_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(scroll)
	log_label = Label.new()
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 18)
	scroll.add_child(log_label)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 10)
	root_box.add_child(action_box)

func _change_language(index: int) -> void:
	language = ["ar", "fr", "en"][index]
	if phase == "lobby":
		_show_lobby()
	else:
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
	b.add_theme_font_size_override("font_size", 19)
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
	log_lines.clear()
	log_lines.append(_tr("بدأت المباراة — دورك السري: ", "La partie commence — votre rôle secret : ", "The match begins — your secret role: ") + _role_name(players[0].role))
	_begin_night()

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
				protected_player = choices[randi() % choices.size()]
	if players[0].role != "witch":
		var witches := []
		for i in range(1, players.size()):
			if players[i].alive and players[i].role == "witch":
				witches.append(i)
		if not witches.is_empty() and attacked_player >= 0 and not witch_heal_used:
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
	for i in range(players.size()):
		if i == 0 or not players[i].alive:
			continue
		if kind == "wolf" and players[i].role == "werewolf":
			continue
		_button(str(players[i].name), func(): _night_target(kind, i))
	_button(_tr("رجوع", "Retour", "Back"), _begin_night)

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
			protected_player = index
			_finish_night()

func _witch_choices() -> void:
	_clear_actions()
	status_label.text = "🧪 " + _tr("الساحرة — لديك جرعتان طوال المباراة", "Sorcière — deux potions pour toute la partie", "Witch — two potions for the whole match")
	if attacked_player >= 0 and not witch_heal_used:
		_button(_tr("استخدم جرعة الشفاء", "Utiliser la potion de soin", "Use healing potion"), func():
			witch_heal_used = true
			attacked_player = -1
			_finish_night())
	if not witch_poison_used:
		_button(_tr("استخدم السم", "Utiliser le poison", "Use poison"), _show_poison_targets)
	_button(_tr("احتفظ بالجرعات", "Garder les potions", "Save potions"), _finish_night)

func _show_poison_targets() -> void:
	_clear_actions()
	for i in range(1, players.size()):
		if players[i].alive:
			_button(str(players[i].name), func():
				selected_player = i
				witch_poison_used = true
				_finish_night())

func _finish_night() -> void:
	var deaths: Array[int] = []
	if attacked_player >= 0 and attacked_player != protected_player:
		deaths.append(attacked_player)
	if selected_player >= 0 and selected_player != 0 and not deaths.has(selected_player):
		deaths.append(selected_player)
	for victim in deaths:
		if players[victim].alive:
			players[victim].alive = false
			log_lines.append("☠ " + str(players[victim].name) + " " + _tr("قُتل أثناء الليل", "a été éliminé cette nuit", "was killed tonight"))
			if players[victim].role == "hunter":
				hunter_pending = victim
	if hunter_pending >= 0:
		_hunter_revenge()
		return
	_check_winner()
	if phase != "finished":
		_begin_day()

func _hunter_revenge() -> void:
	phase = "hunter"
	_clear_actions()
	status_label.text = "🎯 " + _tr("الصياد قبل رحيله يختار من يأخذه معه", "Le chasseur choisit une dernière cible", "The hunter chooses one final target")
	for i in range(players.size()):
		if i != hunter_pending and players[i].alive:
			_button(str(players[i].name), func():
				players[i].alive = false
				log_lines.append("🎯 " + str(players[i].name) + " " + _tr("أُصيب برصاصة الصياد", "a été touché par le chasseur", "was shot by the hunter"))
				hunter_pending = -1
				_check_winner()
				if phase != "finished":
					_begin_day())

func _begin_day() -> void:
	phase = "day"
	_refresh()
	_clear_actions()
	status_label.text = "☀️ " + _tr("الصباح — ناقشوا وصوّتوا", "Le jour — débattez et votez", "Day — discuss and vote")
	_button(_tr("ابدأ التصويت", "Lancer le vote", "Start voting"), _show_vote_targets)

func _show_vote_targets() -> void:
	_clear_actions()
	for i in range(players.size()):
		if i != 0 and players[i].alive:
			_button(_tr("صوّت ضد ", "Voter contre ", "Vote against ") + str(players[i].name), func(): _cast_vote(i))

func _cast_vote(target: int) -> void:
	var votes: Dictionary = {target: 1}
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
			for option in options:
				if players[option].role != "werewolf":
					choice = option
					break
		votes[choice] = int(votes.get(choice, 0)) + 1
	var eliminated := target
	var highest := -1
	for key in votes:
		if int(votes[key]) > highest:
			highest = int(votes[key])
			eliminated = int(key)
	players[eliminated].alive = false
	log_lines.append("⚖ " + str(players[eliminated].name) + " " + _tr("أُخرج بالتصويت", "a été éliminé par vote", "was voted out"))
	if players[eliminated].role == "hunter":
		hunter_pending = eliminated
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
	_button(_tr("العودة للقائمة", "Retour au menu", "Back to menu"), _show_lobby)
	return true

func _refresh() -> void:
	var lines := log_lines.duplicate()
	lines.append("")
	lines.append(_tr("اللاعبون الأحياء:", "Joueurs en vie :", "Players alive:"))
	for p in players:
		if p.alive:
			lines.append("• " + str(p.name) + ("  ★" if p.human else ""))
	log_label.text = "\n".join(lines)
