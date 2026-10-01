class_name CollectionScreen
extends Control
## Collection : les héros vivants, avec une recherche et des filtres (classe, étoiles, tri).
## Les héros morts n'y sont plus : on les retrouve avec le bouton « Tombés ».
## Appuyer sur un héros ouvre sa fiche détaillée.

var count_label: Label
var empty_label: Label
var dead_button: Button
var filter: HeroFilter
var grid: GridContainer
var detail_overlay: Control
## Vrai quand on regarde les héros tombés au lieu des vivants.
var show_dead := false


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	# En haut : le nombre de héros, et le bouton pour voir les héros tombés (ou revenir aux vivants).
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	layout.add_child(top)
	count_label = UI.make_label("", 26)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(count_label)
	dead_button = UI.make_button("", func():
		show_dead = not show_dead
		_refresh(), 20)
	dead_button.custom_minimum_size.y = 56
	top.add_child(dead_button)

	filter = HeroFilter.new()
	filter.changed.connect(_refresh)
	layout.add_child(filter)

	empty_label = UI.make_label("", 26)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

	# Les vivants (ou les tombés), puis la recherche et les filtres, qui trient aussi la liste.
	var alive := GameData.alive_heroes()
	var dead_count := GameData.roster.size() - alive.size()
	if dead_count == 0:
		show_dead = false
	var group: Array = alive
	if show_dead:
		group = GameData.roster.filter(func(hero): return not hero["alive"])
	var heroes := filter.apply(group)

	for hero in heroes:
		var card := UI.make_hero_card(hero)
		card.pressed.connect(func(): _show_detail(hero))
		grid.add_child(card)

	var title := "Héros tombés" if show_dead else "Héros"
	count_label.text = "%s : %d" % [title, group.size()]
	if heroes.size() != group.size():
		count_label.text += " (%d affichés)" % heroes.size()
	dead_button.text = "← Héros vivants" if show_dead else "Tombés (%d)" % dead_count
	dead_button.visible = dead_count > 0
	empty_label.visible = heroes.is_empty()
	if group.is_empty():
		empty_label.text = "Tu n'as encore aucun héros.\nVa dans la Salle d'invocation !"
	else:
		empty_label.text = "Aucun héros ne correspond à la recherche."


## Bouton « Promotion » : le coût (or + pierres d'attribut) est affiché ; le bouton est grisé,
## avec la raison en dessous, si le héros ne peut pas encore être promu.
func _add_promotion(content: VBoxContainer, hero: Dictionary) -> void:
	if not hero["alive"]:
		return
	var cost := GameData.promotion_cost(hero)
	if cost.is_empty():
		return  # déjà au maximum d'étoiles
	var stones := GameData.material_count(GameData.PROMOTION_STONE)
	var text := "Promotion → %s\n%d or + %d %s%s (tu en as %d)" % ["★".repeat(hero["rarity"] + 1), cost["gold"],
		cost["stones"], GameData.PROMOTION_STONE.to_lower(), "s" if cost["stones"] > 1 else "", stones]
	var button := UI.make_button(text, func():
		var lines := GameData.promote(hero)
		_refresh()
		_show_detail.call_deferred(hero, lines), 22)
	button.custom_minimum_size.y = 90
	var problem := GameData.promotion_problem(hero)
	button.disabled = problem != ""
	content.add_child(button)
	if problem != "":
		var why := UI.make_label(problem, 19)
		why.add_theme_color_override("font_color", Color("e05252"))
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(why)
	# Bouton temporaire pour tester sans monter les niveaux en combat.
	if not GameData.is_max_level(hero):
		var test := UI.make_button("+1 niveau (test)", func():
			GameData.gain_xp(hero, GameData.xp_to_next(hero["level"]) - hero["xp"])
			GameData.save_game()
			_refresh()
			_show_detail.call_deferred(hero), 20)
		test.custom_minimum_size.y = 60
		content.add_child(test)


## Affiche la fiche détaillée d'un héros. « notice » : une fenêtre système à montrer en haut
## (le résultat d'une promotion, par exemple).
func _show_detail(hero: Dictionary, notice: Array = []) -> void:
	for child in detail_overlay.get_children():
		detail_overlay.remove_child(child)
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

	# La fiche défile si elle est plus haute que l'écran (beaucoup de compétences...).
	var scroll := UI.make_scroll()
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 496
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	if not notice.is_empty():
		content.add_child(UI.make_system_window("Promotion !", notice))

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

	# Mana (mages et soigneurs) : la réserve, et ce qu'elle regagne chaque seconde en combat.
	var mana: int = GameData.combat_stats(hero)["mana"]
	if mana > 0:
		var mana_label := UI.make_label("Mana : %d (+%s par seconde en combat)" % [mana,
			String.num(hero["stats"]["int"] * Battle.MANA_REGEN_PER_INT, 1).replace(".", ",")], 22)
		mana_label.add_theme_color_override("font_color", Color("4a8fe8"))
		content.add_child(mana_label)

	# Équipement : l'arme (ou l'arme de départ) et le bouclier. Les mages se battent avec la magie.
	if GameData.uses_magic(hero):
		var magic := "Arme : aucune (magie)"
		if hero["class"] == "Mage":
			magic = "Arme : aucune (magie de %s)" % hero.get("element", "Feu").to_lower()
		content.add_child(UI.make_label(magic, 22))
	elif hero["alive"] and GameData.gears_up_on_mission(hero):
		var gear_label := UI.make_label("Arme : prend la meilleure de l'arsenal en partant en mission", 20)
		gear_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(gear_label)
	else:
		content.add_child(UI.make_label("Arme : %s" % GameData.fighting_weapon(hero)["name"], 22))
		var shield := GameData.equipped(hero, "shield")
		if not shield.is_empty():
			content.add_child(UI.make_label("Bouclier : %s" % GameData.weapon_name(shield), 22))

	# Compétences : nom, rang et niveau, puis ce qu'elle fait (en plus petit).
	content.add_child(UI.make_label("Compétences :" if not hero["skills"].is_empty() else "Compétences : aucune", 22))
	for skill in hero["skills"]:
		content.add_child(UI.make_label("%s (%s, niv. %d)" % [skill["name"], skill["rank"], skill["level"]], 22))
		var description := UI.make_label(GameData.SKILLS.get(skill["name"], ""), 18)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.modulate = Color(1, 1, 1, 0.6)
		content.add_child(description)

	# Mode Berserk : ce que la rage change (valeur de base → en Berserk, et l'écart en + ou en −).
	var berserk := GameData.berserk_preview(hero)
	if not berserk.is_empty():
		content.add_child(UI.make_label("Mode Berserk (sous 30 % de vie) :", 20))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		content.add_child(grid)
		for row in berserk:
			var name_label := UI.make_label(row[0], 19)
			name_label.modulate = Color(1, 1, 1, 0.7)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(name_label)
			var gap: int = row[2] - row[1]
			var value := UI.make_label("%d / %d (%s%d)" % [row[2], row[1], "+" if gap >= 0 else "−", absi(gap)], 19)
			value.add_theme_color_override("font_color", Color("e05252") if gap < 0 else Color("f5b82e"))
			grid.add_child(value)

	# Progrès en cours (terrain d'entraînement, tirs à l'arc...) : « Maîtrise de l'épée : 40 / 100 ».
	var progress: Dictionary = hero.get("skill_progress", {})
	for skill_name in progress:
		if progress[skill_name] > 0:
			var line := UI.make_label("Progrès — %s : %d / %d" % [skill_name, progress[skill_name],
				GameData.skill_progress_needed(skill_name)], 18)
			line.modulate = Color(1, 1, 1, 0.6)
			content.add_child(line)
	if hero["alive"]:
		var activity := GameData.activity_text(hero)
		if hero.get("training", "") != "" and not GameData.is_away(hero):
			activity += " (%s)" % hero["training"]
		content.add_child(UI.make_label("Occupation : %s" % activity, 20))

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

	_add_promotion(content, hero)

	var close := UI.make_button("Fermer", func(): detail_overlay.visible = false)
	close.custom_minimum_size.y = 90
	content.add_child(close)

	# Hauteur de la zone qui défile : celle de la fiche, sans dépasser l'écran.
	scroll.custom_minimum_size = Vector2(496, minf(content.get_combined_minimum_size().y, 880))
	detail_overlay.visible = true
