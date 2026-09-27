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


func _on_zone_pressed(zone: Dictionary) -> void:
	info_label.text = "%s : %s" % [zone["name"], zone["info"]]
	if zone["target"] != "":
		navigate.emit(zone["target"])
