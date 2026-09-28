class_name HubScreen
extends Control
## Le hub : la cité vue du ciel. Appuyer sur un quartier ouvre l'écran correspondant,
## ou affiche une description si le quartier n'est pas encore disponible.

## Demande à l'écran principal d'afficher un autre écran.
signal navigate(screen_name: String)

## Les lieux en dehors des remparts.
const OUTSIDE_ZONES := [
	{"name": "Faille spatio-temporelle", "target": "dungeons",
		"info": "Le passage vers les donjons."},
	{"name": "Zone de débarquement", "target": "",
		"info": "Là où reviennent tes héros après une expédition. (Bientôt)"},
]

## Nombre maximum de lettres dans un code secret.
const CODE_MAX_LENGTH := 12

var info_label: Label

# Clavier des codes secrets (à l'ancienne : on tape les lettres sur une grille).
var code_overlay: Control
var code_display: Label
var code_result: Label
var typed_code := ""


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var map := HubMap.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.zone_pressed.connect(_on_zone_pressed)
	layout.add_child(map)

	var outside := HBoxContainer.new()
	outside.add_theme_constant_override("separation", 16)
	layout.add_child(outside)
	for zone in OUTSIDE_ZONES:
		var button := UI.make_button(zone["name"], func(): _on_zone_pressed(zone), 20)
		button.custom_minimum_size.y = 80
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outside.add_child(button)

	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b")))
	info_panel.custom_minimum_size.y = 100
	layout.add_child(info_panel)
	info_label = UI.make_label("Appuie sur un lieu de la cité.", 22)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_panel.add_child(info_label)

	code_overlay = _build_code_pad()
	add_child(code_overlay)


func on_shown() -> void:
	code_overlay.visible = false


func _on_zone_pressed(zone: Dictionary) -> void:
	info_label.text = "%s : %s" % [zone["name"], zone["info"]]
	if zone["target"] == "code":
		typed_code = ""
		code_result.text = ""
		_refresh_code()
		code_overlay.visible = true
	elif zone["target"] != "":
		navigate.emit(zone["target"])


func _build_code_pad() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false

	# Fond sombre qui bloque les appuis sur la cité en dessous.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var window := UI.make_system_window("La stèle", ["Grave un mot de passe :"])
	window.custom_minimum_size.x = 640
	center.add_child(window)
	var content: VBoxContainer = window.get_child(0)
	content.add_theme_constant_override("separation", 12)

	code_display = UI.make_label("", 40)
	code_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_display.add_theme_color_override("font_color", Color("f5b82e"))
	content.add_child(code_display)

	var letters := GridContainer.new()
	letters.columns = 7
	letters.add_theme_constant_override("h_separation", 6)
	letters.add_theme_constant_override("v_separation", 6)
	content.add_child(letters)
	for i in 26:
		var letter := char(65 + i)  # 65 = code de la lettre A
		var key := UI.make_button(letter, func(): _type_letter(letter), 26)
		key.custom_minimum_size = Vector2(80, 70)
		letters.add_child(key)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	content.add_child(buttons)
	for action in [["Effacer", _erase_letter], ["Fermer", func(): overlay.visible = false], ["Valider", _submit_code]]:
		var button := UI.make_button(action[0], action[1], 24)
		button.custom_minimum_size.y = 80
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)

	code_result = UI.make_label("", 22)
	code_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(code_result)
	return overlay


func _type_letter(letter: String) -> void:
	if typed_code.length() < CODE_MAX_LENGTH:
		typed_code += letter
		_refresh_code()


func _erase_letter() -> void:
	typed_code = typed_code.left(-1)
	_refresh_code()


func _refresh_code() -> void:
	# Les cases vides sont affichées avec des tirets.
	code_display.text = typed_code if typed_code != "" else "_ _ _"


func _submit_code() -> void:
	var hero := GameData.redeem_code(typed_code)
	if hero.is_empty():
		code_result.text = "La stèle reste silencieuse."
	else:
		code_result.text = "La stèle s'illumine... %s (%s) rejoint ta cité !" % [
			hero["name"], UI.rarity_text(hero["rarity"])]
	typed_code = ""
	_refresh_code()
