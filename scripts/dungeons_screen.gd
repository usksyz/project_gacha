class_name DungeonsScreen
extends Control
## Donjons : la Tour (combats en temps réel, étage par étage, et étages déjà conquis à refaire
## pour s'entraîner) et le donjon journalier (une équipe part récolter des matériaux).
## L'écran a cinq « pages » : la liste des donjons, la composition des équipes à l'avance,
## l'annonce de la quête de l'étage, le choix de l'équipe, et le combat.

## Temps entre deux fenêtres d'avertissement, en secondes.
const WARNING_DELAY := 0.7

var list_page: Control
var teams_page: Control
var announce_page: Control
var team_page: Control
var battle_view: BattleView

var announce_box: VBoxContainer
var announce_button: Button

## Page de composition : équipe en cours de modification (0 = Équipe 1), ses onglets,
## ses places, et la grille des héros.
var edited_team := 0
var team_tabs: HBoxContainer
var team_slots: TeamSlots
var team_hint: Label
var compose_grid: GridContainer
var presets_box: HBoxContainer

## Quête de l'étage qu'on s'apprête à affronter.
var floor_quest: Dictionary = {}

var floor_label: Label
var daily_label: Label
## Contenu changeant de la carte du donjon journalier (boutons, ramassages, retour).
var daily_box: VBoxContainer
## Annonce de l'entrée d'une équipe dans le donjon, montrée tant qu'elle y est.
var daily_notice := ""
## Le donjon journalier choisi pour la prochaine expédition (le dimanche, ils sont tous ouverts).
var daily_choice := ""
var team_title: Label
var enemies_box: VBoxContainer
var pick_label: Label
## Formation de groupe avant l'étage : les places du groupe (glisser-déposer).
var group_slots: TeamSlots
var heroes_grid: GridContainer
var no_hero_label: Label
var fight_button: Button

## Ennemis de l'étage qu'on s'apprête à affronter.
var floor_enemies: Array[Dictionary] = []
## Étage qu'on s'apprête à jouer (l'étage actuel, ou un étage déjà conquis qu'on refait).
var chosen_floor := 1
var replay_button: Button
## Numéros (id) des héros choisis pour le combat.
var selected_ids: Array[int] = []


func _ready() -> void:
	list_page = _build_list_page()
	teams_page = _build_teams_page()
	announce_page = _build_announce_page()
	team_page = _build_team_page()
	battle_view = BattleView.new()
	battle_view.closed.connect(func(): _show_page(list_page))
	for page in _pages():
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(page)
	_show_page(list_page)


func _pages() -> Array:
	return [list_page, teams_page, announce_page, team_page, battle_view]


func on_shown() -> void:
	# Un combat en cours reste affiché ; sinon on revient à la liste des donjons.
	if not battle_view.visible:
		_show_page(list_page)


func _show_page(page: Control) -> void:
	for other in _pages():
		other.visible = other == page
	if page == list_page:
		var quest := GameData.floor_quest(GameData.tower_floor)
		floor_label.text = "Étage actuel : %d (%s)" % [GameData.tower_floor, quest["name"]]
		replay_button.disabled = GameData.tower_floor <= 1  # aucun étage conquis à refaire
		_refresh_daily()


# --- Page 1 : liste des donjons ---

func _build_list_page() -> Control:
	var margin := _make_margin()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var tower := _make_card(layout, "La Tour",
		"Grimpe les étages un par un. Chaque étage est plus dangereux que le précédent. Un boss garde tous les %d étages." % GameData.BOSS_EVERY)
	floor_label = UI.make_label("", 26)
	floor_label.add_theme_color_override("font_color", Color("f5b82e"))
	tower.add_child(floor_label)
	var enter := UI.make_button("Entrer dans la Tour", func(): _open_tower(GameData.tower_floor))
	enter.custom_minimum_size.y = 80
	tower.add_child(enter)
	replay_button = UI.make_button("Refaire un étage (entraînement)", _open_replay_picker, 24)
	replay_button.custom_minimum_size.y = 70
	tower.add_child(replay_button)
	var compose := UI.make_button("Composer les équipes", _open_teams, 24)
	compose.custom_minimum_size.y = 70
	tower.add_child(compose)

	var daily := _make_card(layout, "Donjon journalier",
		"Un festin de donjon qui change tous les jours : tes héros y récoltent des matériaux rares, sans combattre.")
	daily_label = UI.make_label("", 22)
	daily_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	daily_label.add_theme_color_override("font_color", Color("f5b82e"))
	daily.add_child(daily_label)
	daily_box = VBoxContainer.new()
	daily_box.add_theme_constant_override("separation", 8)
	daily.add_child(daily_box)

	# Chaque seconde, le compte à rebours et les ramassages du donjon journalier avancent.
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(func():
		if list_page.visible and is_visible_in_tree() and not GameData.expeditions.is_empty():
			_refresh_daily())
	add_child(timer)
	timer.start()
	GameData.lobby_updated.connect(func():
		if list_page.visible:
			_refresh_daily())

	# La carte de la Tour et celle du donjon défilent si l'écran est trop petit.
	var scroll := UI.make_scroll()
	margin.remove_child(layout)
	scroll.add_child(layout)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	return margin


## Carte du donjon journalier : verrouillé, ou prêt (un bouton par équipe, autant d'expéditions
## qu'on veut) ; en dessous, les groupes en cours (compte à rebours et derniers ramassages) ;
## au-dessus, les groupes revenus (ce qu'ils ont rapporté).
func _refresh_daily() -> void:
	GameData.update_expedition()
	for child in daily_box.get_children():
		daily_box.remove_child(child)
		child.queue_free()

	_add_daily_calendar()
	if not GameData.expedition_reports.is_empty():
		for report in GameData.expedition_reports:
			daily_box.add_child(UI.make_system_window("Donjon journalier", report["lines"]))
		var ok := UI.make_button("Compris", func():
			GameData.expedition_reports.clear()
			GameData.save_game()
			_refresh_daily(), 22)
		ok.custom_minimum_size.y = 70
		daily_box.add_child(ok)

	var problem := GameData.expedition_problem()
	if problem != "":
		daily_label.text = problem
		return
	var open := GameData.open_daily_dungeons()
	if not daily_choice in open:
		daily_choice = open[0]
	var day: String = GameData.WEEKDAY_NAMES[GameData.daily_weekday()]
	if open.size() > 1:
		daily_label.text = "%s : tous les donjons sont ouverts. Choisis-en un, puis envoie un groupe " % day \
			+ "(%d minutes de récolte), autant de fois que tu veux :" % (GameData.EXPEDITION_SECONDS / 60)
		_add_daily_choice(open)
	else:
		daily_label.text = "%s : %s. Envoie un groupe (%d minutes de récolte), autant de fois que tu veux :" % [
			day, GameData.dungeon_title(daily_choice), GameData.EXPEDITION_SECONDS / 60]
	_add_daily_team_buttons(daily_choice)

	if daily_notice != "" and not GameData.expeditions.is_empty():
		daily_box.add_child(UI.make_system_window("Donjon journalier", [daily_notice]))
	for expedition in GameData.expeditions:
		var remaining := GameData.expedition_remaining(expedition)
		var title := UI.make_label("Équipe %d — %s : récolte en cours, rappel dans %d:%02d." % [
			expedition["team_index"] + 1, GameData.expedition_dungeon(expedition)["name"],
			remaining / 60, remaining % 60], 20)
		title.add_theme_color_override("font_color", Color("f5b82e"))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		daily_box.add_child(title)
		var entries := GameData.expedition_log_so_far(expedition)
		for entry in entries.slice(maxi(0, entries.size() - 3)):
			var line := UI.make_label(entry["text"], 18)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.modulate = Color(1, 1, 1, 0.5 if entry["kind"] == "junk" else 0.85)
			daily_box.add_child(line)


## Calendrier (cahier) : une carte à cadre argenté par donjon, les jours dans un bandeau au-dessus,
## le nom et les matériaux dessous ; la carte du dimanche les réunit tous. La carte du jour est dorée.
func _add_daily_calendar() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	daily_box.add_child(row)
	var today := GameData.daily_weekday()
	var short := func(day: int) -> String: return GameData.WEEKDAY_NAMES[day].left(3)
	for dungeon_id in GameData.DAILY_DUNGEONS:
		var info: Dictionary = GameData.DAILY_DUNGEONS[dungeon_id]
		var days: Array = info["days"]
		row.add_child(_make_calendar_card(" · ".join(days.map(short)), info["name"],
			"\n".join(info["materials"]), today in days))
	row.add_child(_make_calendar_card(short.call(GameData.SUNDAY), "Tous les donjons",
		"Les matériaux des trois", today == GameData.SUNDAY))


func _make_calendar_card(days: String, title: String, materials: String, is_today: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border := Color("f5b82e") if is_today else Color("aab2c0")  # doré aujourd'hui, argenté sinon
	var style := UI.make_panel_style(Color("2f3447") if is_today else Color("1d2030"), border, 4 if is_today else 2)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)
	card.modulate = Color.WHITE if is_today else Color(1, 1, 1, 0.65)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var banner := UI.make_label(("Aujourd'hui\n" if is_today else "\n") + days, 15)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_color", border)
	box.add_child(banner)
	for text in [[title, 17, 1.0], [materials, 13, 0.7]]:
		var label := UI.make_label(text[0], text[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate = Color(1, 1, 1, text[2])
		box.add_child(label)
	return card


## Le dimanche : un bouton par donjon ouvert, pour choisir où envoyer le prochain groupe.
func _add_daily_choice(open: Array[String]) -> void:
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	daily_box.add_child(buttons)
	for dungeon_id in open:
		var button := UI.make_button(GameData.DAILY_DUNGEONS[dungeon_id]["name"], func():
			daily_choice = dungeon_id
			_refresh_daily.call_deferred(), 18)
		button.custom_minimum_size.y = 60
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if dungeon_id == daily_choice:
			button.add_theme_color_override("font_color", Color("f5b82e"))
			button.text = "▶ " + button.text
		buttons.add_child(button)


## Un bouton par équipe composée pour l'envoyer dans le donjon « dungeon_id » (grisé si aucun de ses
## héros n'est libre).
func _add_daily_team_buttons(dungeon_id: String) -> void:
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	daily_box.add_child(buttons)
	for index in GameData.TEAM_COUNT:
		var members := GameData.expedition_members(index)
		var button := UI.make_button("Équipe %d (%d)" % [index + 1, members.size()], func():
			if GameData.start_expedition(index, dungeon_id):
				daily_notice = "L'équipe %d est entrée dans le donjon journalier, %s. Ils reviendront après avoir acquis des matériaux !" \
					% [index + 1, GameData.dungeon_title(dungeon_id)]
			_refresh_daily.call_deferred(), 22)
		button.custom_minimum_size.y = 70
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = members.is_empty()
		buttons.add_child(button)


## Crée une carte (titre + description) dans « parent » et renvoie son contenu,
## pour pouvoir y ajouter d'autres éléments.
func _make_card(parent: Control, title: String, info: String) -> VBoxContainer:
	var card := PanelContainer.new()
	var style := UI.make_panel_style(Color("262a3b"))
	style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)
	content.add_child(UI.make_label(title, 32))
	var info_label := UI.make_label(info, 22)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.modulate = Color(1, 1, 1, 0.7)
	content.add_child(info_label)
	return content


# --- Composition des équipes à l'avance ---

func _build_teams_page() -> Control:
	var margin := _make_margin()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := UI.make_label("Composition des équipes", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	# Onglets : Équipe 1, Équipe 2, Équipe 3.
	team_tabs = HBoxContainer.new()
	team_tabs.add_theme_constant_override("separation", 8)
	layout.add_child(team_tabs)

	# Les places de l'équipe choisie : une carte par héros, ou une place libre.
	var slots_panel := PanelContainer.new()
	slots_panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b")))
	layout.add_child(slots_panel)
	team_slots = TeamSlots.new()
	team_slots.changed.connect(func(ids: Array):
		GameData.set_team(edited_team, ids)
		_refresh_teams_page.call_deferred())
	slots_panel.add_child(team_slots)

	team_hint = UI.make_label("", 22)
	team_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(team_hint)

	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	# Lâcher une carte de l'équipe sur la liste la retire de l'équipe.
	TeamSlots.make_removal_zone(scroll, func(hero_id: int): _remove_team_member(hero_id))
	var centered := CenterContainer.new()
	centered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centered)
	compose_grid = GridContainer.new()
	compose_grid.columns = 5
	compose_grid.add_theme_constant_override("h_separation", 8)
	compose_grid.add_theme_constant_override("v_separation", 8)
	centered.add_child(compose_grid)

	var back := UI.make_button("Terminé", func(): _show_page(list_page))
	back.custom_minimum_size.y = 90
	layout.add_child(back)
	return margin


func _open_teams() -> void:
	edited_team = 0
	_refresh_teams_page()
	_show_page(teams_page)


func _refresh_teams_page() -> void:
	for child in team_tabs.get_children():
		team_tabs.remove_child(child)
		child.queue_free()

	for index in GameData.TEAM_COUNT:
		var tab := UI.make_button("Équipe %d" % (index + 1), _select_team.bind(index), 24)
		tab.custom_minimum_size.y = 70
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if index == edited_team:
			tab.add_theme_color_override("font_color", Color("f5b82e"))
			tab.add_theme_color_override("font_hover_color", Color("f5b82e"))
		tab.modulate = Color.WHITE if index == edited_team else Color(1, 1, 1, 0.6)
		team_tabs.add_child(tab)

	var members := GameData.team_members(edited_team)
	var member_ids := members.map(func(hero): return hero["id"])
	team_slots.set_heroes(member_ids)
	_fill_hero_grid(compose_grid, _sorted_heroes(), member_ids, _toggle_team_member, _remove_team_member)
	team_hint.text = "Équipe %d : %d/%d héros. Conseil du Système : maintiens une carte puis glisse-la dans l'équipe, ou touche-la. Tout est enregistré." \
		% [edited_team + 1, members.size(), GameData.TEAM_SIZE]


func _select_team(index: int) -> void:
	edited_team = index
	_refresh_teams_page.call_deferred()


func _toggle_team_member(hero_id: int) -> void:
	if not GameData.toggle_team_member(edited_team, hero_id):
		team_hint.text = "L'équipe %d est complète (%d héros). Retire d'abord un héros." \
			% [edited_team + 1, GameData.TEAM_SIZE]
		return
	# « call_deferred » : on reconstruit juste après, pas pendant l'appui sur la carte.
	_refresh_teams_page.call_deferred()


## Retire un héros de l'équipe en cours (carte du groupe lâchée sur la liste).
func _remove_team_member(hero_id: int) -> void:
	var ids: Array = GameData.teams[edited_team].duplicate()
	ids.erase(hero_id)
	GameData.set_team(edited_team, ids)
	_refresh_teams_page.call_deferred()


# --- Page 2 : annonce de la quête ---

func _build_announce_page() -> Control:
	var margin := _make_margin()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	announce_box = VBoxContainer.new()
	announce_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	announce_box.alignment = BoxContainer.ALIGNMENT_CENTER
	announce_box.add_theme_constant_override("separation", 16)
	scroll.add_child(announce_box)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	layout.add_child(buttons)
	var back := UI.make_button("Retour", func(): _show_page(list_page))
	back.custom_minimum_size = Vector2(200, 90)
	buttons.add_child(back)
	announce_button = UI.make_button("Former l'équipe", func(): _show_page(team_page))
	announce_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(announce_button)
	return margin


## Affiche l'annonce de l'étage : d'abord les avertissements (une fenêtre rouge après l'autre),
## puis la fenêtre de la quête.
func _play_announce(floor_number: int) -> void:
	for child in announce_box.get_children():
		announce_box.remove_child(child)
		child.queue_free()
	announce_button.disabled = true

	for i in floor_quest["warnings"]:
		announce_box.add_child(UI.make_system_window("Avertissement !", [
			"Cette quête est d'une difficulté extrême."], true))
		Settings.vibrate(200)
		await get_tree().create_timer(WARNING_DELAY).timeout
		if not announce_page.visible:
			return  # le joueur est reparti entre-temps

	var lines := [
		"Quête : %s" % floor_quest["name"],
		"Objectif : %s" % floor_quest["objective"],
	]
	if floor_quest["lasting"]:
		lines.append("Compte à rebours : %d secondes à tenir." % floor_quest["seconds"])
		if floor_quest.get("wait_contact", false):
			lines.append("Le décompte ne démarre qu'au premier contact avec les ennemis.")
	else:
		lines.append("Limite de temps : %d secondes." % floor_quest["seconds"])
	if floor_quest["walls"] > 0:
		lines.append("Remparts de la cité : %d." % floor_quest["walls"])
	if GameData.is_boss_floor(floor_number):
		lines.append("Un boss garde cet étage. Palier : la difficulté monte d'un cran, prépare-toi bien.")
	announce_box.add_child(UI.make_system_window("Étage %d" % floor_number, lines))
	announce_button.disabled = false


# --- Page 3 : choix de l'équipe ---

func _build_team_page() -> Control:
	var margin := _make_margin()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	team_title = UI.make_label("", 40)
	team_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(team_title)

	var enemies_panel := PanelContainer.new()
	enemies_panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b")))
	layout.add_child(enemies_panel)
	enemies_box = VBoxContainer.new()
	enemies_panel.add_child(enemies_box)

	var warning := UI.make_label("Attention : un héros qui tombe au combat meurt pour toujours.", 22)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", Color("e05252"))
	layout.add_child(warning)

	pick_label = UI.make_label("", 24)
	layout.add_child(pick_label)

	# Un bouton par équipe composée à l'avance : elle est choisie d'un seul toucher.
	presets_box = HBoxContainer.new()
	presets_box.add_theme_constant_override("separation", 8)
	layout.add_child(presets_box)

	# Formation de groupe (cahier) : on glisse-dépose les héros dans les places du groupe.
	var group_panel := PanelContainer.new()
	group_panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b"), Color("3d8fe0"), 2))
	layout.add_child(group_panel)
	var group_box := VBoxContainer.new()
	group_panel.add_child(group_box)
	var group_title := UI.make_label("Formation de groupe", 22)
	group_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group_title.add_theme_color_override("font_color", Color("9ad1ff"))
	group_box.add_child(group_title)
	group_slots = TeamSlots.new()
	group_slots.slot_width = 96
	group_slots.changed.connect(func(ids: Array):
		selected_ids.assign(ids)
		_refresh_team.call_deferred())
	group_box.add_child(group_slots)

	no_hero_label = UI.make_label("Aucun héros en vie.\nVa en invoquer dans la Salle d'invocation !", 24)
	no_hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(no_hero_label)

	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	TeamSlots.make_removal_zone(scroll, func(hero_id: int): _remove_selected(hero_id))
	var centered := CenterContainer.new()
	centered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centered)
	heroes_grid = GridContainer.new()
	heroes_grid.columns = 5
	heroes_grid.add_theme_constant_override("h_separation", 8)
	heroes_grid.add_theme_constant_override("v_separation", 8)
	centered.add_child(heroes_grid)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	layout.add_child(buttons)
	var back := UI.make_button("Retour", func(): _show_page(list_page))
	back.custom_minimum_size = Vector2(200, 90)
	buttons.add_child(back)
	fight_button = UI.make_button("", _confirm_group)
	fight_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(fight_button)
	return margin


## Fenêtre pour choisir un étage déjà conquis à refaire (pour entraîner une équipe).
func _open_replay_picker() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var margin := _make_margin()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	layout.add_child(UI.make_system_window("Refaire un étage", [
		"Pour entraîner une nouvelle équipe ou ton équipe principale.",
		"Récompenses réduites : %d %% de l'expérience, %d %% de l'or, pas de gemmes. La Tour ne monte pas." % [
			roundi(GameData.REPLAY_XP_RATE * 100), roundi(GameData.REPLAY_GOLD_RATE * 100)],
		"Attention : un héros qui tombe meurt quand même pour toujours."]))
	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for floor_number in range(1, GameData.tower_floor):
		var text := "Étage %d" % floor_number
		if GameData.is_boss_floor(floor_number):
			text += "\nBoss"
		var button := UI.make_button(text, func():
			overlay.queue_free()
			_open_tower(floor_number), 22)
		button.custom_minimum_size.y = 90
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	var close := UI.make_button("Fermer", func(): overlay.queue_free(), 24)
	close.custom_minimum_size.y = 80
	layout.add_child(close)


## Prépare un étage (ennemis) et affiche le choix de l'équipe.
## L'étage actuel fait monter dans la Tour ; un étage déjà conquis sert d'entraînement.
func _open_tower(floor_number: int) -> void:
	chosen_floor = floor_number
	floor_quest = GameData.floor_quest(floor_number)
	floor_enemies = GameData.tower_enemies(floor_number)
	selected_ids.clear()

	team_title.text = "Étage %d — %s" % [floor_number, floor_quest["name"]]
	if GameData.is_boss_floor(floor_number):
		team_title.text += " — Boss !"

	for child in enemies_box.get_children():
		child.queue_free()
	var rewards := GameData.tower_rewards(floor_number)
	# « Récompense : 300 or, 5 » suivi du cristal des gemmes (ou du mot « gemmes », anciens visuels).
	var header: Control = UI.make_gem_amount("Récompense : %d or, %d" % [rewards["gold"], rewards["gems"]], 22)
	if floor_number < GameData.tower_floor:
		header = UI.make_label("Entraînement : %d or, pas de gemmes, %d d'expérience" % [
			roundi(rewards["gold"] * GameData.REPLAY_GOLD_RATE), roundi(rewards["xp"] * GameData.REPLAY_XP_RATE)], 22)
	header.modulate = Color(1, 1, 1, 0.7)
	enemies_box.add_child(header)
	for text in _enemy_summary():
		enemies_box.add_child(UI.make_label(text, 22))

	_refresh_team()
	_show_page(announce_page)
	_play_announce(floor_number)


## Liste des ennemis regroupés par type : « Gobelin niv. 3 (Assassin) x4 ».
## En quête de survie, le niveau est caché : « niv. ? ».
func _enemy_summary() -> Array:
	var counts := {}
	var examples := {}
	for enemy in floor_enemies:
		var key: String = enemy["base_name"]
		counts[key] = counts.get(key, 0) + 1
		examples[key] = enemy
	var lines := []
	for key in counts:
		var enemy: Dictionary = examples[key]
		var level: String = "?" if floor_quest["hidden_level"] else str(enemy["level"])
		var text := "%s niv. %s (%s)" % [key, level, enemy["class"]]
		if counts[key] > 1:
			text += " x%d" % counts[key]
		lines.append(text)
	return lines


func _refresh_team() -> void:
	# Les héros partis au donjon journalier ne peuvent pas monter dans la Tour.
	var heroes: Array[Dictionary] = []
	for hero in _sorted_heroes():
		if not GameData.is_away(hero):
			heroes.append(hero)
	_fill_hero_grid(heroes_grid, heroes, selected_ids, _toggle_hero, _remove_selected)
	group_slots.set_heroes(selected_ids)

	# Boutons des équipes composées à l'avance (grisés si l'équipe est vide).
	for child in presets_box.get_children():
		presets_box.remove_child(child)
		child.queue_free()
	for index in GameData.TEAM_COUNT:
		var members := GameData.team_members(index).filter(func(hero): return not GameData.is_away(hero))
		var button := UI.make_button("Équipe %d (%d)" % [index + 1, members.size()], _use_team.bind(index), 22)
		button.custom_minimum_size.y = 70
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = members.is_empty()
		presets_box.add_child(button)

	no_hero_label.visible = heroes.is_empty()
	pick_label.text = "Choisis une équipe, ou glisse jusqu'à %d héros dans le groupe :" % GameData.TEAM_SIZE
	fight_button.text = "Combattre (%d/%d)" % [selected_ids.size(), GameData.TEAM_SIZE]
	fight_button.disabled = selected_ids.is_empty()


## Choisit d'un coup les héros (encore en vie) d'une équipe composée à l'avance.
func _use_team(index: int) -> void:
	selected_ids.clear()
	for hero in GameData.team_members(index):
		if not GameData.is_away(hero):
			selected_ids.append(hero["id"])
	_refresh_team.call_deferred()


## Les héros en vie, les plus rares d'abord, puis dans l'ordre d'invocation.
func _sorted_heroes() -> Array[Dictionary]:
	var heroes := GameData.alive_heroes()
	heroes.sort_custom(func(a, b):
		if a["rarity"] != b["rarity"]:
			return a["rarity"] > b["rarity"]
		return a["id"] < b["id"])
	return heroes


## Remplit une grille de cartes de héros. Les héros de « chosen_ids » ont un cadre lumineux ;
## toucher une carte appelle « on_press » avec le numéro du héros. Les cartes se glissent dans le
## groupe (TeamSlots) ; une carte du groupe lâchée sur la grille appelle « on_remove ».
func _fill_hero_grid(grid: GridContainer, heroes: Array[Dictionary], chosen_ids: Array, on_press: Callable,
		on_remove: Callable) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for hero in heroes:
		var card := UI.make_card(hero)
		if hero["id"] in chosen_ids:
			UI.mark_card_chosen(card, hero)
		card.pressed.connect(func():
			if not card.get_meta("dragged", false):
				on_press.call(hero["id"]))
		TeamSlots.make_draggable(card, hero, "grid")
		TeamSlots.make_removal_zone(card, on_remove)
		grid.add_child(card)


## Retire un héros du groupe avant l'étage (carte du groupe lâchée sur la liste).
func _remove_selected(hero_id: int) -> void:
	selected_ids.erase(hero_id)
	_refresh_team.call_deferred()


## Ajoute ou retire un héros de l'équipe.
func _toggle_hero(hero_id: int) -> void:
	if hero_id in selected_ids:
		selected_ids.erase(hero_id)
	elif selected_ids.size() < GameData.TEAM_SIZE:
		selected_ids.append(hero_id)
	# « call_deferred » : on reconstruit la grille juste après, pas pendant l'appui sur la carte.
	_refresh_team.call_deferred()


## Avant le combat, une fenêtre confirme le groupe (cahier : « ex. Han ★ et Shei ★★★★ »).
func _confirm_group() -> void:
	var names: Array[String] = []
	for hero_id in selected_ids:
		var hero := GameData.hero_by_id(hero_id)
		names.append("%s %s" % [hero["name"], "★".repeat(hero["rarity"])])
	var group := ", ".join(names.slice(0, -1)) + " et " + names[-1] if names.size() > 1 else names[0]
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 600
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	box.add_child(UI.make_system_window("Formation de groupe", [
		"Le groupe est formé : %s." % group,
		"Étage %d — %s. Partir au combat ?" % [chosen_floor, floor_quest["name"]],
	]))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var cancel := UI.make_button("Annuler", func(): overlay.queue_free(), 24)
	cancel.custom_minimum_size = Vector2(0, 84)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(cancel)
	var go := UI.make_button("Confirmer", func():
		overlay.queue_free()
		_start_fight(), 24)
	go.custom_minimum_size = Vector2(0, 84)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(go)


# --- Page 3 : combat ---

func _start_fight() -> void:
	var team: Array[Dictionary] = []
	for hero in GameData.alive_heroes():
		if hero["id"] in selected_ids:
			team.append(hero)

	var floor_number := chosen_floor
	# Le combat est noté dans la sauvegarde : si le jeu est fermé en plein combat,
	# les héros se débrouillent seuls et le résultat est appliqué au lancement suivant.
	# C'est aussi là que les héros prennent leurs armes dans l'arsenal : avant de créer le combat.
	GameData.start_tower_battle(team, floor_enemies, floor_quest, floor_number)
	var battle := Battle.new(team, floor_enemies, floor_quest)
	battle.start()

	_show_page(battle_view)
	battle_view.play(battle, "Étage %d — %s" % [floor_number, floor_quest["name"]])


func _make_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	return margin
