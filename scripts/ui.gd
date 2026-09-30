class_name UI
## Petites fonctions pour fabriquer les éléments d'interface utilisés par plusieurs écrans.
## Exemple d'utilisation : UI.make_label("Bonjour", 24)


static func make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


static func make_button(text: String, on_pressed: Callable, font_size := 28) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(on_pressed)
	return button


## Fond de panneau arrondi, utilisé pour les cartes, les fiches, les barres...
static func make_panel_style(background: Color, border: Color = Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	return style


## Zone qui défile verticalement et prend toute la hauteur disponible.
## Pas de barre visible : on fait défiler en glissant le doigt (voir drag_scroll.gd)
## ou avec la molette de la souris.
static func make_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	return scroll


## Applique le même style à tous les états d'un bouton (normal, survolé, appuyé...).
static func set_button_style(button: Button, normal: StyleBox, pressed: StyleBox) -> void:
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Fenêtre « système » : fond sombre, bordure violette, titre centré en majuscules.
## « danger » = variante rouge, pour les alertes graves (mort d'un héros...).
## Chaque ligne de « lines » devient un texte centré.
static func make_system_window(title: String, lines: Array, danger := false) -> PanelContainer:
	var accent := Color("e05252") if danger else Color("9b6be0")
	var panel := PanelContainer.new()
	var style := make_panel_style(Color("15121f"), accent, 3)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var title_label := make_label(title.to_upper(), 26)
	title_label.add_theme_color_override("font_color", accent.lightened(0.3))
	content.add_child(title_label)
	for line in lines:
		var label := make_label(line, 22)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if danger:
			label.add_theme_color_override("font_color", accent.lightened(0.4))
		content.add_child(label)
	for label in content.get_children():
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel


static func rarity_text(rarity: int) -> String:
	return "%d étoile%s" % [rarity, "s" if rarity > 1 else ""]


## Fenêtres de fin d'un combat de la Tour, à partir du rapport de GameData.finish_tower_battle :
## une fenêtre rouge par héros mort, les annonces, l'éveil des compétences, puis le résultat.
static func make_battle_report_windows(report: Dictionary) -> Array[Control]:
	var windows: Array[Control] = []
	if not report["dead"].is_empty():
		Settings.vibrate(400)
	for death in report["dead"]:
		var hero: Dictionary = death["hero"]
		windows.append(make_system_window("Un héros est tombé", [
			"%s (%s) a quitté ce monde pour toujours." % [hero["name"], rarity_text(hero["rarity"])],
			"Cause : %s." % death["cause"],
		], true))
	if not report["notices"].is_empty():
		windows.append(make_system_window("Félicitations !", report["notices"]))
	if not report["skills"].is_empty():
		windows.append(make_system_window("Progrès des compétences !", report["skills"]))

	var lines := []
	if report["victory"]:
		lines.append("+%d or   +%d gemmes" % [report["gold"], report["gems"]])
		if report.get("stones", 0) > 0:
			lines.append("+%d %s (pour la promotion)" % [report["stones"], GameData.PROMOTION_STONE])
	else:
		lines.append("Les survivants sont ramenés à la cité.")
	lines.append("+%d expérience pour chaque survivant" % report["xp"])
	for level_up in report["level_ups"]:
		var hero: Dictionary = level_up["hero"]
		lines.append("%s passe au niveau %d !" % [hero["name"], hero["level"]])
	if report["mvp"] != "":
		lines.append("MVP : %s" % report["mvp"])
	var title := "Défaite"
	if report["victory"]:
		title = "Étage réussi (entraînement)" if report.get("replay", false) else "Étage conquis !"
	windows.append(make_system_window(title, lines))
	return windows


## Carte d'un héros (rareté, nom, classe). C'est un bouton : on peut appuyer dessus.
static func make_hero_card(hero: Dictionary) -> Button:
	var color: Color = GameData.RARITY_COLORS[hero["rarity"]]

	var card := Button.new()
	card.custom_minimum_size = Vector2(120, 170)
	set_button_style(
		card,
		make_panel_style(color.darkened(0.6), color, 4),
		make_panel_style(color.darkened(0.3), color, 4)
	)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	var stars := make_label(rarity_text(hero["rarity"]), 15)
	stars.add_theme_color_override("font_color", color)
	content.add_child(stars)
	content.add_child(make_label(hero["name"], 18))
	var hero_class := make_label(hero["class"], 14)
	hero_class.modulate = Color(1, 1, 1, 0.7)
	content.add_child(hero_class)
	content.add_child(make_label("Niv. %d" % hero["level"], 14))

	for label in content.get_children():
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if not hero["alive"]:
		card.modulate = Color(0.4, 0.4, 0.4)
	return card
