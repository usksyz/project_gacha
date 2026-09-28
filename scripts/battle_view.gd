class_name BattleView
extends Control
## Écran de combat : rejoue pas à pas un combat déjà calculé par Battle.
## Barres de vie en haut, journal des actions au milieu, résultat à la fin.

signal closed

## Temps entre deux actions affichées, en secondes (à vitesse x1).
const STEP_DELAY := 0.5

## Vitesses proposées par le bouton d'accélération.
const SPEEDS := [1, 2, 4]

const HERO_COLOR := Color("4caf6a")
const ENEMY_COLOR := Color("e05252")

var battle: Battle
var layout: VBoxContainer
var bars: Array[ProgressBar] = []  # une barre de vie par combattant (héros, puis ennemis)
var hp_labels: Array[Label] = []
var rows: Array[Control] = []
var log_label: RichTextLabel
var controls: HBoxContainer
var speed_button: Button
var skipping := false


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)


## Lance l'affichage du combat. « report » = le rapport de GameData.finish_tower_battle.
func play(new_battle: Battle, title: String, report: Dictionary) -> void:
	battle = new_battle
	skipping = false
	_build(title)

	for event in new_battle.events:
		_show_event(event)
		if not skipping:
			await get_tree().create_timer(STEP_DELAY / SPEEDS[Settings.battle_speed_index]).timeout
		if battle != new_battle:
			return  # un autre combat a commencé entre-temps : on arrête de rejouer celui-ci
	_show_result(report)


func _build(title: String) -> void:
	for child in layout.get_children():
		layout.remove_child(child)
		child.queue_free()
	bars.clear()
	hp_labels.clear()
	rows.clear()

	var title_label := UI.make_label(title, 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title_label)

	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 24)
	layout.add_child(teams)
	teams.add_child(_build_team_column("Ton équipe", battle.heroes, HERO_COLOR))
	teams.add_child(_build_team_column("Ennemis", battle.enemies, ENEMY_COLOR))

	# Journal : la dernière ligne reste toujours visible.
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 20)
	log_label.add_theme_stylebox_override("normal", UI.make_panel_style(Color("12131c")))
	layout.add_child(log_label)

	# Boutons du bas : accélération (la vitesse choisie est enregistrée dans les paramètres) et fin directe.
	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	layout.add_child(controls)
	speed_button = UI.make_button("", _next_speed)
	speed_button.custom_minimum_size = Vector2(200, 80)
	controls.add_child(speed_button)
	_next_speed(0)
	var skip_button := UI.make_button("Passer", func(): skipping = true)
	skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(skip_button)


## Passe à la vitesse suivante (x1 → x2 → x4 → x1). « step » = 0 pour juste afficher la vitesse.
func _next_speed(step := 1) -> void:
	if step != 0:
		Settings.change("battle_speed_index", (Settings.battle_speed_index + step) % SPEEDS.size())
	speed_button.text = "Vitesse x%d" % SPEEDS[Settings.battle_speed_index]


func _build_team_column(team_name: String, fighters: Array, color: Color) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	var header := UI.make_label(team_name, 26)
	header.add_theme_color_override("font_color", color)
	column.add_child(header)

	for fighter in fighters:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		column.add_child(row)

		var line := HBoxContainer.new()
		row.add_child(line)
		var name_label := UI.make_label("%s  niv. %d" % [fighter["name"], fighter["level"]], 20)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		line.add_child(name_label)
		var hp_label := UI.make_label("", 18)
		line.add_child(hp_label)

		var bar := ProgressBar.new()
		bar.max_value = fighter["max_hp"]
		bar.show_percentage = false
		bar.custom_minimum_size.y = 16
		bar.add_theme_stylebox_override("background", _bar_style(Color("12131c")))
		bar.add_theme_stylebox_override("fill", _bar_style(color))
		row.add_child(bar)

		rows.append(row)
		bars.append(bar)
		hp_labels.append(hp_label)
		_set_hp(rows.size() - 1, fighter["max_hp"])
	return column


func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style


func _show_event(event: Dictionary) -> void:
	log_label.add_text(event["text"] + "\n")
	for i in bars.size():
		_set_hp(i, event["hp"][i])


func _set_hp(index: int, hp: int) -> void:
	bars[index].value = hp
	hp_labels[index].text = "%d/%d" % [hp, bars[index].max_value]
	# Un combattant à terre est grisé.
	rows[index].modulate = Color(1, 1, 1) if hp > 0 else Color(0.4, 0.4, 0.4)


## Remplace les boutons du bas par les fenêtres de fin de combat :
## une fenêtre rouge par héros mort, puis le résultat (récompenses, niveaux, MVP).
func _show_result(report: Dictionary) -> void:
	controls.queue_free()

	# Le journal et les fenêtres de fin se partagent la place ; les fenêtres défilent si besoin.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)

	if not report["dead"].is_empty():
		Settings.vibrate(400)
	for death in report["dead"]:
		var hero: Dictionary = death["hero"]
		box.add_child(UI.make_system_window("Un héros est tombé", [
			"%s (%s) a quitté ce monde pour toujours." % [hero["name"], UI.rarity_text(hero["rarity"])],
			"Cause : %s." % death["cause"],
		], true))

	var lines := []
	if report["victory"]:
		lines.append("+%d or   +%d gemmes" % [report["gold"], report["gems"]])
	else:
		lines.append("Les survivants sont ramenés à la cité.")
	lines.append("+%d expérience pour chaque survivant" % report["xp"])
	for level_up in report["level_ups"]:
		var hero: Dictionary = level_up["hero"]
		lines.append("%s passe au niveau %d !" % [hero["name"], hero["level"]])
	if report["mvp"] != "":
		lines.append("MVP : %s" % report["mvp"])
	box.add_child(UI.make_system_window("Étage conquis !" if report["victory"] else "Défaite", lines))

	var continue_button := UI.make_button("Continuer", func(): closed.emit())
	continue_button.custom_minimum_size.y = 90
	box.add_child(continue_button)
