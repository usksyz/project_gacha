class_name ForgeScreen
extends Control
## Forge (ouverte depuis l'Armurerie, dont elle est l'annexe) : on choisit une arme et le grade
## du matériau principal, puis on la fabrique :
## - « Production automatique » : un simple tirage, l'arme reste à son rang de base ;
## - « À la main » : le puzzle de forge (ForgePuzzle), avec une difficulté au choix.
## Avant de lancer, une fenêtre montre la chance de succès et demande Oui / Non.
## Les règles sont dans GameData (section « Forge »).

## Demande à l'écran principal d'afficher un autre écran (retour à l'armurerie).
signal navigate(screen_name: String)

var content: VBoxContainer
## Calque par-dessus l'écran : confirmation, puzzle, résultat.
var overlay: Control

## Arme choisie et grade du matériau principal choisi.
var weapon_type := "Épée"
var material_grade := ""


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var back := UI.make_button("← Retour à l'armurerie", func(): navigate.emit("armory"), 22)
	back.custom_minimum_size.y = 64
	layout.add_child(back)
	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)


func on_shown() -> void:
	# Un puzzle en cours reste affiché (on peut changer d'onglet sans le perdre).
	if not overlay.visible:
		_refresh()


func _refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

	if not GameData.forge_built():
		var closed := UI.make_label("La forge n'est pas encore construite. Construis-la depuis le hub (bouton « Construction », %d gemmes), une fois le terrain d'entraînement ouvert." \
			% GameData.BUILDINGS["forge"]["cost"], 22)
		closed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(closed)
		return

	_add_section("Entrepôt", _warehouse_lines())
	_add_section("Assistants", _assistant_lines())

	# Choix de l'arme : un bouton par type.
	content.add_child(UI.make_label("Arme à forger", 24))
	var types := GridContainer.new()
	types.columns = 3
	types.add_theme_constant_override("h_separation", 8)
	types.add_theme_constant_override("v_separation", 8)
	content.add_child(types)
	for type in GameData.FORGE_RECIPES:
		var button := _make_choice(type, type == weapon_type, func():
			weapon_type = type
			material_grade = ""
			_refresh.call_deferred())
		types.add_child(button)

	var recipe: Dictionary = GameData.FORGE_RECIPES[weapon_type]
	var parts := ["%d %s" % [recipe["qty"], recipe["main"]]]
	for material in recipe["extra"]:
		parts.append("%d %s" % [recipe["extra"][material], material])
	content.add_child(_small("Recette : %s. Le grade du %s donne le rang de base de l'arme." % [
		" + ".join(parts), recipe["main"].to_lower()]))

	# Choix du grade du matériau principal, parmi ceux dont on a assez.
	var grades := GameData.forge_grades(weapon_type)
	if grades.is_empty():
		content.add_child(_small("Pas assez de matériaux. Envoie une équipe au donjon journalier !"))
		return
	if not material_grade in grades:
		material_grade = grades[0]  # le meilleur grade disponible
	var grade_row := HFlowContainer.new()
	grade_row.add_theme_constant_override("h_separation", 8)
	grade_row.add_theme_constant_override("v_separation", 8)
	content.add_child(grade_row)
	for grade in grades:
		grade_row.add_child(_make_choice("%s (%d)" % [grade, GameData.material_count(recipe["main"], grade)],
			grade == material_grade, func():
				material_grade = grade
				_refresh.call_deferred()))

	var base := GameData.forge_base_grade(weapon_type, material_grade)
	var lines := ["Rang de base : %s%s" % [base, " (plan : +1 cran)" if weapon_type in GameData.plans else ""]]
	var maluses := GameData.forge_maluses(weapon_type)
	for malus in maluses:
		lines.append("Malus : %s" % GameData.MALUS_NAMES[malus])
	if maluses.is_empty():
		lines.append("Aucun malus.")
	_add_section("%s [%s]" % [weapon_type, base], lines)

	var auto_chance := GameData.forge_chance(weapon_type, "auto")
	var auto := UI.make_button("Production automatique — chance : %s" % GameData.chance_word(auto_chance),
		func(): _confirm("auto"), 22)
	auto.custom_minimum_size.y = 80
	content.add_child(auto)

	content.add_child(UI.make_label("À la main (puzzle, 3 minutes) :", 24))
	for difficulty in GameData.FORGE_DIFFICULTIES:
		var info: Dictionary = GameData.FORGE_DIFFICULTIES[difficulty]
		var chance := GameData.forge_chance(weapon_type, difficulty)
		var button := UI.make_button("%s — jusqu'à +%d cran%s — chance : %s" % [difficulty, info["bonus"],
			"s" if info["bonus"] > 1 else "", GameData.chance_word(chance)], func(): _confirm(difficulty), 22)
		button.custom_minimum_size.y = 70
		content.add_child(button)


func _warehouse_lines() -> Array:
	var lines := []
	for material in GameData.warehouse:
		var by_grade: Dictionary = GameData.warehouse[material]
		if by_grade.is_empty():
			continue
		var parts := []
		for grade in GameData.WEAPON_GRADES:
			if by_grade.has(grade):
				parts.append("%s x%d" % [grade, by_grade[grade]])
		lines.append("%s : %s" % [material, ", ".join(parts)])
	if lines.is_empty():
		lines.append("Vide. Les matériaux viennent du donjon journalier.")
	if not GameData.plans.is_empty():
		lines.append("Plans : %s" % ", ".join(GameData.plans))
	return lines


func _assistant_lines() -> Array:
	var lines := []
	for hero in GameData.posted_heroes("forge"):
		var text := "%s (%s)" % [hero["name"], "★".repeat(hero["rarity"])]
		var level := GameData.skill_level(hero["skills"], "Forge")
		if level > 0:
			text += " — artisan, niv. %d" % level
		else:
			text += " — apprenti (%d / %d)" % [GameData.skill_progress(hero, "Forge"), GameData.TRAINING_POINTS_PER_LEVEL]
		if GameData.is_away(hero):
			text += " — absent"
		lines.append(text)
	if lines.is_empty():
		lines.append("Aucun. Affecte des héros à la forge depuis le hub (bouton « Affectations »).")
	return lines


func _add_section(title: String, lines: Array) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b")))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(UI.make_label(title, 24))
	for line in lines:
		box.add_child(_small(line))
	content.add_child(panel)


func _small(text: String) -> Label:
	var label := UI.make_label(text, 19)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(1, 1, 1, 0.8)
	return label


func _make_choice(text: String, selected: bool, on_press: Callable) -> Button:
	var button := UI.make_button(text, on_press, 22)
	button.custom_minimum_size = Vector2(150, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.button_pressed = selected
	return button


# ---------------------------------------------------------------------------
# Confirmation, puzzle et résultat
# ---------------------------------------------------------------------------

func _clear_overlay() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()


## Fenêtre de confirmation : chance de succès, puis Oui / Non.
func _confirm(difficulty: String) -> void:
	_clear_overlay()
	var chance := GameData.forge_chance(weapon_type, difficulty)
	var how := "Production automatique" if difficulty == "auto" else "À la main (%s)" % difficulty
	var box := _overlay_box()
	box.add_child(UI.make_system_window("Forge", [
		"%s [%s] — %s" % [weapon_type, GameData.forge_base_grade(weapon_type, material_grade), how],
		"Probabilité de succès : %s" % GameData.chance_word(chance),
		"En cas d'échec, les matériaux sont perdus.",
		"Lancer la fabrication ?"]))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	for entry in [["Non", func(): overlay.visible = false], ["Oui", func(): _start(difficulty)]]:
		var button := UI.make_button(entry[0], entry[1], 26)
		button.custom_minimum_size.y = 90
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	overlay.visible = true


func _start(difficulty: String) -> void:
	if difficulty == "auto":
		var result := GameData.forge_auto(weapon_type, material_grade)
		if not result["ok"]:
			overlay.visible = false
			_refresh()
			return
		_show_result(result["success"], "Succès" if result["success"] else "Échec", result)
		return
	if not GameData.forge_manual_begin(weapon_type, material_grade):
		overlay.visible = false
		_refresh()
		return
	_clear_overlay()
	var puzzle := ForgePuzzle.new()
	var type := weapon_type
	var grade := material_grade
	puzzle.setup(difficulty, GameData.forge_maluses(type), "%s [%s]" % [type, GameData.forge_base_grade(type, grade)])
	puzzle.finished.connect(func(success: bool, bonus: int, result_name: String):
		var result := GameData.forge_manual_end(type, grade, success, bonus)
		_show_result(success, result_name, result))
	overlay.add_child(puzzle)
	overlay.visible = true


## Fenêtre du résultat : l'arme obtenue (qui rejoint l'arsenal) ou l'échec.
func _show_result(success: bool, result_name: String, result: Dictionary) -> void:
	_clear_overlay()
	var lines := []
	if success:
		lines.append("%s ! %s rejoint l'arsenal." % [result_name, GameData.weapon_name(result["weapon"])])
	else:
		lines.append("Échec... les matériaux sont perdus.")
	lines.append_array(result.get("news", []))
	var box := _overlay_box()
	box.add_child(UI.make_system_window("Forge", lines, not success))
	var ok := UI.make_button("Compris", func():
		overlay.visible = false
		_refresh(), 26)
	ok.custom_minimum_size.y = 90
	box.add_child(ok)
	overlay.visible = true


## Fond sombre et boîte centrée dans le calque.
func _overlay_box() -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	overlay.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	return box
