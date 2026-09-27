class_name SummonScreen
extends Control
## Écran d'invocation : boutons pour invoquer et affichage des héros obtenus.

var pity_label: Label
var roster_label: Label
var results_grid: GridContainer
var summon_one_button: Button
var summon_ten_button: Button
var reveal_tween: Tween


func _ready() -> void:
	_build_ui()
	GameData.gems_changed.connect(func(_amount): _refresh_labels())
	_refresh_labels()


func on_shown() -> void:
	_refresh_labels()


func _on_summon(count: int) -> void:
	var heroes := GameData.summon(count)
	if heroes.is_empty():
		return
	_show_results(heroes)
	_refresh_labels()


## Affiche les cartes des héros obtenus, l'une après l'autre.
func _show_results(heroes: Array[Dictionary]) -> void:
	if reveal_tween:
		reveal_tween.kill()
	for child in results_grid.get_children():
		results_grid.remove_child(child)
		child.queue_free()

	reveal_tween = create_tween()
	for hero in heroes:
		var card := UI.make_hero_card(hero)
		card.modulate.a = 0.0
		results_grid.add_child(card)
		reveal_tween.tween_property(card, "modulate:a", 1.0, 0.15)


func _refresh_labels() -> void:
	pity_label.text = "5 étoiles garanti dans %d invocations" % GameData.summons_before_pity()
	roster_label.text = "Héros possédés : %d" % GameData.roster.size()
	summon_one_button.disabled = not GameData.can_afford(1)
	summon_ten_button.disabled = not GameData.can_afford(10)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	margin.add_child(layout)

	var title := UI.make_label("Salle d'invocation", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	pity_label = UI.make_label("", 24)
	pity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(pity_label)

	var results_area := CenterContainer.new()
	results_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(results_area)
	results_grid = GridContainer.new()
	results_grid.columns = 5
	results_grid.add_theme_constant_override("h_separation", 8)
	results_grid.add_theme_constant_override("v_separation", 8)
	results_area.add_child(results_grid)

	roster_label = UI.make_label("", 24)
	roster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(roster_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	layout.add_child(buttons)
	summon_one_button = _make_summon_button(1)
	buttons.add_child(summon_one_button)
	summon_ten_button = _make_summon_button(10)
	buttons.add_child(summon_ten_button)

	# Bouton temporaire pour tester sans limite de gemmes.
	var test_button := UI.make_button("+1000 gemmes (test)", func(): GameData.add_gems(1000))
	test_button.custom_minimum_size.y = 70
	layout.add_child(test_button)


func _make_summon_button(count: int) -> Button:
	var text := "Invoquer x%d\n%d gemmes" % [count, GameData.SUMMON_COST * count]
	var button := UI.make_button(text, func(): _on_summon(count))
	button.custom_minimum_size.y = 110
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button
