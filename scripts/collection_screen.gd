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
## Titre de la fenêtre de ce résultat (« Promotion ! », « Liens »...).
var _dev_notice_title := "Promotion !"


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
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		"%s (%s, niveau %d) est prêt à changer de classe." % [hero["name"], GameData.class_label(hero), hero["level"]],
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
		["Mettre en rupture", func(): GameData.dev_break(hero)],
	])
	var star_row: Array = []
	if hero["rarity"] < GameData.MAX_PROMOTION_RARITY:
		star_row.append(["+1 étoile (gratuit)", func(): _dev_notice = GameData.dev_promote(hero)])
	if not hero["alive"]:
		star_row.append(["Ressusciter", func(): GameData.dev_revive(hero)])
	if not star_row.is_empty():
		_add_dev_row(content, star_row)

	# Immortel : seulement en mode dev (hors du mode dev, tous les héros sont mortels, héros secrets compris).
	var immortal := CheckBox.new()
	immortal.text = "Immortel (mode dev) : à terre au lieu de mourir"
	immortal.button_pressed = hero.get("immortal", false)
	immortal.add_theme_font_size_override("font_size", 20)
	immortal.add_theme_color_override("font_color", Color("ff9a8a"))
	immortal.custom_minimum_size.y = 56
	immortal.toggled.connect(func(on: bool):
		GameData.dev_set_immortal(hero, on)
		_redraw_detail.call_deferred())
	content.add_child(immortal)

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

	# Monter un lien d'un cran avec un autre héros, cherché par son nom (clavier de l'appareil).
	var bond_row := HBoxContainer.new()
	bond_row.add_theme_constant_override("separation", 8)
	content.add_child(bond_row)
	var partner := LineEdit.new()
	partner.placeholder_text = "Nom d'un autre héros"
	partner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	partner.custom_minimum_size.y = 60
	partner.add_theme_font_size_override("font_size", 20)
	bond_row.add_child(partner)
	bond_row.add_child(_make_dev_button("Lien +1 cran", func():
		_dev_notice_title = "Liens"
		_dev_notice = [GameData.dev_raise_bond(hero, partner.text)]))
	bond_row.add_child(_make_dev_button("Rendre hostile", func():
		_dev_notice_title = "Hostilité"
		_dev_notice = [GameData.dev_make_hostile(hero, partner.text)]))

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

	_add_personality_tools(content, hero)


## Mode dev : la personnalité v2 (cahier, onglets « Personnalité ») : métier, couches, talent, effort, tics,
## puis les 18 axes en curseurs par paliers de 10, groupés par famille (palier, nom du palier, points
## d'évolution), les composites, les accès ouverts, les tensions et les scores des comportements.
## Hors du mode dev, rien de tout cela n'est montré : le Maître ne voit pas de chiffres.
func _add_personality_tools(content: VBoxContainer, hero: Dictionary) -> void:
	if not hero.has("persona"):
		return
	var persona: Dictionary = hero["persona"]
	var title := UI.make_label("PERSONNALITÉ (mode dev)", 24)
	title.add_theme_color_override("font_color", Color("e05252"))
	content.add_child(title)

	var metier: Dictionary = PersonalityData.METIERS.get(persona["metier"], {})
	var lines: Array[String] = []
	lines.append("%s : %s (lien avec le combat %d / 3)" % ["Métier" if hero["rarity"] <= 2 else "Passé",
		metier.get("name", "?"), metier.get("combat", 0)])
	var layer_parts: Array[String] = []
	for layer_id in PersonalityData.LAYERS:
		var layer: Dictionary = PersonalityData.LAYERS[layer_id]
		layer_parts.append("%s : %s" % [layer["name"], layer["options"].get(persona["layers"].get(layer_id, ""), {}).get("name", "?")])
	lines.append(" · ".join(layer_parts))
	var aptitude_parts: Array[String] = []
	for domain in PersonalityData.APTITUDE_DOMAINS:
		aptitude_parts.append("%s %d" % [PersonalityData.APTITUDE_DOMAINS[domain], persona["aptitudes"].get(domain, 0)])
	lines.append("Talent : croissance %d ; aptitudes %s" % [hero["growth"], ", ".join(aptitude_parts)])
	lines.append("Effort : %.0f · acharnement x%.2f" % [persona["effort"], PersonalityEngine.acharnement(hero)])
	lines.append("Tics : %s" % " ; ".join(persona["tics"].map(func(tic_id): return PersonalityEngine.tic_text(tic_id))))
	# Anciens traits lus sur les paliers (révélés ou non), et ceux gardés d'une ancienne sauvegarde.
	var trait_parts: Array = GameData.hero_traits(hero).map(func(t): return t["name"] + ("" if t["known"] else " (caché)"))
	lines.append("Traits : %s" % (", ".join(trait_parts) if not trait_parts.is_empty() else "aucun"))
	if not persona.get("legacy_traits", []).is_empty():
		lines.append("Gardés de l'ancienne version (le profil ne peut pas les donner) : %s" % ", ".join(persona["legacy_traits"]))
	if persona.get("secret_profile", false):
		var note_parts: Array = []
		for layer_id in persona.get("layer_notes", {}):
			note_parts.append("%s : %s" % [PersonalityData.LAYERS[layer_id]["name"], persona["layer_notes"][layer_id]])
		note_parts.append_array(persona.get("notes", []))
		lines.append("Profil écrit à la main. %s" % " ; ".join(note_parts))
	for line in lines:
		var label := UI.make_label(line, 17)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)

	# Les 18 curseurs, par famille. « − » et « + » changent le palier ; « évo » ajoute 10 points
	# d'évolution vers ce pôle (à la vitesse de la famille : le tempérament ne bouge presque pas).
	for family_id in PersonalityData.FAMILIES:
		var family_label := UI.make_label(PersonalityData.FAMILIES[family_id]["name"], 20)
		family_label.add_theme_color_override("font_color", Color("ff9a8a"))
		content.add_child(family_label)
		for axis_id in PersonalityData.AXIS_ORDER:
			if PersonalityData.AXES[axis_id]["family"] != family_id:
				continue
			_add_axis_slider(content, hero, axis_id)

	var composite_parts: Array[String] = []
	for composite_id in PersonalityData.COMPOSITES:
		composite_parts.append("%s %+d" % [PersonalityData.COMPOSITES[composite_id]["name"], PersonalityEngine.composite(hero, composite_id)])
	var behaviour_parts: Array[String] = []
	for behaviour_id in PersonalityData.BEHAVIOURS:
		behaviour_parts.append("%s %+.0f" % [PersonalityData.BEHAVIOURS[behaviour_id]["name"], PersonalityEngine.score(hero, behaviour_id)])
	var access_lines: Array = PersonalityEngine.accesses(hero).map(func(access_id): return "• " + PersonalityEngine.access_text(access_id))
	var tension_names: Array = PersonalityEngine.tensions(hero).map(func(tension_id): return PersonalityData.TENSIONS[tension_id]["name"])
	var modifier_lines: Array = PersonalityEngine.modifier_lines(hero).map(func(line): return "• " + line)
	for line in ["Composites : " + ", ".join(composite_parts),
			"Comportements : " + ", ".join(behaviour_parts),
			"Accès ouverts :\n" + ("\n".join(access_lines) if not access_lines.is_empty() else "aucun"),
			"Tensions : " + (", ".join(tension_names) if not tension_names.is_empty() else "aucune"),
			"Effets en jeu (P2) :\n" + ("\n".join(modifier_lines) if not modifier_lines.is_empty() else "aucun (neutre)"),
			"Affinités (compétences à condition) :\n" + "\n".join(PersonalityEngine.affinity_lines(hero).map(func(line): return "• " + line))]:
		var label := UI.make_label(line, 17)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)
	_add_dev_row(content, [["Nouveau tirage de la personnalité", func(): GameData.dev_reroll_personality(hero)]])
	_add_p1b_tools(content, hero)


## Mode dev, personnalité P1b (structures sans effet en jeu) : les 8 briques, les cercles et le visage du
## héros cercle par cercle, ses sujets (appréhension, connaissance), ses dernières décisions et leurs
## raisons, son dernier combat ; et de quoi tester (rencontre simulée, bibliothèque, mémorial).
func _add_p1b_tools(content: VBoxContainer, hero: Dictionary) -> void:
	var D := PersonalityData
	var E := PersonalityEngine
	var lines: Array[String] = []
	# Les 8 briques.
	var mind := E.mind(hero)
	var need_parts: Array[String] = []
	for need_id in D.NEEDS:
		need_parts.append("%s %.0f (poids x%.2f)" % [D.NEEDS[need_id]["name"], E.need(hero, need_id), E.need_weight(hero, need_id)])
	var expectation_parts: Array[String] = []
	for expectation_id in D.EXPECTATIONS:
		expectation_parts.append("%s %.0f" % [D.EXPECTATIONS[expectation_id]["name"], mind.get("expectations", {}).get(expectation_id, 0.0)])
	var opinion_parts: Array[String] = []
	for other_id in mind.get("opinions", {}):
		var others := GameData.roster.filter(func(other): return str(other["id"]) == other_id)
		opinion_parts.append("%s %+.0f" % [others[0]["name"] if not others.is_empty() else "#" + other_id, mind["opinions"][other_id]])
	lines.append("BRIQUES — Besoins : " + ", ".join(need_parts))
	lines.append("Pensées : %d · Attentes : %s · Dissonance : %.1f · Souvenirs : %d" % [mind.get("thoughts", []).size(),
		", ".join(expectation_parts), mind.get("dissonance", 0.0), mind.get("memories", []).size()])
	lines.append("Opinions : %s · Confiance envers le Maître : %+.0f" % [", ".join(opinion_parts) if not opinion_parts.is_empty() else "aucune", E.trust(hero)])
	lines.append("Adaptation : %s · Désirs : %s" % [mind.get("coping", {}).get("habits", {}), ", ".join(mind.get("desires", [])) if mind.get("desires", []) else "aucun"])
	# Les cercles.
	var stance: Dictionary = D.HIERARCHY_STANCES.get(E.hierarchy_stance(hero), {})
	var debt_names: Array = E.debts(hero).map(func(debt):
		var savior := GameData.roster.filter(func(other): return other["id"] == debt["id"])
		return savior[0]["name"] if not savior.is_empty() else "#%d" % debt["id"])
	lines.append("CERCLES — Rapport à la hiérarchie : %s · Dettes de vie : %s" % [stance.get("name", "?"),
		", ".join(debt_names) if not debt_names.is_empty() else "aucune"])
	for circle_id in D.CIRCLES:
		var face := E.circle_face(hero, circle_id)
		var face_parts: Array[String] = []
		for axis_id in face:
			face_parts.append("%s %+d → %+d" % [D.AXES[axis_id]["name"], face[axis_id][0] * 10, face[axis_id][1] * 10])
		lines.append("  %s : %s" % [D.CIRCLES[circle_id], ", ".join(face_parts) if not face_parts.is_empty() else "comme d'habitude"])
	var circle_parts: Array[String] = []
	for other in GameData.alive_heroes():
		if other["id"] != hero["id"]:
			circle_parts.append("%s : %s" % [other["name"], E.circle(hero, other)])
	if not circle_parts.is_empty():
		lines.append("  Les autres héros pour lui : " + ", ".join(circle_parts.slice(0, 12)))
	# Les sujets.
	var subject_parts: Array[String] = []
	for subject in E.subjects(hero):
		var entry: Dictionary = E.subjects(hero)[subject]
		var level: int = entry["knowledge"]
		var marks: Array[String] = []
		if entry.get("prior", false):
			marks.append("connu avant l'invocation")
		if entry.get("scar", false):
			marks.append("cicatrice")
		if entry.get("hate", false):
			marks.append("haine")
		subject_parts.append("%s : appréhension %.0f, connaissance %d%s%s" % [D.SUBJECTS.get(subject, {}).get("name", subject),
			E.apprehension(hero, subject), level, " (" + D.KNOWLEDGE_LEVELS[level]["name"] + ")" if level > 0 else "",
			" — " + ", ".join(marks) if not marks.is_empty() else ""])
	lines.append("SUJETS — " + ("\n".join(subject_parts) if not subject_parts.is_empty() else "aucun encore"))
	lines.append("À consigner à la bibliothèque : %d élément(s)" % E.pending_report(hero).size())
	# Le pourquoi des décisions, et le dernier combat.
	for decision in E.decisions(hero).slice(-3):
		lines.append("DÉCISION « %s » → %s : %s" % [decision["what"], decision["chosen"],
			" ; ".join(decision["reasons"].map(func(reason): return "%s (%+.1f)" % [reason["why"], reason["weight"]]))])
	var battles: Array = hero.get("recent_battles", [])
	if not battles.is_empty():
		var last: Dictionary = battles.back()
		lines.append("DERNIER COMBAT — étage %d, %s, %s ; formations : %s ; %s ; %d événements : %s" % [last["floor"],
			"victoire" if last["victory"] else "défaite", "survécu" if last["survived"] else "mort",
			", ".join(last["formation"]) if not last["formation"].is_empty() else "aucune", last["counts"], last["events"].size(),
			", ".join(last["events"].slice(0, 6).map(func(event): return "%s %.0fs" % [event["kind"], event["t"]]))])
	for line in lines:
		var label := UI.make_label(line, 16)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)
	_add_dev_row(content, [
		["Combat facile (gobelins)", func(): _dev_message(GameData.dev_subject_encounter(hero, "monster:gobelin", 5.0))],
		["Combat dur (gobelins)", func(): _dev_message(GameData.dev_subject_encounter(hero, "monster:gobelin", 95.0))],
	])
	_add_dev_row(content, [
		["Consigner à la bibliothèque", func(): _dev_message(GameData.dev_deposit(hero))],
		["Étudier le bestiaire", func(): _dev_message(GameData.dev_study(hero))],
	])


## Une ligne de curseur : « Audace +30 (Penchant) · évo 4 / 10 », puis − / + / évo− / évo+.
func _add_axis_slider(content: VBoxContainer, hero: Dictionary, axis_id: String) -> void:
	var value := PersonalityEngine.tier(hero, axis_id)
	var evo: float = hero["persona"]["evo"].get(axis_id, 0.0)
	var next := value + (1 if evo >= 0.0 else -1)
	var cost := PersonalityEngine.evolution_cost(value, next) if absi(next) <= PersonalityData.TIER_MAX else 0.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	content.add_child(row)
	var axis: Dictionary = PersonalityData.AXES[axis_id]
	var label := UI.make_label("%s / %s : %+d\n%s, %s · évo %.1f / %.0f" % [axis["plus"], axis["minus"], value * 10,
		PersonalityEngine.tier_name(value), PersonalityEngine.pole_name(axis_id, value), absf(evo), cost], 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	for entry in [["−", func(): GameData.dev_set_axis_tier(hero, axis_id, value - 1)],
			["+", func(): GameData.dev_set_axis_tier(hero, axis_id, value + 1)],
			["évo−", func(): _dev_evolution(hero, axis_id, -10.0)],
			["évo+", func(): _dev_evolution(hero, axis_id, 10.0)]]:
		var button := _make_dev_button(entry[0], entry[1])
		button.size_flags_horizontal = Control.SIZE_FILL
		button.custom_minimum_size.x = 58 if entry[0].length() == 1 else 64
		row.add_child(button)


## Fenêtre du mode dev après un outil de la personnalité P1b.
func _dev_message(text: String) -> void:
	_dev_notice_title = "Personnalité (P1b)"
	_dev_notice = [text]


func _dev_evolution(hero: Dictionary, axis_id: String, points: float) -> void:
	_dev_notice_title = "Personnalité"
	_dev_notice = GameData.dev_add_evolution(hero, axis_id, points)


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


## Duel (voir DuelPanel) : par-dessus la collection ; la fiche est redessinée à la fin.
func _confirm_duel(challenger: Dictionary, rival: Dictionary) -> void:
	DuelPanel.open(self, challenger, rival).finished.connect(_redraw_detail)

## Redessine la fiche du héros affiché (après un outil du mode dev, ou le bouton Favori), au même endroit de la page.
func _redraw_detail() -> void:
	var scroll_position := detail_scroll.scroll_vertical
	var notice := _dev_notice
	var notice_title := _dev_notice_title
	_dev_notice = []
	_dev_notice_title = "Promotion !"
	_refresh()
	_show_detail(detail_hero, notice, notice_title)
	if notice.is_empty():
		await get_tree().process_frame
		detail_scroll.scroll_vertical = scroll_position


## Ouvre le calque d'une fiche : fond sombre (le toucher ferme la fiche), panneau bordé de « border »,
## zone qui défile. Renvoie la colonne où mettre le contenu ; la fiche finit par _close_sheet.
func _open_sheet(hero: Dictionary, border: Color) -> VBoxContainer:
	for child in detail_overlay.get_children():
		detail_overlay.remove_child(child)
		child.queue_free()

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
	var style := UI.make_panel_style(Color("262a3b"), border, 4)
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
	return content


## Bouton « Fermer » en bas de la fiche, et hauteur de la zone qui défile (celle de la fiche, sans
## dépasser l'écran) ; puis la fiche s'affiche.
func _close_sheet(content: VBoxContainer) -> void:
	var close := UI.make_button("Fermer", func(): detail_overlay.visible = false)
	close.custom_minimum_size.y = 90
	content.add_child(close)
	var scroll := detail_scroll
	scroll.custom_minimum_size = Vector2(496, minf(content.get_combined_minimum_size().y, 880))
	detail_overlay.visible = true
	# Les textes à plusieurs lignes ne connaissent leur vraie hauteur qu'une fois affichés : on ajuste.
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(content):
		scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, 880)


## Fiche figée d'un héros tombé (liste des héros tombés) : la fenêtre « En mémoire » (portrait, étoiles,
## classe, niveau, combats livrés, cause de la mort, traits révélés, liens), puis ses statistiques et
## ses compétences au moment de sa mort. Rien ne s'y modifie (sauf « Ressusciter » en mode dev).
func _show_memorial(hero: Dictionary) -> void:
	var content := _open_sheet(hero, Color("e05252"))
	content.add_child(UI.make_death_window(hero, true))
	var stat_parts: Array[String] = []
	for stat in GameData.STAT_NAMES:
		stat_parts.append("%s %d" % [GameData.STAT_NAMES[stat], hero["stats"][stat]])
	var stats := UI.make_label(" · ".join(stat_parts), 20)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.modulate = Color(1, 1, 1, 0.7)
	content.add_child(stats)
	var skills: Array = hero["skills"].map(func(skill): return "%s (niv. %d)" % [skill["name"], skill["level"]])
	var skills_label := UI.make_label("Compétences : %s" % (", ".join(skills) if not skills.is_empty() else "aucune"), 20)
	skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills_label.modulate = Color(1, 1, 1, 0.7)
	content.add_child(skills_label)
	if Settings.dev_mode:
		var revive := _make_dev_button("Ressusciter (mode dev)", func(): GameData.dev_revive(hero))
		revive.custom_minimum_size.y = 70
		content.add_child(revive)
	_close_sheet(content)


## Affiche la fiche détaillée d'un héros. « notice » : une fenêtre système à montrer en haut
## (le résultat d'une promotion, par exemple), avec le titre « notice_title ».
func _show_detail(hero: Dictionary, notice: Array = [], notice_title := "Promotion !") -> void:
	# Un héros tombé : sa fiche figée (voir _show_memorial).
	if not hero["alive"]:
		_show_memorial(hero)
		return
	var color: Color = GameData.RARITY_COLORS[hero["rarity"]]
	var content := _open_sheet(hero, color)

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
		content.add_child(UI.make_label(GameData.class_label(hero), 28))
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
		if GameData.is_broken(hero):
			var broken := UI.make_label("EN RUPTURE : il refuse l'entraînement et les affectations jusqu'à %d de santé mentale (repos). S'il retombe à 0 dans la Tour, il peut mourir de stress." \
				% GameData.BROKEN_RECOVERY, 18)
			broken.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			broken.add_theme_color_override("font_color", Color("e05252"))
			content.add_child(broken)
		if GameData.mental_combat_factor(hero) < 1.0:
			var malus := UI.make_label("En combat : attaque et défense -%d %%" % roundi((1.0 - GameData.mental_combat_factor(hero)) * 100), 18)
			malus.modulate = Color(1, 1, 1, 0.7)
			content.add_child(malus)
	# Traits de caractère : « ? » tant qu'ils ne se sont pas révélés en jouant.
	content.add_child(UI.make_label("Caractère : %s" % GameData.traits_text(hero), 22))
	for t in GameData.hero_traits(hero):
		if t["known"]:
			var trait_info := UI.make_label("%s : %s" % [t["name"], GameData.TRAITS.get(t["name"], "")], 18)
			trait_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			trait_info.modulate = Color(1, 1, 1, 0.6)
			content.add_child(trait_info)
	# Liens avec les autres héros (voir GameData, personality.gd) : groupe lié, puis chaque lien.
	if hero.get("group", "") != "":
		content.add_child(UI.make_label("Groupe lié : %s" % hero["group"], 22))
	var links := GameData.hero_bonds(hero)
	if links.is_empty():
		var lonely := UI.make_label("Liens : aucun pour l'instant (ils se créent en combattant ensemble).", 18)
		lonely.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lonely.modulate = Color(1, 1, 1, 0.6)
		content.add_child(lonely)
	else:
		content.add_child(UI.make_label("Liens :", 22))
		for link in links:
			var other: Dictionary = link["hero"]
			var text := "%s (%s) — %s" % [other["name"], "★".repeat(other["rarity"]), GameData.bond_name(link["level"])]
			if not other["alive"]:
				text += " (tombé)"
			var line := UI.make_label(text, 18)
			if link["level"] == GameData.BOND_HOSTILE:
				line.add_theme_color_override("font_color", Color("e05252"))
			elif link["level"] >= GameData.BOND_FRIEND:
				line.add_theme_color_override("font_color",
					Color("f5c542") if link["level"] >= GameData.BOND_BROTHERS else Color("6fe08a"))
			if not other["alive"]:
				line.modulate = Color(1, 1, 1, 0.5)
			content.add_child(line)
			# Hostiles : le conflit se règle par un duel, organisé par le Maître.
			if link["level"] == GameData.BOND_HOSTILE and other["alive"] and hero["alive"]:
				var duel := UI.make_button("Organiser un duel contre %s" % other["name"], func(): _confirm_duel(hero, other), 20)
				duel.custom_minimum_size.y = 64
				content.add_child(duel)

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

	# Mode Berserk (compétence à bascule) : ses statistiques en rage, « valeur actuelle / valeur de base (+5) ».
	var berserk := GameData.berserk_preview(hero)
	if not berserk.is_empty():
		var berserk_title := UI.make_label("Mode Berserk (il l'active de lui-même quand le combat est difficile, ou sur ton ordre) :", 20)
		berserk_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(berserk_title)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		content.add_child(grid)
		for row in berserk:
			var name_label := UI.make_label(row[0], 19)
			name_label.modulate = Color(1, 1, 1, 0.7)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(name_label)
			var gap: int = row[1] - row[2]
			var value := UI.make_label("%d / %d (%s%d)" % [row[1], row[2], "+" if gap >= 0 else "-", absi(gap)], 19)
			value.add_theme_color_override("font_color", Color("e05252") if gap < 0 else Color("f5b82e"))
			grid.add_child(value)
	# Migraine (après une rage) : elle continue après le combat.
	var migraine := GameData.migraine_left(hero)
	if hero["alive"] and migraine > 0.0:
		var migraine_label := UI.make_label("Migraine : encore %d min (-%d %% de dégâts en combat)" \
			% [ceili(migraine / 60.0), roundi((1.0 - GameData.MIGRAINE_DAMAGE_FACTOR) * 100)], 20)
		migraine_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		migraine_label.add_theme_color_override("font_color", Color("c9a2ff"))
		content.add_child(migraine_label)

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
	if hero["alive"] and GameData.is_immortal(hero):
		status_text = "Immortel (mode dev)"
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
	_close_sheet(content)
