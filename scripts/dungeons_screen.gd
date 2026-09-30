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
var team_slots: HBoxContainer
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
var team_title: Label
var enemies_box: VBoxContainer
var pick_label: Label
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
		if list_page.visible and is_visible_in_tree() and not GameData.expedition.is_empty():
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


## Carte du donjon journalier : verrouillé, prêt (un bouton par équipe), en cours
## (compte à rebours et derniers ramassages), ou revenu (ce qui a été rapporté).
func _refresh_daily() -> void:
	GameData.update_expedition()
	for child in daily_box.get_children():
		daily_box.remove_child(child)
		child.queue_free()

	var dungeon := "%s (%s)" % [GameData.DAILY_DUNGEON["name"], GameData.DAILY_DUNGEON["difficulty"]]
	if not GameData.expedition_report.is_empty():
		daily_label.text = "Le groupe est revenu !"
		daily_box.add_child(UI.make_system_window("Donjon journalier", GameData.expedition_report["lines"]))
		var ok := UI.make_button("Compris", func():
			GameData.expedition_report = {}
			GameData.save_game()
			_refresh_daily(), 22)
		ok.custom_minimum_size.y = 70
		daily_box.add_child(ok)
		return

	if not GameData.expedition.is_empty():
		var remaining := GameData.expedition_remaining()
		daily_label.text = "%s : l'équipe %d récolte. Rappel dans %d:%02d." % [dungeon,
			GameData.expedition["team_index"] + 1, remaining / 60, remaining % 60]
		if daily_notice != "":
			daily_box.add_child(UI.make_system_window("Donjon journalier", [daily_notice]))
		var entries := GameData.expedition_log_so_far()
		for entry in entries.slice(maxi(0, entries.size() - 6)):
			var line := UI.make_label(entry["text"], 18)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.modulate = Color(1, 1, 1, 0.5 if entry["kind"] == "junk" else 0.85)
			daily_box.add_child(line)
		return

	var problem := GameData.expedition_problem()
	if problem != "":
		daily_label.text = problem
		return
	daily_label.text = "Aujourd'hui : %s. Envoie une équipe (%d minutes de récolte) :" % [
		dungeon, GameData.EXPEDITION_SECONDS / 60]
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	daily_box.add_child(buttons)
	for index in GameData.TEAM_COUNT:
		var members := GameData.expedition_members(index)
		var button := UI.make_button("Équipe %d (%d)" % [index + 1, members.size()], func():
			if GameData.start_expedition(index):
				daily_notice = "L'équipe %d est entrée dans le donjon journalier, %s. Ils reviendront après avoir acquis des matériaux !" \
					% [index + 1, dungeon]
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
	var slots_center := CenterContainer.new()
	slots_panel.add_child(slots_center)
	team_slots = HBoxContainer.new()
	team_slots.add_theme_constant_override("separation", 8)
	slots_center.add_child(team_slots)

	team_hint = UI.make_label("", 22)
	team_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(team_hint)

	var scroll := UI.make_scroll()
	layout.add_child(scroll)
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
	for box in [team_tabs, team_slots]:
		for child in box.get_children():
			box.remove_child(child)
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
	for hero in members:
		var card := UI.make_hero_card(hero)
		card.custom_minimum_size = Vector2(108, 150)
		card.pressed.connect(_toggle_team_member.bind(hero["id"]))  # toucher une carte la retire
		team_slots.add_child(card)
	for i in GameData.TEAM_SIZE - members.size():
		var empty := PanelContainer.new()
		empty.custom_minimum_size = Vector2(108, 150)
		empty.add_theme_stylebox_override("panel", UI.make_panel_style(Color("1b1d2a"), Color("3a3f55"), 2))
		var plus := UI.make_label("+", 40)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.modulate = Color(1, 1, 1, 0.3)
		empty.add_child(plus)
		team_slots.add_child(empty)

	var member_ids := members.map(func(hero): return hero["id"])
	_fill_hero_grid(compose_grid, _sorted_heroes(), member_ids, _toggle_team_member)
	team_hint.text = "Équipe %d : %d/%d héros. Touche un héros pour l'ajouter ou le retirer. Tout est enregistré." \
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

	no_hero_label = UI.make_label("Aucun héros en vie.\nVa en invoquer dans la Salle d'invocation !", 24)
	no_hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(no_hero_label)

	var scroll := UI.make_scroll()
	layout.add_child(scroll)
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
	fight_button = UI.make_button("", _start_fight)
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
	var reward_text := "Récompense : %d or, %d gemmes" % [rewards["gold"], rewards["gems"]]
	if floor_number < GameData.tower_floor:
		reward_text = "Entraînement : %d or, pas de gemmes, %d d'expérience" % [
			roundi(rewards["gold"] * GameData.REPLAY_GOLD_RATE), roundi(rewards["xp"] * GameData.REPLAY_XP_RATE)]
	var header := UI.make_label(reward_text, 22)
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
	_fill_hero_grid(heroes_grid, heroes, selected_ids, _toggle_hero)

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
	pick_label.text = "Choisis une équipe, ou jusqu'à %d héros :" % GameData.TEAM_SIZE
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


## Remplit une grille de cartes de héros. Les héros de « chosen_ids » ont une épaisse
## bordure blanche ; toucher une carte appelle « on_press » avec le numéro du héros.
func _fill_hero_grid(grid: GridContainer, heroes: Array[Dictionary], chosen_ids: Array, on_press: Callable) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for hero in heroes:
		var card := UI.make_hero_card(hero)
		if hero["id"] in chosen_ids:
			var color: Color = GameData.RARITY_COLORS[hero["rarity"]]
			var style := UI.make_panel_style(color.darkened(0.2), Color.WHITE, 8)
			UI.set_button_style(card, style, style)
		card.pressed.connect(on_press.bind(hero["id"]))
		grid.add_child(card)


## Ajoute ou retire un héros de l'équipe.
func _toggle_hero(hero_id: int) -> void:
	if hero_id in selected_ids:
		selected_ids.erase(hero_id)
	elif selected_ids.size() < GameData.TEAM_SIZE:
		selected_ids.append(hero_id)
	# « call_deferred » : on reconstruit la grille juste après, pas pendant l'appui sur la carte.
	_refresh_team.call_deferred()


# --- Page 3 : combat ---

func _start_fight() -> void:
	var team: Array[Dictionary] = []
	for hero in GameData.alive_heroes():
		if hero["id"] in selected_ids:
			team.append(hero)

	var floor_number := chosen_floor
	var battle := Battle.new(team, floor_enemies, floor_quest)
	battle.start()
	# Le combat est noté dans la sauvegarde : si le jeu est fermé en plein combat,
	# les héros se débrouillent seuls et le résultat est appliqué au lancement suivant.
	GameData.start_tower_battle(team, floor_enemies, floor_quest, floor_number)

	_show_page(battle_view)
	battle_view.play(battle, "Étage %d — %s" % [floor_number, floor_quest["name"]])


func _make_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	return margin
