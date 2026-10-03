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
## Fiche affichée : le héros et sa zone qui défile (pour la redessiner au même endroit en mode dev).
var detail_hero: Dictionary = {}
var detail_scroll: ScrollContainer
## Annonce à montrer en haut de la fiche après un outil du mode dev (+1 étoile).
var _dev_notice: Array = []


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
		var card := UI.make_card(hero)
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


## Bouton « Changer de classe » : visible seulement quand le héros peut en changer (voir GameData,
## section « Changement de classe »). Sinon, s'il a atteint le niveau mais qu'il lui manque quelque chose
## (compétence d'arme, ou il est parti), la fiche explique pourquoi.
func _add_class_change(content: VBoxContainer, hero: Dictionary) -> void:
	var problem := GameData.class_change_problem(hero)
	if problem != "":
		var why := UI.make_label(problem, 19)
		why.add_theme_color_override("font_color", Color("e0a052"))
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(why)
		return
	var options := GameData.class_change_options(hero)
	if options.is_empty():
		return
	var button := UI.make_button("Changer de classe", func(): _show_class_choice(hero, options), 24)
	button.custom_minimum_size.y = 90
	button.add_theme_color_override("font_color", Color("9ad1ff"))
	content.add_child(button)


## Fenêtre du choix de la nouvelle classe (une ou deux classes proposées), par-dessus la fiche.
## Une fois la classe choisie, la fiche se rouvre avec la fenêtre système qui l'annonce.
func _show_class_choice(hero: Dictionary, options: Array[String]) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_overlay.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 600
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var question := "Quelle voie pour %s ?" % hero["name"] if options.size() > 1 \
		else "%s peut devenir %s." % [hero["name"], options[0]]
	box.add_child(UI.make_system_window("Changement de classe", [
		"%s (%s, niveau %d) est prêt à changer de classe." % [hero["name"], hero["class"], hero["level"]],
		question,
	]))
	for new_class in options:
		var choose := UI.make_button("Devenir %s" % new_class, func():
			var lines := GameData.change_class(hero, new_class)
			overlay.queue_free()
			_refresh()
			_show_detail.call_deferred(hero, lines, "Changement de classe !"), 24)
		choose.custom_minimum_size.y = 84
		box.add_child(choose)
	var cancel := UI.make_button("Annuler", func(): overlay.queue_free(), 24)
	cancel.custom_minimum_size.y = 84
	box.add_child(cancel)


## Bouton « Favori » : met le héros en favori (cœur sur sa carte, protégé de la synthèse) ou l'en retire.
## Grisé, avec la raison, quand les GameData.FAVORITES_MAX places sont prises.
func _add_favorite_button(content: VBoxContainer, hero: Dictionary) -> void:
	if not hero["alive"]:
		return
	var count := GameData.favorites_count()
	var favorite := GameData.is_favorite(hero)
	var text := "♥ Favori — retirer des favoris" if favorite \
		else "♡ Ajouter aux favoris (%d / %d)" % [count, GameData.FAVORITES_MAX]
	var button := UI.make_button(text, func():
		GameData.toggle_favorite(hero)
		_redraw_detail.call_deferred(), 22)
	button.custom_minimum_size.y = 80
	button.add_theme_color_override("font_color", Color("ff5c8a"))
	button.disabled = not favorite and count >= GameData.FAVORITES_MAX
	content.add_child(button)
	if button.disabled:
		var why := UI.make_label("Déjà %d favoris : retire d'abord un héros des favoris." % GameData.FAVORITES_MAX, 19)
		why.add_theme_color_override("font_color", Color("e05252"))
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(why)


## Mode dev : outils de test sur ce héros (niveaux, expérience, étoiles, stats, compétences, résurrection).
## Ils passent outre les règles du jeu (voir GameData, section « Mode dev »).
func _add_dev_tools(content: VBoxContainer, hero: Dictionary) -> void:
	var title := UI.make_label("OUTILS DU MODE DEV", 24)
	title.add_theme_color_override("font_color", Color("e05252"))
	content.add_child(title)

	_add_dev_row(content, [
		["+1 niveau", func(): GameData.dev_add_levels(hero, 1)],
		["+5 niveaux", func(): GameData.dev_add_levels(hero, 5)],
		["Niveau max", func(): GameData.dev_add_levels(hero, GameData.MAX_LEVEL[hero["rarity"]])],
	])
	_add_dev_row(content, [
		["+100 XP", func(): GameData.dev_add_xp(hero, 100)],
		["+5 stats", func(): GameData.dev_add_stats(hero, 5)],
		["-5 stats", func(): GameData.dev_add_stats(hero, -5)],
	])
	_add_dev_row(content, [
		["-20 santé mentale", func(): GameData.dev_change_mental(hero, -20)],
		["Santé mentale 100", func(): GameData.dev_change_mental(hero, GameData.MENTAL_MAX)],
	])
	var star_row: Array = []
	if hero["rarity"] < GameData.MAX_PROMOTION_RARITY:
		star_row.append(["+1 étoile (gratuit)", func(): _dev_notice = GameData.dev_promote(hero)])
	if not hero["alive"]:
		star_row.append(["Ressusciter", func(): GameData.dev_revive(hero)])
	if not star_row.is_empty():
		_add_dev_row(content, star_row)

	# Donner une compétence (toutes celles du jeu), ou la monter d'un niveau si le héros l'a déjà.
	var give := HBoxContainer.new()
	give.add_theme_constant_override("separation", 8)
	content.add_child(give)
	var menu := OptionButton.new()
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.custom_minimum_size.y = 60
	menu.add_theme_font_size_override("font_size", 18)
	menu.get_popup().add_theme_font_size_override("font_size", 24)
	for skill_name in GameData.SKILLS:
		menu.add_item(skill_name)
	give.add_child(menu)
	give.add_child(_make_dev_button("Donner", func():
		GameData.dev_give_skill(hero, menu.get_item_text(menu.selected))))

	# Les compétences du héros : changer leur niveau, ou les retirer.
	for skill in hero["skills"]:
		var skill_name: String = skill["name"]
		var label := UI.make_label("%s (niv. %d)" % [skill_name, skill["level"]], 18)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)
		_add_dev_row(content, [
			["-1", func(): GameData.dev_set_skill_level(hero, skill_name, skill["level"] - 1)],
			["+1", func(): GameData.dev_set_skill_level(hero, skill_name, skill["level"] + 1)],
			["Max", func(): GameData.dev_set_skill_level(hero, skill_name, GameData.SKILL_MAX_LEVEL)],
			["Retirer", func(): GameData.dev_remove_skill(hero, skill_name)],
		])


## Une rangée de boutons du mode dev : [[texte, action], ...]. Après l'action, la fiche est redessinée.
func _add_dev_row(content: VBoxContainer, entries: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	for entry in entries:
		row.add_child(_make_dev_button(entry[0], entry[1]))


func _make_dev_button(text: String, action: Callable) -> Button:
	var button := UI.make_button(text, func():
		action.call()
		_redraw_detail.call_deferred(), 18)
	button.custom_minimum_size.y = 56
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("font_color", Color("ff9a8a"))
	return button


## Redessine la fiche du héros affiché (après un outil du mode dev, ou le bouton Favori), au même endroit de la page.
func _redraw_detail() -> void:
	var scroll_position := detail_scroll.scroll_vertical
	var notice := _dev_notice
	_dev_notice = []
	_refresh()
	_show_detail(detail_hero, notice)
	if notice.is_empty():
		await get_tree().process_frame
		detail_scroll.scroll_vertical = scroll_position


## Affiche la fiche détaillée d'un héros. « notice » : une fenêtre système à montrer en haut
## (le résultat d'une promotion, par exemple), avec le titre « notice_title ».
func _show_detail(hero: Dictionary, notice: Array = [], notice_title := "Promotion !") -> void:
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
	detail_hero = hero
	detail_scroll = scroll
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 496
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	if not notice.is_empty():
		content.add_child(UI.make_system_window(notice_title, notice))

	if Settings.new_visuals:
		# Nouveaux visuels : la carte avec son cadre (étoiles, portrait, nom, niveau et stats).
		var card_box := CenterContainer.new()
		card_box.add_child(FramedHeroCard.new(hero, FramedHeroCard.CROP.size.x, true))
		content.add_child(card_box)
	else:
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

	# Santé mentale (voir GameData, personality.gd) : la valeur, l'état d'esprit, et la barre.
	if hero["alive"]:
		var mental := GameData.mental(hero)
		var mental_label := UI.make_label("Santé mentale : %d / %d (%s)" % [roundi(mental), GameData.MENTAL_MAX,
			GameData.mental_text(hero)], 22)
		mental_label.add_theme_color_override("font_color", UI.mental_color(mental))
		content.add_child(mental_label)
		content.add_child(UI.make_mental_bar(hero))
		if GameData.mental_combat_factor(hero) < 1.0:
			var malus := UI.make_label("En combat : attaque et défense -%d %%" % roundi((1.0 - GameData.mental_combat_factor(hero)) * 100), 18)
			malus.modulate = Color(1, 1, 1, 0.7)
			content.add_child(malus)
	# Traits de caractère : « ? » tant qu'ils ne se sont pas révélés en jouant.
	content.add_child(UI.make_label("Caractère : %s" % GameData.traits_text(hero), 22))
	for t in hero.get("traits", []):
		if t["known"]:
			var trait_info := UI.make_label("%s : %s" % [t["name"], GameData.TRAITS.get(t["name"], "")], 18)
			trait_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			trait_info.modulate = Color(1, 1, 1, 0.6)
			content.add_child(trait_info)

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

	_add_favorite_button(content, hero)
	_add_class_change(content, hero)
	_add_promotion(content, hero)
	if Settings.dev_mode:
		_add_dev_tools(content, hero)

	var close := UI.make_button("Fermer", func(): detail_overlay.visible = false)
	close.custom_minimum_size.y = 90
	content.add_child(close)

	# Hauteur de la zone qui défile : celle de la fiche, sans dépasser l'écran.
	scroll.custom_minimum_size = Vector2(496, minf(content.get_combined_minimum_size().y, 880))
	detail_overlay.visible = true
