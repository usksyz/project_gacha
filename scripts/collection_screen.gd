class_name CollectionScreen
extends Control
## Collection : tous les héros possédés, triés par rareté.
## Appuyer sur un héros ouvre sa fiche détaillée.

var count_label: Label
var empty_label: Label
var grid: GridContainer
var detail_overlay: Control


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	count_label = UI.make_label("", 26)
	layout.add_child(count_label)

	empty_label = UI.make_label("Tu n'as encore aucun héros.\nVa dans la Salle d'invocation !", 26)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(empty_label)

	# Zone qui défile quand il y a beaucoup de héros.
	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var centered := CenterContainer.new()
	centered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centered)
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	centered.add_child(grid)

	# Calque qui affiche la fiche d'un héros par-dessus la liste.
	detail_overlay = Control.new()
	detail_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_overlay.visible = false
	add_child(detail_overlay)


func on_shown() -> void:
	detail_overlay.visible = false
	_refresh()


func _refresh() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	# Tri : les plus rares d'abord, puis dans l'ordre d'invocation.
	var heroes: Array = GameData.roster.duplicate()
	heroes.sort_custom(func(a, b):
		if a["rarity"] != b["rarity"]:
			return a["rarity"] > b["rarity"]
		return a["id"] < b["id"])

	for hero in heroes:
		var card := UI.make_hero_card(hero)
		card.pressed.connect(func(): _show_detail(hero))
		grid.add_child(card)

	count_label.text = "Héros possédés : %d" % heroes.size()
	empty_label.visible = heroes.is_empty()


## Affiche la fiche détaillée d'un héros.
func _show_detail(hero: Dictionary) -> void:
	for child in detail_overlay.get_children():
		child.queue_free()

	var color: Color = GameData.RARITY_COLORS[hero["rarity"]]

	# Fond sombre : appuyer à côté de la fiche la ferme.
	var dim := Button.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.set_button_style(dim, UI.make_panel_style(Color(0, 0, 0, 0.7)), UI.make_panel_style(Color(0, 0, 0, 0.7)))
	dim.pressed.connect(func(): detail_overlay.visible = false)
	detail_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 560
	var style := UI.make_panel_style(Color("262a3b"), color, 4)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)

	var rarity := UI.make_label(UI.rarity_text(hero["rarity"]), 26)
	rarity.add_theme_color_override("font_color", color)
	content.add_child(rarity)
	content.add_child(UI.make_label(hero["name"], 52))
	content.add_child(UI.make_label(hero["class"], 28))

	var level_text := "Niveau %d / %d" % [hero["level"], GameData.MAX_LEVEL[hero["rarity"]]]
	content.add_child(UI.make_label(level_text, 26))
	var xp_text := "Niveau maximum atteint"
	if not GameData.is_max_level(hero):
		xp_text = "Expérience : %d / %d" % [hero["xp"], GameData.xp_to_next(hero["level"])]
	var xp_label := UI.make_label(xp_text, 22)
	xp_label.modulate = Color(1, 1, 1, 0.7)
	content.add_child(xp_label)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 32)
	stats.add_theme_constant_override("v_separation", 8)
	content.add_child(stats)
	for stat in GameData.STAT_NAMES:
		var stat_name := UI.make_label(GameData.STAT_NAMES[stat], 26)
		stat_name.modulate = Color(1, 1, 1, 0.7)
		stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(stat_name)
		stats.add_child(UI.make_label(str(hero["stats"][stat]), 26))

	# Compétences : nom, rang et niveau, puis ce qu'elle fait (en plus petit).
	content.add_child(UI.make_label("Compétences :" if not hero["skills"].is_empty() else "Compétences : aucune", 22))
	for skill in hero["skills"]:
		content.add_child(UI.make_label("%s (%s, niv. %d)" % [skill["name"], skill["rank"], skill["level"]], 22))
		var description := UI.make_label(GameData.SKILLS.get(skill["name"], ""), 18)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.modulate = Color(1, 1, 1, 0.6)
		content.add_child(description)

	var status_text := "En vie"
	var status_color := Color("4caf6a")
	if hero["immortal"]:
		status_text = "Immortel"
		status_color = Color("f5b82e")
	elif not hero["alive"]:
		status_text = "Mort"
		if hero.get("death_cause", "") != "":
			status_text = "Mort — %s" % hero["death_cause"]
		status_color = Color("e05252")
	var status := UI.make_label(status_text, 26)
	status.add_theme_color_override("font_color", status_color)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)

	var close := UI.make_button("Fermer", func(): detail_overlay.visible = false)
	close.custom_minimum_size.y = 90
	content.add_child(close)

	detail_overlay.visible = true
