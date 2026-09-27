class_name DungeonsScreen
extends Control
## Donjons : aperçu des modes de jeu à venir.

const MODES := [
	{"name": "La Tour", "info": "Grimpe les étages un par un. Chaque étage est plus dangereux que le précédent."},
	{"name": "Donjon d'expérience", "info": "Donjon journalier : fais gagner de l'expérience à tes héros."},
	{"name": "Donjon de ressources", "info": "Donjon journalier : récolte des matériaux pour la cité."},
	{"name": "Donjon d'or", "info": "Donjon journalier : amasse de l'or."},
]


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	for mode in MODES:
		var card := PanelContainer.new()
		var style := UI.make_panel_style(Color("262a3b"))
		style.set_content_margin_all(24)
		card.add_theme_stylebox_override("panel", style)
		layout.add_child(card)

		var content := VBoxContainer.new()
		card.add_child(content)
		var header := HBoxContainer.new()
		content.add_child(header)
		var title := UI.make_label(mode["name"], 32)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		var soon := UI.make_label("Bientôt", 22)
		soon.add_theme_color_override("font_color", Color("f5b82e"))
		header.add_child(soon)
		var info := UI.make_label(mode["info"], 22)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.modulate = Color(1, 1, 1, 0.7)
		content.add_child(info)
