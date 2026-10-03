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
## Chaque ligne de « lines » devient un texte centré (une ligne peut aussi être un nœud déjà
## fabriqué, comme un montant de gemmes avec son icône : il est centré tel quel).
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
		if line is Control:
			var centered := CenterContainer.new()
			centered.add_child(line)
			content.add_child(centered)
			continue
		var label := make_label(line, 22)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if danger:
			label.add_theme_color_override("font_color", accent.lightened(0.4))
		content.add_child(label)
	for label in content.get_children():
		if label is Label:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel


## Un montant de gemmes : le texte (« 1 000 », « +5 »...) suivi du cristal qui lévite
## (nouveaux visuels), ou du mot « gemmes » (anciens visuels).
static func make_gem_amount(text: String, font_size: int, color := Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := make_label(text if Settings.new_visuals else text + " gemmes", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	if Settings.new_visuals:
		row.add_child(GemIcon.new(roundf(font_size * 1.7)))
	return row


## Un nombre avec des espaces entre les milliers : 50000 -> « 50 000 ».
static func format_number(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			grouped += " "
		grouped += digits[i]
	return ("-" if value < 0 else "") + grouped


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
	if not report.get("lost_weapons", []).is_empty():
		windows.append(make_system_window("Armes perdues", report["lost_weapons"], true))
	if not report["notices"].is_empty():
		windows.append(make_system_window("Félicitations !", report["notices"]))
	if not report["skills"].is_empty():
		windows.append(make_system_window("Progrès des compétences !", report["skills"]))

	var lines := []
	if report["victory"]:
		lines.append(make_gem_amount("+%s or   +%d" % [format_number(report["gold"]), report["gems"]], 22))
		var items: Array = report.get("items", [])
		if not items.is_empty():
			lines.append(make_reward_items(items))
			lines.append("Rangés dans l'entrepôt.")
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


## Icônes provisoires des objets (en attendant de vraies images) ; sinon, l'initiale du nom.
const ITEM_ICONS := {"Minerai de fer": "Fe", "Charbon": "Ch", "Cristal brut": "Cr", "Pierre d'attribut": "◆",
	"Bois": "Bo", "Peau de bête": "Pe", "Herbe médicinale": "He", "Pierre de taille": "Pi", "Plume": "Pl", "Lin": "Li"}


## Les objets gagnés, une case par objet (cahier : « les récompenses s'affichent avec une icône par objet »).
## « items » : [{"name", "grade", "count"}].
static func make_reward_items(items: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = mini(items.size(), 4)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for item in items:
		grid.add_child(make_reward_item(item["name"], item["grade"], item["count"]))
	return grid


## Une case d'objet : l'icône (provisoire : l'initiale du matériau), le grade dans le coin,
## la quantité en bas et le nom dessous. Le cadre a la couleur du grade.
static func make_reward_item(item_name: String, grade: String, count: int) -> VBoxContainer:
	var color := ArmoryScreen.grade_color(grade)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(92, 92)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", make_panel_style(color.darkened(0.75), color, 3))
	box.add_child(slot)

	var letter := make_label(ITEM_ICONS.get(item_name, item_name.left(1).to_upper()), 40)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.add_theme_color_override("font_color", color.lightened(0.3))
	slot.add_child(letter)

	var grade_label := make_label(grade, 16)
	grade_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	grade_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grade_label.add_theme_color_override("font_color", color.lightened(0.4))
	slot.add_child(grade_label)

	var count_label := make_label("x%d" % count, 18)
	count_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	count_label.size_flags_vertical = Control.SIZE_SHRINK_END
	slot.add_child(count_label)

	var name_label := make_label(item_name, 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size.x = 100
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.modulate = Color(1, 1, 1, 0.8)
	box.add_child(name_label)
	return box


## Carte d'un héros pour les listes : le cadre illustré (FramedHeroCard) avec les nouveaux visuels,
## sinon l'ancienne carte simple (make_hero_card). « width » : largeur de la carte illustrée.
static func make_card(hero: Dictionary, width := 120.0) -> Button:
	if Settings.new_visuals:
		return FramedHeroCard.new(hero, width)
	return make_hero_card(hero)


## Marque une carte comme choisie (dans une équipe, pour un sacrifice...), avec la couleur voulue.
static func mark_card_chosen(card: Button, hero: Dictionary, color := Color.WHITE) -> void:
	if card is FramedHeroCard:
		card.set_chosen(color)
		return
	var rarity_color: Color = GameData.RARITY_COLORS[hero["rarity"]]
	var style := make_panel_style(rarity_color.darkened(0.2), color, 8)
	set_button_style(card, style, style)


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

	if GameData.is_favorite(hero):
		add_favorite_mark(card, 22)
	if not hero["alive"]:
		card.modulate = Color(0.4, 0.4, 0.4)
	return card


## Petit cœur rose en haut à droite d'une carte : le héros est un favori.
static func add_favorite_mark(card: Control, font_size: int) -> void:
	var heart := make_label("♥", font_size)
	heart.add_theme_color_override("font_color", Color("ff5c8a"))
	heart.add_theme_color_override("font_outline_color", Color.BLACK)
	heart.add_theme_constant_override("outline_size", 4)
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	heart.position += Vector2(-font_size * 0.9, 2)
	card.add_child(heart)
