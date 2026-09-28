class_name DungeonsScreen
extends Control
## Donjons : la Tour (combats automatiques, étage par étage) et les donjons journaliers (à venir).
## L'écran a trois « pages » : la liste des donjons, le choix de l'équipe, et le combat.

const DAILY_MODES := [
	{"name": "Donjon d'expérience", "info": "Donjon journalier : fais gagner de l'expérience à tes héros."},
	{"name": "Donjon de ressources", "info": "Donjon journalier : récolte des matériaux pour la cité."},
	{"name": "Donjon d'or", "info": "Donjon journalier : amasse de l'or."},
]

var list_page: Control
var team_page: Control
var battle_view: BattleView

var floor_label: Label
var team_title: Label
var enemies_box: VBoxContainer
var pick_label: Label
var heroes_grid: GridContainer
var no_hero_label: Label
var fight_button: Button

## Ennemis de l'étage qu'on s'apprête à affronter.
var floor_enemies: Array[Dictionary] = []
## Numéros (id) des héros choisis pour le combat.
var selected_ids: Array[int] = []


func _ready() -> void:
	list_page = _build_list_page()
	team_page = _build_team_page()
	battle_view = BattleView.new()
	battle_view.closed.connect(func(): _show_page(list_page))
	for page in [list_page, team_page, battle_view]:
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(page)
	_show_page(list_page)


func on_shown() -> void:
	# Un combat en cours reste affiché ; sinon on revient à la liste des donjons.
	if not battle_view.visible:
		_show_page(list_page)


func _show_page(page: Control) -> void:
	for other in [list_page, team_page, battle_view]:
		other.visible = other == page
	if page == list_page:
		floor_label.text = "Étage actuel : %d" % GameData.tower_floor


# --- Page 1 : liste des donjons ---

func _build_list_page() -> Control:
	var margin := _make_margin()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var tower := _make_card(layout, "La Tour",
		"Grimpe les étages un par un. Chaque étage est plus dangereux que le précédent. Un boss garde tous les 10 étages.")
	floor_label = UI.make_label("", 26)
	floor_label.add_theme_color_override("font_color", Color("f5b82e"))
	tower.add_child(floor_label)
	var enter := UI.make_button("Entrer dans la Tour", _open_tower)
	enter.custom_minimum_size.y = 80
	tower.add_child(enter)

	for mode in DAILY_MODES:
		var content := _make_card(layout, mode["name"], mode["info"])
		var soon := UI.make_label("Bientôt", 22)
		soon.add_theme_color_override("font_color", Color("f5b82e"))
		content.add_child(soon)
	return margin


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


# --- Page 2 : choix de l'équipe ---

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

	no_hero_label = UI.make_label("Aucun héros en vie.\nVa en invoquer dans la Salle d'invocation !", 24)
	no_hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(no_hero_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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


## Prépare l'étage actuel (ennemis) et affiche le choix de l'équipe.
func _open_tower() -> void:
	var floor_number := GameData.tower_floor
	floor_enemies = GameData.tower_enemies(floor_number)
	selected_ids.clear()

	team_title.text = "Étage %d" % floor_number
	if GameData.is_boss_floor(floor_number):
		team_title.text += " — Boss !"

	for child in enemies_box.get_children():
		child.queue_free()
	var header := UI.make_label("Ennemis (récompense : %d gemmes)" % GameData.tower_reward(floor_number), 22)
	header.modulate = Color(1, 1, 1, 0.7)
	enemies_box.add_child(header)
	for enemy in floor_enemies:
		var stats: Dictionary = enemy["stats"]
		var text := "%s (%s) — PV %d, ATQ %d" % [enemy["name"], enemy["class"], stats["hp"], stats["atk"]]
		enemies_box.add_child(UI.make_label(text, 22))

	_refresh_team()
	_show_page(team_page)


func _refresh_team() -> void:
	for child in heroes_grid.get_children():
		heroes_grid.remove_child(child)
		child.queue_free()

	# Tri : les plus rares d'abord, puis dans l'ordre d'invocation.
	var heroes := GameData.alive_heroes()
	heroes.sort_custom(func(a, b):
		if a["rarity"] != b["rarity"]:
			return a["rarity"] > b["rarity"]
		return a["id"] < b["id"])

	for hero in heroes:
		var card := UI.make_hero_card(hero)
		if hero["id"] in selected_ids:
			# Un héros choisi a une épaisse bordure blanche.
			var color: Color = GameData.RARITY_COLORS[hero["rarity"]]
			var style := UI.make_panel_style(color.darkened(0.2), Color.WHITE, 8)
			UI.set_button_style(card, style, style)
		card.pressed.connect(_toggle_hero.bind(hero["id"]))
		heroes_grid.add_child(card)

	no_hero_label.visible = heroes.is_empty()
	pick_label.text = "Choisis jusqu'à %d héros :" % GameData.TEAM_SIZE
	fight_button.text = "Combattre (%d/%d)" % [selected_ids.size(), GameData.TEAM_SIZE]
	fight_button.disabled = selected_ids.is_empty()


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

	var floor_number := GameData.tower_floor
	var battle := Battle.new(team, floor_enemies)
	battle.run()
	# Le résultat est appliqué tout de suite : quitter l'écran pendant l'animation
	# ne permet pas d'éviter la mort d'un héros.
	var reward := GameData.finish_tower_battle(battle)

	_show_page(battle_view)
	battle_view.play(battle, "La Tour — Étage %d" % floor_number, reward)


func _make_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	return margin
