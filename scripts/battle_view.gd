class_name BattleView
extends Control
## Écran de combat : rejoue pas à pas un combat déjà calculé par Battle.
## Barres de vie en haut, journal des actions au milieu, résultat à la fin.

signal closed

## Temps entre deux actions affichées, en secondes.
const STEP_DELAY := 0.4

const HERO_COLOR := Color("4caf6a")
const ENEMY_COLOR := Color("e05252")

var battle: Battle
var layout: VBoxContainer
var bars: Array[ProgressBar] = []  # une barre de vie par combattant (héros, puis ennemis)
var hp_labels: Array[Label] = []
var rows: Array[Control] = []
var log_label: RichTextLabel
var skip_button: Button
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


## Lance l'affichage du combat. « reward » = gemmes gagnées (0 en cas de défaite).
func play(new_battle: Battle, title: String, reward: int) -> void:
	battle = new_battle
	skipping = false
	_build(title)

	for event in battle.events:
		_show_event(event)
		if not skipping:
			await get_tree().create_timer(STEP_DELAY).timeout
	_show_result(reward)


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

	skip_button = UI.make_button("Passer l'animation", func(): skipping = true)
	skip_button.custom_minimum_size.y = 80
	layout.add_child(skip_button)


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
		var name_label := UI.make_label(fighter["name"], 20)
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


## Remplace le bouton « Passer » par le résultat du combat.
func _show_result(reward: int) -> void:
	skip_button.queue_free()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	layout.add_child(box)

	var result := UI.make_label("Victoire !" if battle.victory else "Défaite", 40)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_color_override("font_color", Color("f5b82e") if battle.victory else ENEMY_COLOR)
	box.add_child(result)

	if reward > 0:
		var reward_label := UI.make_label("+%d gemmes" % reward, 28)
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(reward_label)

	var dead := []
	for fighter in battle.heroes:
		if fighter["hp"] <= 0:
			dead.append(fighter["name"])
	var losses := "Aucune perte." if dead.is_empty() else "Morts au combat : " + ", ".join(dead)
	var losses_label := UI.make_label(losses, 24)
	losses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	losses_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not dead.is_empty():
		losses_label.add_theme_color_override("font_color", ENEMY_COLOR)
	box.add_child(losses_label)

	var continue_button := UI.make_button("Continuer", func(): closed.emit())
	continue_button.custom_minimum_size.y = 90
	box.add_child(continue_button)
