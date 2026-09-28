class_name CodePad
extends Control
## Clavier des codes secrets, à l'ancienne : on tape les lettres sur une grille.
## S'affiche par-dessus l'écran ; on l'ouvre avec open().

## Nombre maximum de lettres dans un code secret.
const CODE_MAX_LENGTH := 12

var display: Label
var result: Label
var typed_code := ""


func _ready() -> void:
	# Occupe tout l'écran (bords compris, car le clavier est déjà ajouté à l'écran à ce moment-là).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Fond sombre qui bloque les appuis sur ce qu'il y a en dessous.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var window := UI.make_system_window("Code secret", ["Tape un code :"])
	window.custom_minimum_size.x = 640
	center.add_child(window)
	var content: VBoxContainer = window.get_child(0)
	content.add_theme_constant_override("separation", 12)

	display = UI.make_label("", 40)
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display.add_theme_color_override("font_color", Color("f5b82e"))
	content.add_child(display)

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
	for action in [["Effacer", _erase_letter], ["Fermer", func(): visible = false], ["Valider", _submit_code]]:
		var button := UI.make_button(action[0], action[1], 24)
		button.custom_minimum_size.y = 80
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)

	result = UI.make_label("", 22)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(result)


func open() -> void:
	typed_code = ""
	result.text = ""
	_refresh()
	visible = true


func _type_letter(letter: String) -> void:
	if typed_code.length() < CODE_MAX_LENGTH:
		typed_code += letter
		_refresh()


func _erase_letter() -> void:
	typed_code = typed_code.left(-1)
	_refresh()


func _refresh() -> void:
	display.text = typed_code if typed_code != "" else "_ _ _"


func _submit_code() -> void:
	var hero := GameData.redeem_code(typed_code)
	if hero.is_empty():
		result.text = "Code invalide... ou déjà utilisé."
	else:
		result.text = "Code accepté ! %s (%s) rejoint ta cité." % [hero["name"], UI.rarity_text(hero["rarity"])]
	typed_code = ""
	_refresh()
