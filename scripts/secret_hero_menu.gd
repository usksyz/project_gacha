class_name SecretHeroMenu
extends Control
## Menu des héros secrets, ouvert par le code GameData.SECRET_MENU_CODE (« SECRET_HERO »).
## Chaque héros secret a sa fiche (étoiles, classe, stats, magie, compétences) ; on en choisit un
## ou plusieurs, puis « Invoquer » les fait venir dans la cité. Ceux qu'on a déjà sont grisés.

const ACCENT := Color("9b6be0")
const CHOSEN := Color("f5b82e")

var list: VBoxContainer
var summon_button: Button
var result_box: VBoxContainer
## Fiches affichées (voir GameData.secret_hero_previews) et noms des héros choisis.
var previews: Array[Dictionary] = []
var chosen: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color("0e0f16")  # opaque : la fenêtre du code, dessous, ne doit pas se voir
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	layout.add_child(UI.make_system_window("Héros secrets", ["Choisis le ou les héros à invoquer."]))
	result_box = VBoxContainer.new()
	layout.add_child(result_box)

	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	layout.add_child(buttons)
	var close := UI.make_button("Fermer", func(): visible = false, 24)
	summon_button = UI.make_button("", _summon_chosen, 24)
	for button in [close, summon_button]:
		button.custom_minimum_size.y = 90
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)


func open() -> void:
	previews = GameData.secret_hero_previews()
	chosen = []
	for child in result_box.get_children():
		child.queue_free()
	_refresh()
	visible = true


func _refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for hero in previews:
		list.add_child(_make_entry(hero))
	summon_button.text = "Invoquer (%d)" % chosen.size()
	summon_button.disabled = chosen.is_empty()


## La fiche d'un héros secret : sa carte à gauche, ses informations à droite, et le bouton pour le choisir.
func _make_entry(hero: Dictionary) -> Control:
	var owned := GameData.owns_secret_hero(hero["name"])
	if owned:
		# Déjà dans la cité : sa vraie fiche (niveau, stats et compétences d'aujourd'hui).
		for own in GameData.roster:
			if own.get("secret", false) and own["name"] == hero["name"]:
				hero = own
	var selected: bool = hero["name"] in chosen
	var panel := PanelContainer.new()
	var border: Color = CHOSEN if selected else GameData.RARITY_COLORS[hero["rarity"]]
	panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b"), border, 4 if selected else 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	# La carte : toucher la carte choisit le héros, comme le bouton.
	var card: Button = FramedHeroCard.new(hero, 120) if Settings.new_visuals else UI.make_hero_card(hero)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.pressed.connect(_toggle.bind(hero["name"]))
	card.disabled = owned
	row.add_child(card)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var title := UI.make_label("%s  %s" % [hero["name"], "★".repeat(hero["rarity"])], 26)
	title.add_theme_color_override("font_color", GameData.RARITY_COLORS[hero["rarity"]].lightened(0.3))
	info.add_child(title)
	var hero_class: String = hero["class"]
	if hero.has("element"):
		hero_class += " (magie de %s)" % hero["element"].to_lower()
	info.add_child(UI.make_label(hero_class + " — immortel", 20))
	var stats: Dictionary = hero["stats"]
	for pair in [["str", "int"], ["vit", "dex"]]:
		var line := UI.make_label("%s %d   %s %d" % [GameData.STAT_NAMES[pair[0]], stats[pair[0]],
			GameData.STAT_NAMES[pair[1]], stats[pair[1]]], 18)
		line.modulate = Color(1, 1, 1, 0.8)
		info.add_child(line)
	var skill_names := PackedStringArray()
	for skill in hero["skills"]:
		skill_names.append("%s (niv. %d)" % [skill["name"], skill["level"]])
	var skills := UI.make_label("Compétences : " + (", ".join(skill_names) if not skill_names.is_empty() else "aucune"), 17)
	skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills.modulate = Color(1, 1, 1, 0.7)
	info.add_child(skills)

	var text := "✓ Choisi" if selected else "Choisir"
	if owned:
		text = "Déjà dans ta cité"
	var choose := UI.make_button(text, _toggle.bind(hero["name"]), 20)
	choose.custom_minimum_size.y = 56
	choose.disabled = owned
	if selected:
		choose.add_theme_color_override("font_color", CHOSEN)
	info.add_child(choose)
	if owned:
		panel.modulate = Color(1, 1, 1, 0.5)
	return panel


func _toggle(hero_name: String) -> void:
	if hero_name in chosen:
		chosen.erase(hero_name)
	else:
		chosen.append(hero_name)
	_refresh.call_deferred()


## Fait venir les héros choisis, puis annonce leur arrivée en haut de la fenêtre.
func _summon_chosen() -> void:
	var lines := []
	for hero in previews:
		if hero["name"] in chosen:
			var recruited := GameData.recruit_secret_hero(hero)
			if not recruited.is_empty():
				lines.append("%s (%s) rejoint ta cité !" % [recruited["name"], UI.rarity_text(recruited["rarity"])])
	chosen = []
	for child in result_box.get_children():
		child.queue_free()
	if not lines.is_empty():
		result_box.add_child(UI.make_system_window("Invocation réussie", lines))
	_refresh()
