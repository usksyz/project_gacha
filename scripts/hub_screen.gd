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

var info_label: Label

## Clavier des codes secrets, ouvert par la Place publique (aussi disponible dans les paramètres).
var code_pad: CodePad

## Fenêtre de construction des bâtiments de magie (il faut un mage).
var construction_panel: ConstructionPanel


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

	var build_button := UI.make_button("Construction", func(): construction_panel.open(), 22)
	build_button.custom_minimum_size.y = 70
	layout.add_child(build_button)

	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b")))
	info_panel.custom_minimum_size.y = 100
	layout.add_child(info_panel)
	info_label = UI.make_label("Appuie sur un lieu de la cité.", 22)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_panel.add_child(info_label)

	code_pad = CodePad.new()
	add_child(code_pad)
	construction_panel = ConstructionPanel.new()
	add_child(construction_panel)


func on_shown() -> void:
	code_pad.visible = false
	construction_panel.visible = false


func _on_zone_pressed(zone: Dictionary) -> void:
	info_label.text = "%s : %s" % [zone["name"], zone["info"]]
	# Le terrain d'entraînement ne s'ouvre qu'après quelques tirages d'armes.
	if zone["target"] == "training" and not GameData.training_unlocked():
		info_label.text = "%s : encore fermé. Il s'ouvre après %d armes tirées à l'Armurerie (%d / %d)." % [
			zone["name"], GameData.TRAINING_UNLOCK_DRAWS, GameData.weapon_draws, GameData.TRAINING_UNLOCK_DRAWS]
		return
	# Le laboratoire d'alchimie est un bâtiment de magie : il faut le construire (avec un mage).
	if zone["name"] == GameData.BUILDINGS["laboratoire"]["name"]:
		if "laboratoire" in GameData.buildings:
			info_label.text = "%s : construit. %s (Bientôt)" % [zone["name"], GameData.BUILDINGS["laboratoire"]["info"]]
		else:
			info_label.text = "%s : pas encore construit. Il faut un mage parmi tes héros (bouton « Construction »)." % zone["name"]
		return
	if zone["target"] == "code":
		code_pad.open()
	elif zone["target"] != "":
		navigate.emit(zone["target"])