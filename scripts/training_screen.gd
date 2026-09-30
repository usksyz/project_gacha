class_name TrainingScreen
extends Control
## Terrain d'entraînement (ouvert depuis le hub).
## On y envoie des héros travailler une compétence : Maîtrise de l'épée ou Utilisation du bouclier.
## Chaque séance (quelques minutes de temps réel, même jeu fermé) leur donne des points de progrès ;
## à 100 points, ils apprennent la compétence ou gagnent un niveau. Les règles sont dans GameData.

## Texte court de chaque programme, pour les boutons.
const PROGRAM_LABELS := {
	"Maîtrise de l'épée": "Épée",
	"Utilisation du bouclier": "Bouclier",
}

## Demande à l'écran principal d'afficher un autre écran (retour au hub).
signal navigate(screen_name: String)

var slots_label: Label
var news_box: VBoxContainer
var list: VBoxContainer
## Étiquette de suivi de chaque héros (id -> Label), mise à jour chaque seconde.
var status_labels := {}


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var back := UI.make_button("← Retour à la cité", func(): navigate.emit("hub"), 22)
	back.custom_minimum_size.y = 64
	layout.add_child(back)

	slots_label = UI.make_label("", 26)
	slots_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(slots_label)
	var rules := UI.make_label("Une séance toutes les %d minutes, même quand le jeu est fermé. L'entraînement donne des compétences, pas de niveaux. Un héros qui monte dans la Tour le reprend après l'étage." \
		% (GameData.TRAINING_SESSION_SECONDS / 60), 20)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.modulate = Color(1, 1, 1, 0.7)
	layout.add_child(rules)

	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	news_box = VBoxContainer.new()
	news_box.add_theme_constant_override("separation", 8)
	content.add_child(news_box)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	content.add_child(list)

	# Chaque seconde : compte à rebours des séances. Quand une séance se termine,
	# GameData prévient (training_updated) et on redessine l'écran.
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_tick)
	add_child(timer)
	timer.start()
	GameData.training_updated.connect(func():
		if is_visible_in_tree():
			_refresh())


func on_shown() -> void:
	GameData.update_training()
	_refresh()


func _tick() -> void:
	if not is_visible_in_tree():
		return
	GameData.update_training()
	for hero in GameData.alive_heroes():
		if status_labels.has(hero["id"]):
			status_labels[hero["id"]].text = _status_text(hero)


## Reconstruit tout l'écran : nouveautés, puis une carte par héros vivant.
func _refresh() -> void:
	for box in [news_box, list]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	status_labels.clear()

	if not GameData.training_news.is_empty():
		news_box.add_child(UI.make_system_window("Entraînement terminé !", GameData.training_news))
		var ok := UI.make_button("Compris", _clear_news, 22)
		ok.custom_minimum_size.y = 70
		news_box.add_child(ok)

	slots_label.text = "Places occupées : %d / %d" % [GameData.trainees().size(), GameData.TRAINING_SLOTS]
	for hero in GameData.alive_heroes():
		list.add_child(_make_hero_row(hero))


## Le joueur a lu les nouveautés : on les efface.
func _clear_news() -> void:
	GameData.training_news = []
	GameData.save_game()
	_refresh()


## Carte d'un héros : nom, progrès dans chaque programme, et boutons pour choisir son programme.
func _make_hero_row(hero: Dictionary) -> Control:
	var color: Color = GameData.RARITY_COLORS[hero["rarity"]]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b"), color, 2))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	box.add_child(UI.make_label("%s (%s) — %s, niv. %d" % [hero["name"], "★".repeat(hero["rarity"]),
		hero["class"], hero["level"]], 24))
	for skill_name in GameData.TRAINING_SKILLS:
		var line := UI.make_label(_progress_text(hero, skill_name), 20)
		line.modulate = Color(1, 1, 1, 0.75)
		box.add_child(line)
	var status := UI.make_label(_status_text(hero), 20)
	status.add_theme_color_override("font_color", Color("f5b82e"))
	box.add_child(status)
	status_labels[hero["id"]] = status

	# Un bouton par programme, plus « Repos ». Le programme en cours est enfoncé.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	var current: String = hero.get("training", "")
	for skill_name in GameData.TRAINING_SKILLS:
		buttons.add_child(_make_program_button(hero, PROGRAM_LABELS[skill_name], skill_name, current == skill_name))
	buttons.add_child(_make_program_button(hero, "Repos", "", current == ""))
	return panel


func _make_program_button(hero: Dictionary, text: String, skill_name: String, selected: bool) -> Button:
	var button := UI.make_button(text, func(): _choose(hero, skill_name), 22)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 64
	button.toggle_mode = true
	button.button_pressed = selected
	return button


func _choose(hero: Dictionary, skill_name: String) -> void:
	var accepted: bool = hero.get("training", "") == skill_name or GameData.set_training(hero, skill_name)
	# On redessine même en cas de refus : le bouton touché ne doit pas rester enfoncé.
	_refresh()
	if not accepted:
		slots_label.text = "Le terrain est plein (%d places) : renvoie d'abord un héros au repos." % GameData.TRAINING_SLOTS


## « Maîtrise de l'épée : niv. 2 — 40 / 100 » (ou « pas encore apprise »).
func _progress_text(hero: Dictionary, skill_name: String) -> String:
	var level := GameData.skill_level(hero["skills"], skill_name)
	if level >= GameData.SKILL_MAX_LEVEL:
		return "%s : niveau maximum" % skill_name
	var progress := "%d / %d" % [GameData.skill_progress(hero, skill_name), GameData.TRAINING_POINTS_PER_LEVEL]
	if level == 0:
		return "%s : pas encore apprise — %s" % [skill_name, progress]
	return "%s : niv. %d — %s" % [skill_name, level, progress]


func _status_text(hero: Dictionary) -> String:
	var training: String = hero.get("training", "")
	if training == "":
		return "Au repos"
	if GameData.in_tower(hero):
		return "Parti dans la Tour : reprendra l'entraînement (%s) après l'étage" % PROGRAM_LABELS[training]
	var seconds := GameData.seconds_to_next_session(hero)
	return "À l'entraînement (%s) : prochaine séance dans %d:%02d" % [PROGRAM_LABELS[training], seconds / 60, seconds % 60]
