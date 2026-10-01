class_name CodePad
extends Control
## Fenêtre des codes secrets : un champ de texte où l'on tape le code
## avec le clavier de l'appareil (celui du téléphone, ou du PC).
## S'affiche par-dessus l'écran ; on l'ouvre avec open().

## Nombre maximum de caractères dans un code secret.
const CODE_MAX_LENGTH := 12

var input: LineEdit
var result: Label


func _ready() -> void:
	# Occupe tout l'écran (bords compris, car la fenêtre est déjà ajoutée à l'écran à ce moment-là).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Fond sombre qui bloque les appuis sur ce qu'il y a en dessous.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# La fenêtre est placée en haut, pour rester visible au-dessus du clavier du téléphone.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var window := UI.make_system_window("Code secret", ["Tape un code :"])
	margin.add_child(window)
	var content: VBoxContainer = window.get_child(0)
	content.add_theme_constant_override("separation", 12)

	input = LineEdit.new()
	input.max_length = CODE_MAX_LENGTH
	input.placeholder_text = "Ton code"
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.custom_minimum_size.y = 80
	input.add_theme_font_size_override("font_size", 36)
	input.add_theme_color_override("font_color", Color("f5b82e"))
	# Appuyer sur « Entrée » (ou « OK » sur le téléphone) valide le code.
	input.text_submitted.connect(func(_text): _submit_code())
	content.add_child(input)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	content.add_child(buttons)
	for action in [["Fermer", close], ["Valider", _submit_code]]:
		var button := UI.make_button(action[0], action[1], 24)
		button.custom_minimum_size.y = 80
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)

	result = UI.make_label("", 22)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(result)


func open() -> void:
	input.text = ""
	result.text = ""
	visible = true
	# Donner le focus au champ fait apparaître le clavier du téléphone.
	input.grab_focus()


func close() -> void:
	input.release_focus()  # range le clavier du téléphone
	visible = false


func _submit_code() -> void:
	# Le code du mode dev (outils de test, or et gemmes infinis).
	if input.text.strip_edges().to_upper() == Settings.DEV_CODE:
		if Settings.dev_mode:
			result.text = "Le mode dev est déjà actif."
		else:
			Settings.change("dev_mode", true)
			result.text = "Mode dev activé : or et gemmes infinis. Outils dans Paramètres > « Outils du mode dev », et sur la fiche de chaque héros."
		input.text = ""
		return
	var hero := GameData.redeem_code(input.text)
	if hero.is_empty():
		result.text = "Code invalide... ou déjà utilisé."
	else:
		result.text = "Code accepté ! %s (%s) rejoint ta cité." % [hero["name"], UI.rarity_text(hero["rarity"])]
	input.text = ""
	input.grab_focus()
