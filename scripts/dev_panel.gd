class_name DevPanel
extends Control
## Fenêtre « Outils du mode dev » (Paramètres, seulement en mode dev) : outils de test pour tout le jeu.
## Les outils pour un héros précis sont sur sa fiche (Collection). Les règles sont dans GameData
## (section « Mode dev »). L'or et les gemmes sont infinis tant que le mode dev est actif.

const DANGER_COLOR := Color("e05252")

var result_label: Label
var floor_label: Label
var class_menu: OptionButton
var grade_menu: OptionButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var panel := PanelContainer.new()
	var style := UI.make_panel_style(Color("1f1416"), DANGER_COLOR, 3)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title := UI.make_label("OUTILS DU MODE DEV", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", DANGER_COLOR.lightened(0.2))
	layout.add_child(title)
	result_label = UI.make_label("", 20)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_color_override("font_color", Color("f5b82e"))
	layout.add_child(result_label)

	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	_add_section(content, "Or et gemmes : infinis")
	_add_note(content, "Les dépenses et les gains ne comptent pas : tes vraies réserves reviennent en quittant le mode dev.")

	# Créer un héros : classe au choix (ou au hasard), puis un bouton par nombre d'étoiles.
	_add_section(content, "Créer un héros")
	class_menu = _make_menu(["Classe au hasard"] + GameData.CLASS_MAIN_STAT.keys())
	content.add_child(class_menu)
	var stars := []
	for rarity in range(1, 6):
		stars.append(["%d★" % rarity, func():
			var hero_class := "" if class_menu.selected <= 0 else class_menu.get_item_text(class_menu.selected)
			var hero := GameData.dev_create_hero(rarity, hero_class)
			return "%s (%s, %s) rejoint ta cité." % [hero["name"], "★".repeat(rarity), hero["class"]]])
	_add_row(content, stars)
	_add_note(content, "Pour les niveaux, l'expérience, les étoiles, les stats et les compétences d'un héros : sa fiche, dans la Collection.")

	_add_section(content, "Tour")
	floor_label = UI.make_label("", 22)
	content.add_child(floor_label)
	_add_row(content, [
		["-1 étage", func(): return _move_floor(-1)],
		["+1 étage", func(): return _move_floor(1)],
		["+5 étages", func(): return _move_floor(5)],
	])

	_add_section(content, "Lieux")
	_add_row(content, [["Ouvrir le terrain d'entraînement", func():
		GameData.dev_unlock_training()
		return "Le terrain d'entraînement est ouvert."]])
	_add_row(content, [["Séance d'entraînement maintenant", func():
		GameData.dev_training_session()
		return "Les héros à l'entraînement ont fait une séance (voir le terrain)."]])
	_add_row(content, [["Terminer les expéditions en cours", func():
		if GameData.expeditions.is_empty():
			return "Aucune expédition en cours (le donjon journalier s'ouvre après l'étage %d)." % GameData.DAILY_UNLOCK_FLOOR
		GameData.dev_finish_expedition()
		return "Les groupes sont revenus (voir l'écran Donjons)."]])
	_add_row(content, [["Construire tous les bâtiments", func():
		GameData.dev_build_all()
		return "Tous les bâtiments sont construits."]])

	_add_section(content, "Objets")
	grade_menu = _make_menu(GameData.WEAPON_GRADES.keys().map(func(grade): return "Grade " + grade))
	content.add_child(grade_menu)
	_add_row(content, [["+10 de chaque matériau et pierres", func():
		var grade: String = GameData.WEAPON_GRADES.keys()[grade_menu.selected]
		GameData.dev_add_materials(grade, 10)
		return "+10 de chaque matériau (grade %s) et +10 %s." % [grade, GameData.PROMOTION_STONE.to_lower()]]])
	_add_row(content, [["Tous les plans de forge", func():
		GameData.dev_all_plans()
		return "Tu as tous les plans de forge."]])

	var quit := UI.make_button("Quitter le mode dev", func():
		Settings.change("dev_mode", false)
		visible = false, 24)
	quit.custom_minimum_size.y = 80
	quit.add_theme_color_override("font_color", DANGER_COLOR)
	layout.add_child(quit)
	var close := UI.make_button("Fermer", func(): visible = false, 24)
	close.custom_minimum_size.y = 80
	layout.add_child(close)


func open() -> void:
	result_label.text = ""
	_refresh_floor()
	visible = true


func _move_floor(step: int) -> String:
	GameData.dev_set_floor(GameData.tower_floor + step)
	_refresh_floor()
	return "Prochain étage de la Tour : %d." % GameData.tower_floor


func _refresh_floor() -> void:
	floor_label.text = "Prochain étage à conquérir : %d" % GameData.tower_floor


func _add_section(parent: Control, text: String) -> void:
	var label := UI.make_label(text, 26)
	label.add_theme_color_override("font_color", Color("f5b82e"))
	parent.add_child(label)


func _add_note(parent: Control, text: String) -> void:
	var label := UI.make_label(text, 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(1, 1, 1, 0.7)
	parent.add_child(label)


## Une rangée de boutons : [[texte, action], ...]. L'action renvoie le texte à afficher en haut.
func _add_row(parent: Control, entries: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	for entry in entries:
		var action: Callable = entry[1]
		var button := UI.make_button(entry[0], func(): result_label.text = str(action.call()), 20)
		button.custom_minimum_size.y = 64
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)


func _make_menu(items: Array) -> OptionButton:
	var menu := OptionButton.new()
	menu.custom_minimum_size.y = 64
	menu.add_theme_font_size_override("font_size", 20)
	menu.get_popup().add_theme_font_size_override("font_size", 26)
	for item in items:
		menu.add_item(item)
	return menu
