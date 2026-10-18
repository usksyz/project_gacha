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
			return "%s (%s, %s) rejoint ta cité." % [hero["name"], "★".repeat(rarity), GameData.class_label(hero)]])
	_add_row(content, stars)
	_add_note(content, "Pour les niveaux, l'expérience, les étoiles, les stats et les compétences d'un héros : sa fiche, dans la Collection.")

	_add_section(content, "Tutoriel")
	_add_row(content, [["Passer le tutoriel", func():
		if GameData.tutorial_step == "":
			return "Pas de tutoriel en cours."
		GameData.dev_skip_tutorial()
		return "Tutoriel passé : tous les onglets sont ouverts (rien n'est donné : ni héros, ni le tirage d'armes offert)."]])

	_add_section(content, "Invocation")
	_add_row(content, [["Rendre l'invocation gratuite", func():
		GameData.dev_reset_free_summon()
		if GameData.tutorial_step != "":
			return "L'invocation gratuite du jour est rendue (elle n'apparaît qu'après le tutoriel)."
		return "L'invocation gratuite du jour est rendue (écran Invocation)."]])

	_add_section(content, "Vie de la cité")
	_add_row(content, [["Une demande maintenant", func(): return GameData.dev_force_request()],
		["Rapport du jour à revoir", func():
			GameData.dev_reset_daily_report()
			return "Le rapport de la fée s'affichera (fenêtre à la fermeture des outils)."]])
	_add_note(content, "Les bulles de la cité et les demandes montrent leur raison en mode dev.")

	_add_section(content, "Tour")
	floor_label = UI.make_label("", 22)
	content.add_child(floor_label)
	_add_row(content, [
		["-1 étage", func(): return _move_floor(-1)],
		["+1 étage", func(): return _move_floor(1)],
		["+5 étages", func(): return _move_floor(5)],
	])
	# (Recensement « Techniques », point 9) Revoir le dernier combat de la Tour, à l'identique, avec les ordres donnés.
	_add_row(content, [["Revoir le dernier combat", _replay_last_fight]])
	_add_note(content, "Rejoué à l'identique (même graine, mêmes ordres), sans rien changer à la partie. Pendant un combat, " +
		"le bouton « Calques » de la vue montre ce que les héros et les monstres « savent » (regards, recherche, terrain).")

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
	_add_row(content, [["Monstre rare garanti (oui / non)", func():
		GameData.dev_force_rare = not GameData.dev_force_rare
		return "Monstre rare à chaque expédition : %s (jusqu'à la fermeture du jeu)." \
			% ("oui" if GameData.dev_force_rare else "non")]])
	_add_row(content, [["Donjon journalier : jour suivant", func():
		# Jour simulé (le vrai jour, puis dimanche, lundi... samedi, puis de nouveau le vrai jour).
		GameData.dev_daily_weekday = GameData.dev_daily_weekday + 1 if GameData.dev_daily_weekday < 6 else -1
		if GameData.dev_daily_weekday < 0:
			return "Donjon journalier : retour au vrai jour (%s)." % GameData.WEEKDAY_NAMES[GameData.daily_weekday()]
		return "Donjon journalier : on fait comme si on était %s (jusqu'à la fermeture du jeu)." \
			% GameData.WEEKDAY_NAMES[GameData.dev_daily_weekday].to_lower()]])
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

	# Personnalité P1b : bibliothèque et mémorial du Maître (données seulement, pas encore de salle).
	_add_section(content, "Bibliothèque et mémorial")
	_add_note(content, "Personnalité P1b : les données, sans salle ni écran. Un héros consigne ce qu'il rapporte depuis sa fiche (outils de la personnalité).")
	_add_row(content, [["Voir la bibliothèque", func():
			_show_library()
			return ""],
		["Voir le mémorial", func():
			_show_memorial()
			return ""]])
	_add_row(content, [["Enregistrer les morts au mémorial", func(): return GameData.dev_memorial_record_dead()]])
	_add_row(content, [["Mémorial : +1 niveau de places", func(): return GameData.dev_memorial_upgrade(true)],
		["Mémorial : +1 niveau de mémoire", func(): return GameData.dev_memorial_upgrade(false)]])

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


# ---------------------------------------------------------------------------
# Bibliothèque et mémorial (personnalité P1b)
# ---------------------------------------------------------------------------

## Une fenêtre par-dessus le panneau : un titre, des lignes (textes, ou rangées [[texte, action]] de
## boutons), et « Fermer ». Renvoie la fenêtre (elle se retire d'elle-même en fermant).
func _open_window(title: String, lines: Array) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	overlay.add_child(margin)
	var panel := PanelContainer.new()
	var style := UI.make_panel_style(Color("15121f"), Color("9b6be0"), 3)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	var title_label := UI.make_label(title.to_upper(), 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color("c9a8ff"))
	layout.add_child(title_label)
	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	for line in lines:
		if line is Array:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			content.add_child(row)
			for entry in line:
				var action: Callable = entry[1]
				var button := UI.make_button(entry[0], action, 18)
				button.custom_minimum_size.y = 56
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(button)
		else:
			var label := UI.make_label(str(line), 18)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(label)
	var close := UI.make_button("Fermer", func(): overlay.queue_free(), 22)
	close.custom_minimum_size.y = 64
	layout.add_child(close)
	return overlay


func _show_library() -> void:
	var library: Dictionary = GameData.library
	var lines: Array = ["Niveau de la salle : %d · fiches vérifiées : %d" % [library["level"], Library.verified_count(library)]]
	lines.append("BESTIAIRE")
	for subject in library["bestiary"]:
		var card: Dictionary = library["bestiary"][subject]
		var notes: Array[String] = []
		notes.append("vérifiée" if card["verified"] else "non vérifiée")
		if card["told"]:
			notes.append("racontée par un illettré")
		if card["omission"]:
			notes.append("omission possible (Ruse)")
		if card["prior"]:
			notes.append("connu avant l'invocation")
		lines.append("• %s : connaissance %d, détail %d, danger écrit %.0f ; par %s (%s)" % [PersonalityData.SUBJECTS.get(subject, {}).get("name", subject),
			card["knowledge"], card["detail"], card["danger"], ", ".join(card["authors"].map(func(a): return a["name"])), ", ".join(notes)])
	lines.append("CARNETS D'ÉTAGE")
	for key in library["floors"]:
		var notes_floor: Dictionary = library["floors"][key]
		lines.append("• Étage %d : %d passage(s), %d victoire(s), vagues %d ; tués par : %s ; a marché : %s ; par %s%s" % [notes_floor["floor"],
			notes_floor["visits"], notes_floor["victories"], notes_floor["waves"], ", ".join(notes_floor["killed_by"]) if notes_floor["killed_by"] else "-",
			", ".join(notes_floor["worked"]) if notes_floor["worked"] else "-", ", ".join(notes_floor["authors"].map(func(a): return a["name"])),
			" (rôle exagéré)" if notes_floor["exaggerated"] else ""])
	lines.append("FORMATIONS : %d · STRATÉGIES : %s" % [library["formations"].size(), ", ".join(library["strategies"].keys()) if library["strategies"] else "aucune"])
	lines.append("REGISTRE DES COMPÉTENCES")
	for skill_name in library["skills"]:
		var entry: Dictionary = library["skills"][skill_name]
		lines.append("• %s : %s" % [skill_name, Library.SKILL_STATE_NAMES.get(entry["state"], entry["state"])])
	_open_window("Bibliothèque", lines)


func _show_memorial() -> void:
	var memorial: Dictionary = GameData.memorial
	var lines: Array = ["%d / %d places (niveau %d) · mémoire niveau %d" % [memorial["entries"].size(), Memorial.capacity(memorial),
		memorial["capacity_level"], memorial["memory_level"]]]
	var holder := {}  # (la fenêtre n'existe qu'après la boucle : les boutons la retrouvent ici)
	for item in memorial["entries"]:
		var kept := Memorial.view(memorial, item)
		var battle_text := "aucun combat gardé"
		if not kept["battles"].is_empty():
			var last: Dictionary = kept["battles"].back()
			battle_text = "%d combat(s) gardé(s) ; le dernier : étage %d, %s" % [kept["battles"].size(), last["floor"],
				", ".join(last.get("events", []).map(func(event): return "%s %.0fs" % [event["kind"], event["t"]]))]
		lines.append("%s (%s) — %s. %s. Sujets gardés : %s%s" % [item["name"], "★".repeat(item["rarity"]), item["cause"], battle_text,
			", ".join(kept["subjects"].keys().map(func(s): return "%s %d" % [PersonalityData.SUBJECTS.get(s, {}).get("name", s), kept["subjects"][s]])) if kept["subjects"] else "aucun",
			"" if kept["past"] == "" else " ; passé : " + PersonalityData.METIERS.get(kept["past"], {}).get("name", kept["past"])])
		var hero_id: int = item["id"]
		var hero_name: String = item["name"]
		lines.append([["Retirer", func(): _confirm_memorial_removal(hero_id, hero_name, holder.get("window"))]])
	holder["window"] = _open_window("Mémorial", lines)


## Fenêtre de validation, puis « [Nom] sera oublié à jamais. »
func _confirm_memorial_removal(hero_id: int, hero_name: String, memorial_window) -> void:
	var holder := {}
	holder["window"] = _open_window("Retirer du mémorial", ["Retirer %s du mémorial ?" % hero_name,
		[["Oui, retirer", func():
			var message := GameData.dev_memorial_remove(hero_id)
			holder["window"].queue_free()
			if is_instance_valid(memorial_window):
				memorial_window.queue_free()
			_open_window("Mémorial", [message])],
		["Non", func(): holder["window"].queue_free()]]])


func _make_menu(items: Array) -> OptionButton:
	var menu := OptionButton.new()
	menu.custom_minimum_size.y = 64
	menu.add_theme_font_size_override("font_size", 20)
	menu.get_popup().add_theme_font_size_override("font_size", 26)
	for item in items:
		menu.add_item(item)
	return menu


## (Point 9) Revoir le dernier combat de la Tour : un écran de combat par-dessus tout, qui se ferme à la fin.
func _replay_last_fight() -> String:
	var battle: Battle = GameData.dev_replay_battle()
	if battle == null:
		return "Aucun combat à revoir dans cette séance."
	var view := BattleView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("15121f")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(backdrop)
	layer.add_child(view)
	get_tree().root.add_child(layer)
	view.play(battle, "Revoir : étage %d" % GameData.last_fight["floor"], func(_fight):
		var label := UI.make_label("Fin du combat revu : rien n'a changé dans la partie.", 24)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return [label])
	view.closed.connect(func(): layer.queue_free())
	visible = false
	return "Le combat est rejoué."
