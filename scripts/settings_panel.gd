class_name SettingsPanel
extends Control
## Fenêtre des paramètres, ouverte par la roue dentée en haut de l'écran.
## Chaque réglage est enregistré sur l'appareil dès qu'on le change (voir settings.gd).

const ACCENT_COLOR := Color("9b6be0")
const DANGER_COLOR := Color("e05252")

var code_pad: CodePad
var reset_button: Button
## « Recommencer la partie » demande un deuxième appui pour confirmer.
var reset_armed := false


func _ready() -> void:
	# Occupe tout l'écran (bords compris, car la fenêtre est déjà ajoutée à l'écran à ce moment-là).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var panel := PanelContainer.new()
	var style := UI.make_panel_style(Color("15121f"), ACCENT_COLOR, 3)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)

	var title := UI.make_label("PARAMÈTRES", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT_COLOR.lightened(0.3))
	layout.add_child(title)

	# Les réglages défilent si l'écran est trop petit.
	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	_add_section(content, "Son")
	_add_volume_row(content, "Musique", "music_volume")
	_add_volume_row(content, "Effets sonores", "sfx_volume")

	_add_section(content, "Jeu")
	_add_speed_row(content)
	_add_toggle_row(content, "Vibrations", "vibrations")
	_add_toggle_row(content, "Plein écran", "fullscreen")
	var language := UI.make_label("Français", 24)
	language.modulate = Color(1, 1, 1, 0.7)
	_add_row(content, "Langue", language)

	_add_section(content, "Codes secrets")
	var code_button := UI.make_button("Entrer un code", func(): code_pad.open(), 24)
	code_button.custom_minimum_size.y = 80
	content.add_child(code_button)

	_add_section(content, "Partie")
	reset_button = UI.make_button("", _on_reset_pressed, 24)
	reset_button.custom_minimum_size.y = 80
	reset_button.add_theme_color_override("font_color", DANGER_COLOR)
	content.add_child(reset_button)
	var about := UI.make_label("Projet Gacha — prototype fait avec Godot 4", 20)
	about.modulate = Color(1, 1, 1, 0.5)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(about)

	var close := UI.make_button("Fermer", func(): visible = false)
	close.custom_minimum_size.y = 90
	layout.add_child(close)

	# Le clavier des codes s'affiche par-dessus les paramètres.
	code_pad = CodePad.new()
	add_child(code_pad)


func open() -> void:
	reset_armed = false
	reset_button.text = "Recommencer la partie"
	code_pad.visible = false
	visible = true


func _add_section(parent: Control, text: String) -> void:
	var label := UI.make_label(text, 28)
	label.add_theme_color_override("font_color", Color("f5b82e"))
	parent.add_child(label)


## Une ligne : le nom du réglage à gauche, et son contrôle à droite.
func _add_row(parent: Control, text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := UI.make_label(text, 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)


## Volume : boutons « - » et « + » (de 10 en 10), plus faciles à toucher qu'un curseur.
func _add_volume_row(parent: Control, text: String, setting: String) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var value := UI.make_label("", 24)
	value.custom_minimum_size.x = 90
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var refresh := func(): value.text = "%d %%" % Settings.get(setting)
	for step in [-10, 10]:
		var on_pressed := func():
			Settings.change(setting, clampi(Settings.get(setting) + step, 0, 100))
			refresh.call()
		var button := UI.make_button("-" if step < 0 else "+", on_pressed, 28)
		button.custom_minimum_size = Vector2(70, 70)
		box.add_child(button)
		if step < 0:
			box.add_child(value)
	refresh.call()
	_add_row(parent, text, box)


## Interrupteur : un bouton « Activé » / « Désactivé ».
func _add_toggle_row(parent: Control, text: String, setting: String) -> void:
	var button := UI.make_button("", func(): pass, 24)
	button.custom_minimum_size = Vector2(200, 70)
	var refresh := func(): button.text = "Activé" if Settings.get(setting) else "Désactivé"
	button.pressed.connect(func():
		Settings.change(setting, not Settings.get(setting))
		refresh.call())
	refresh.call()
	_add_row(parent, text, button)


## Vitesse de combat : x1 → x2 → x4 → x1 (la même que le bouton pendant les combats).
func _add_speed_row(parent: Control) -> void:
	var button := UI.make_button("", func(): pass, 24)
	button.custom_minimum_size = Vector2(200, 70)
	var refresh := func(): button.text = "x%d" % BattleView.SPEEDS[Settings.battle_speed_index]
	button.pressed.connect(func():
		Settings.change("battle_speed_index", (Settings.battle_speed_index + 1) % BattleView.SPEEDS.size())
		refresh.call())
	refresh.call()
	_add_row(parent, "Vitesse de combat", button)


func _on_reset_pressed() -> void:
	if not reset_armed:
		reset_armed = true
		reset_button.text = "Sûr ? Tout sera perdu. Appuie encore."
		return
	GameData.reset_game()
	# On recharge la scène pour reconstruire tous les écrans à partir de la nouvelle partie.
	get_tree().reload_current_scene()
