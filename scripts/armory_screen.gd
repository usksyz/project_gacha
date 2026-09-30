class_name ArmoryScreen
extends Control
## Armurerie (ouverte depuis le hub) : tirage d'armes payé en or, arsenal, et équipement des héros.
## Les armes tirées vont dans l'arsenal, puis les héros s'équipent d'eux-mêmes (GameData.auto_equip).
## Le Maître peut aussi choisir l'arme d'un héros : ce héros ne change alors plus d'arme tout seul,
## jusqu'à ce qu'on appuie sur « Auto ». Les règles sont dans GameData (section « Armes »).

## Demande à l'écran principal d'afficher un autre écran (retour au hub).
signal navigate(screen_name: String)

## Couleur des grades, selon leur lettre (F gris, E vert, D bleu, C violet).
const GRADE_COLORS := {
	"F": Color("8a8f98"), "E": Color("4caf6a"), "D": Color("3d8fe0"), "C": Color("a35ce0"),
}

var info_label: Label
var result_box: VBoxContainer
var arsenal_box: HFlowContainer
var arsenal_title: Label
var heroes_box: VBoxContainer
## Calque pour choisir une arme dans l'arsenal, par-dessus l'écran.
var picker: Control


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var back := UI.make_button("← Retour à la cité", func(): navigate.emit("hub"), 22)
	back.custom_minimum_size.y = 64
	layout.add_child(back)

	# Tirage x1 et x10.
	var draw_row := HBoxContainer.new()
	draw_row.add_theme_constant_override("separation", 12)
	layout.add_child(draw_row)
	for count in [1, 10]:
		var button := UI.make_button("Tirage x%d\n%d or" % [count, GameData.WEAPON_DRAW_COST * count],
			func(): _draw_weapons(count), 24)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 100
		draw_row.add_child(button)
	info_label = UI.make_label("", 20)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.modulate = Color(1, 1, 1, 0.75)
	layout.add_child(info_label)

	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	result_box = VBoxContainer.new()
	content.add_child(result_box)
	arsenal_title = UI.make_label("", 24)
	content.add_child(arsenal_title)
	arsenal_box = HFlowContainer.new()
	arsenal_box.add_theme_constant_override("h_separation", 8)
	arsenal_box.add_theme_constant_override("v_separation", 8)
	content.add_child(arsenal_box)
	content.add_child(UI.make_label("Équipement des héros", 24))
	heroes_box = VBoxContainer.new()
	heroes_box.add_theme_constant_override("separation", 12)
	content.add_child(heroes_box)

	picker = Control.new()
	picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker.visible = false
	add_child(picker)


func on_shown() -> void:
	picker.visible = false
	for child in result_box.get_children():
		child.queue_free()
	info_label.text = "Les armes rangées dans l'arsenal équipent les héros automatiquement."
	_refresh()


func _draw_weapons(count: int) -> void:
	var weapons := GameData.draw_weapons(count)
	for child in result_box.get_children():
		child.queue_free()
	if weapons.is_empty():
		info_label.text = "Pas assez d'or : il faut %d or." % (GameData.WEAPON_DRAW_COST * count)
		return
	var lines := []
	for weapon in weapons:
		lines.append(GameData.weapon_name(weapon))
	result_box.add_child(UI.make_system_window("Tirage d'armes", lines))
	# Annonce de l'ouverture du terrain d'entraînement, au tirage qui la déclenche.
	var before: int = GameData.weapon_draws - weapons.size()
	if before < GameData.TRAINING_UNLOCK_DRAWS and GameData.training_unlocked():
		result_box.add_child(UI.make_system_window("Félicitations !",
			["Le terrain d'entraînement a été construit avec succès !"]))
	info_label.text = "Les nouvelles armes sont dans l'arsenal ; les héros prennent celles qui leur conviennent."
	_refresh()


## Redessine l'arsenal (armes rangées) et l'équipement de chaque héros vivant.
func _refresh() -> void:
	for box in [arsenal_box, heroes_box]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()

	var free := GameData.free_weapons()
	arsenal_title.text = "Arsenal : %d arme%s rangée%s" % [free.size(), "s" if free.size() > 1 else "", "s" if free.size() > 1 else ""]
	for weapon in free:
		arsenal_box.add_child(_make_weapon_tag(weapon))

	for hero in GameData.alive_heroes():
		heroes_box.add_child(_make_hero_row(hero))


## Petite étiquette colorée « Épée [D+] ».
func _make_weapon_tag(weapon: Dictionary) -> Control:
	var color := grade_color(weapon["grade"])
	var panel := PanelContainer.new()
	var style := UI.make_panel_style(color.darkened(0.6), color, 2)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(UI.make_label(GameData.weapon_name(weapon), 20))
	return panel


static func grade_color(grade: String) -> Color:
	return GRADE_COLORS.get(grade.left(1), Color.WHITE)


## Carte d'un héros : son arme, son bouclier, et les boutons pour les changer.
func _make_hero_row(hero: Dictionary) -> Control:
	var color: Color = GameData.RARITY_COLORS[hero["rarity"]]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b"), color, 2))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UI.make_label("%s (%s) — %s, niv. %d" % [hero["name"], "★".repeat(hero["rarity"]),
		hero["class"], hero["level"]], 24))

	if GameData.uses_magic(hero):
		var magic := UI.make_label("Se bat avec la magie : pas d'arme.", 20)
		magic.modulate = Color(1, 1, 1, 0.7)
		box.add_child(magic)
		return panel

	var weapon := GameData.fighting_weapon(hero)
	var from_arsenal := not GameData.equipped(hero, "weapon").is_empty()
	box.add_child(UI.make_label("Arme : %s%s" % [weapon["name"], "" if from_arsenal else " (arme de départ)"], 20))
	var shield := GameData.equipped(hero, "shield")
	var shield_text := "aucun" if shield.is_empty() else GameData.weapon_name(shield)
	if weapon["type"] == "Arc":
		shield_text = "impossible avec un arc"
	box.add_child(UI.make_label("Bouclier : %s" % shield_text, 20))
	var mode := UI.make_label("Équipement choisi par le Maître" if hero.get("manual_gear", false) \
		else "S'équipe tout seul", 18)
	mode.modulate = Color(1, 1, 1, 0.6)
	box.add_child(mode)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	for entry in [["Arme", "weapon"], ["Bouclier", "shield"]]:
		var button := UI.make_button(entry[0], func(): _open_picker(hero, entry[1]), 22)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 64
		button.disabled = entry[1] == "shield" and weapon["type"] == "Arc"
		buttons.add_child(button)
	var auto := UI.make_button("Auto", func():
		GameData.set_auto_gear(hero)
		_refresh(), 22)
	auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto.custom_minimum_size.y = 64
	auto.disabled = not hero.get("manual_gear", false)
	buttons.add_child(auto)
	return panel


## Fenêtre pour choisir l'arme (ou le bouclier) d'un héros parmi celles de l'arsenal.
func _open_picker(hero: Dictionary, slot: String) -> void:
	for child in picker.get_children():
		child.queue_free()

	var dim := Button.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.set_button_style(dim, UI.make_panel_style(Color(0, 0, 0, 0.75)), UI.make_panel_style(Color(0, 0, 0, 0.75)))
	dim.pressed.connect(func(): picker.visible = false)
	picker.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	picker.add_child(margin)
	var panel := PanelContainer.new()
	var style := UI.make_panel_style(Color("262a3b"), Color("9b6be0"), 3)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var title := "Bouclier" if slot == "shield" else "Arme"
	layout.add_child(UI.make_label("%s de %s" % [title, hero["name"]], 28))
	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var count := 0
	for weapon in GameData.free_weapons():
		if (weapon["type"] == "Bouclier") != (slot == "shield"):
			continue
		var text := "%s — %s" % [GameData.weapon_name(weapon), GameData.WEAPON_TYPES[weapon["type"]]["info"]]
		var button := UI.make_button(text, func():
			GameData.equip(hero, weapon)
			picker.visible = false
			_refresh(), 20)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 70
		button.add_theme_color_override("font_color", grade_color(weapon["grade"]).lightened(0.3))
		list.add_child(button)
		count += 1
	if count == 0:
		list.add_child(UI.make_label("Rien de ce genre dans l'arsenal. Fais un tirage !", 20))

	var remove_text := "Retirer le bouclier" if slot == "shield" else "Reprendre l'arme de départ"
	var remove := UI.make_button(remove_text, func():
		GameData.unequip(hero, slot)
		picker.visible = false
		_refresh(), 22)
	remove.custom_minimum_size.y = 70
	layout.add_child(remove)
	var cancel := UI.make_button("Annuler", func(): picker.visible = false, 22)
	cancel.custom_minimum_size.y = 70
	layout.add_child(cancel)
	picker.visible = true
