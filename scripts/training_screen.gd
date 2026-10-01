class_name TrainingScreen
extends Control
## Terrain d'entraînement (ouvert depuis le hub).
## On y envoie des héros travailler une compétence : Maîtrise de l'épée ou Utilisation du bouclier.
## Chaque séance (quelques minutes de temps réel, même jeu fermé) leur donne des points de progrès ;
## à 100 points, ils apprennent la compétence ou gagnent un niveau. Les règles sont dans GameData.
## L'écran ne montre que les héros à l'entraînement ; « Ajouter un héros » ouvre une fenêtre
## avec une recherche et des filtres (HeroFilter), pour s'y retrouver parmi des centaines de héros.

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
var add_button: Button
## Étiquette de suivi de chaque héros (id -> Label), mise à jour chaque seconde.
var status_labels := {}
## Fenêtre « Ajouter un héros » (par-dessus l'écran), avec sa recherche et sa liste.
var picker: Control
var filter: HeroFilter
var picker_list: VBoxContainer
## Nombre maximum de héros montrés dans la fenêtre : au-delà, il faut affiner la recherche.
const MAX_ROWS := 30


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
	add_button = UI.make_button("+ Ajouter un héros", _open_picker, 24)
	add_button.custom_minimum_size.y = 80
	content.add_child(add_button)

	_build_picker()

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
	picker.visible = false
	GameData.update_training()
	_refresh()


func _tick() -> void:
	if not is_visible_in_tree():
		return
	GameData.update_training()
	for hero in GameData.alive_heroes():
		if status_labels.has(hero["id"]):
			status_labels[hero["id"]].text = _status_text(hero)


## Reconstruit tout l'écran : nouveautés, puis une carte par héros à l'entraînement.
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

	var trainees := GameData.trainees()
	slots_label.text = "Places occupées : %d / %d" % [trainees.size(), GameData.TRAINING_SLOTS]
	for hero in trainees:
		list.add_child(_make_hero_row(hero))
	if trainees.is_empty():
		var empty := UI.make_label("Personne ne s'entraîne pour l'instant.", 22)
		empty.modulate = Color(1, 1, 1, 0.7)
		list.add_child(empty)
	var full := trainees.size() >= GameData.TRAINING_SLOTS
	add_button.disabled = full
	add_button.text = "Terrain plein : renvoie un héros au repos pour libérer une place" if full else "+ Ajouter un héros"
	add_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Construit (une seule fois) la fenêtre « Ajouter un héros ». La recherche est gardée d'une
## ouverture à l'autre.
func _build_picker() -> void:
	picker = Control.new()
	picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker.visible = false
	add_child(picker)

	# Fond sombre : appuyer à côté de la fenêtre la ferme.
	var dim := Button.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.set_button_style(dim, UI.make_panel_style(Color(0, 0, 0, 0.75)), UI.make_panel_style(Color(0, 0, 0, 0.75)))
	dim.pressed.connect(func(): picker.visible = false)
	picker.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	picker.add_child(margin)
	var panel := PanelContainer.new()
	var style := UI.make_panel_style(Color("262a3b"), Color("9b6be0"), 3)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	layout.add_child(UI.make_label("Envoyer un héros à l'entraînement", 26))
	filter = HeroFilter.new()
	filter.changed.connect(_refresh_picker)
	layout.add_child(filter)
	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	picker_list = VBoxContainer.new()
	picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_list.add_theme_constant_override("separation", 8)
	scroll.add_child(picker_list)
	var close := UI.make_button("Fermer", func(): picker.visible = false, 22)
	close.custom_minimum_size.y = 70
	layout.add_child(close)


func _open_picker() -> void:
	_refresh_picker()
	picker.visible = true


## Liste des héros qui ne s'entraînent pas encore et correspondent à la recherche (MAX_ROWS au plus).
## Chaque ligne a un bouton par programme : un toucher l'inscrit et ferme la fenêtre.
func _refresh_picker() -> void:
	for child in picker_list.get_children():
		picker_list.remove_child(child)
		child.queue_free()
	var candidates := GameData.alive_heroes().filter(func(hero): return hero.get("training", "") == "")
	var heroes := filter.apply(candidates)
	for hero in heroes.slice(0, MAX_ROWS):
		picker_list.add_child(_make_candidate_row(hero))
	var hint := ""
	if heroes.is_empty():
		hint = "Aucun héros ne correspond à la recherche."
	elif heroes.size() > MAX_ROWS:
		hint = "… et %d autres héros : affine la recherche pour les trouver." % (heroes.size() - MAX_ROWS)
	if hint != "":
		var label := UI.make_label(hint, 20)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate = Color(1, 1, 1, 0.7)
		picker_list.add_child(label)


## Ligne compacte d'un héros dans la fenêtre : nom, niveaux des compétences d'entraînement,
## occupation actuelle, et un bouton par programme.
func _make_candidate_row(hero: Dictionary) -> Control:
	var color: Color = GameData.RARITY_COLORS[hero["rarity"]]
	var panel := PanelContainer.new()
	var style := UI.make_panel_style(Color("1d2030"), color, 2)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(UI.make_label("%s (%s) — %s, niv. %d" % [hero["name"], "★".repeat(hero["rarity"]),
		hero["class"], hero["level"]], 22))
	var levels := PackedStringArray()
	for skill_name in GameData.TRAINING_SKILLS:
		levels.append("%s niv. %d" % [PROGRAM_LABELS[skill_name], GameData.skill_level(hero["skills"], skill_name)])
	var info := UI.make_label("%s — %s" % [", ".join(levels), GameData.activity_text(hero)], 18)
	info.modulate = Color(1, 1, 1, 0.7)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	for skill_name in GameData.TRAINING_SKILLS:
		var button := UI.make_button(PROGRAM_LABELS[skill_name], func():
			picker.visible = false
			_choose(hero, skill_name), 22)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 56
		button.disabled = GameData.skill_level(hero["skills"], skill_name) >= GameData.SKILL_MAX_LEVEL
		buttons.add_child(button)
	return panel


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
		return GameData.activity_text(hero)  # au repos, ou assistant dans un bâtiment
	if GameData.is_away(hero):
		return "%s : reprendra l'entraînement (%s) à son retour" % [GameData.activity_text(hero), PROGRAM_LABELS[training]]
	var seconds := GameData.seconds_to_next_session(hero)
	return "À l'entraînement (%s) : prochaine séance dans %d:%02d" % [PROGRAM_LABELS[training], seconds / 60, seconds % 60]
