class_name AssignmentPanel
extends Control
## Fenêtre des affectations (bouton « Affectations » du hub) : pour chaque bâtiment construit,
## ses postes d'assistant (GameData.POSTS_PER_BUILDING). On touche un poste libre pour y mettre
## un héros, ou un poste occupé pour libérer le héros. Un héros affecté quitte le terrain
## d'entraînement : il ne travaille qu'à un endroit à la fois. S'ouvre avec open().

var list: VBoxContainer
var info: Label
## Liste des héros à choisir pour un poste (par-dessus la fenêtre).
var picker: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	layout.add_child(UI.make_system_window("Affectations", [
		"%d postes d'assistant par bâtiment. Un héros affecté y travaille au lieu de s'entraîner." \
			% GameData.POSTS_PER_BUILDING]))
	info = UI.make_label("", 20)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", Color("f5b82e"))
	layout.add_child(info)
	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	var close := UI.make_button("Fermer", func(): visible = false, 24)
	close.custom_minimum_size.y = 80
	layout.add_child(close)

	picker = Control.new()
	picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker.visible = false
	add_child(picker)


func open() -> void:
	info.text = ""
	picker.visible = false
	_refresh()
	visible = true


func _refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	if GameData.buildings.is_empty():
		var none := UI.make_label("Aucun bâtiment construit pour l'instant (bouton « Construction »).", 22)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(none)
		return
	for building_id in GameData.BUILDINGS:
		if not building_id in GameData.buildings:
			continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b"), Color("9b6be0"), 2))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		panel.add_child(box)
		box.add_child(UI.make_label(GameData.BUILDINGS[building_id]["name"], 24))
		if building_id == "forge":
			var hint := UI.make_label("Les assistants deviennent artisans en travaillant (compétence « Forge »).", 18)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.modulate = Color(1, 1, 1, 0.7)
			box.add_child(hint)
		var posted := GameData.posted_heroes(building_id)
		for i in GameData.POSTS_PER_BUILDING:
			var button: Button
			if i < posted.size():
				var hero: Dictionary = posted[i]
				var text := "%s (%s)" % [hero["name"], "★".repeat(hero["rarity"])]
				if GameData.skill_level(hero["skills"], "Forge") > 0:
					text += " — artisan"
				if GameData.is_away(hero):
					text += " — absent (%s)" % GameData.activity_text(hero)
				button = UI.make_button(text + "   [libérer]", func():
					GameData.set_post(hero, "")
					_refresh.call_deferred(), 20)
			else:
				button = UI.make_button("Poste libre : choisir un héros", func(): _open_picker(building_id), 20)
			button.custom_minimum_size.y = 64
			box.add_child(button)
		list.add_child(panel)


## Liste des héros vivants (sauf ceux déjà à ce poste), avec ce qu'ils font en ce moment.
func _open_picker(building_id: String) -> void:
	for child in picker.get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	picker.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	layout.add_child(UI.make_label("Assistant : %s" % GameData.BUILDINGS[building_id]["name"], 28))
	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var heroes := VBoxContainer.new()
	heroes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heroes.add_theme_constant_override("separation", 8)
	scroll.add_child(heroes)
	for hero in GameData.alive_heroes():
		if hero.get("post", "") == building_id:
			continue
		var text := "%s (%s) — %s, niv. %d — %s" % [hero["name"], "★".repeat(hero["rarity"]),
			hero["class"], hero["level"], GameData.activity_text(hero)]
		var button := UI.make_button(text, func():
			if not GameData.set_post(hero, building_id):
				info.text = "Impossible : les postes de ce bâtiment sont pris."
			picker.visible = false
			_refresh.call_deferred(), 20)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 64
		heroes.add_child(button)
	var cancel := UI.make_button("Annuler", func(): picker.visible = false, 24)
	cancel.custom_minimum_size.y = 80
	layout.add_child(cancel)
	picker.visible = true
