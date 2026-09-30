class_name SummonScreen
extends Control
## Écran d'invocation : deux sortes d'invocation (voir GameData.SUMMON_TYPES),
## chacune avec ses boutons x1 et x10, et l'affichage des héros obtenus.
## - normale : payée en or, héros de base ;
## - spéciale : payée en gemmes, meilleures chances de hauts rangs, seule à donner des mages.

var pity_label: Label
var roster_label: Label
var results_grid: GridContainer
## Boutons d'invocation : [sorte, nombre, bouton], pour les griser quand on ne peut pas payer.
var summon_buttons: Array = []
var reveal_tween: Tween


func _ready() -> void:
	_build_ui()
	GameData.gems_changed.connect(func(_amount): _refresh_labels())
	GameData.gold_changed.connect(func(_amount): _refresh_labels())
	_refresh_labels()


func on_shown() -> void:
	_refresh_labels()


func _on_summon(summon_type: String, count: int) -> void:
	var heroes := GameData.summon(summon_type, count)
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
	pity_label.text = "Invocation spéciale : 5 étoiles garanti dans %d invocations" % GameData.summons_before_pity()
	roster_label.text = "Héros possédés : %d" % GameData.roster.size()
	for entry in summon_buttons:
		entry[2].disabled = not GameData.can_afford(entry[0], entry[1])


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var title := UI.make_label("Salle d'invocation", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	pity_label = UI.make_label("", 22)
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

	# Une ligne par sorte d'invocation : son nom, ses chances, puis les boutons x1 et x10.
	for summon_type in GameData.SUMMON_TYPES:
		var info: Dictionary = GameData.SUMMON_TYPES[summon_type]
		var name_label := UI.make_label(info["name"], 26)
		layout.add_child(name_label)
		var rates := UI.make_label(_rates_text(info), 18)
		rates.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rates.modulate = Color(1, 1, 1, 0.65)
		layout.add_child(rates)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 16)
		layout.add_child(buttons)
		for count in [1, 10]:
			var button := _make_summon_button(summon_type, count)
			buttons.add_child(button)
			summon_buttons.append([summon_type, count, button])

	# Boutons temporaires pour tester sans limite d'or ni de gemmes.
	var tests := HBoxContainer.new()
	tests.add_theme_constant_override("separation", 16)
	layout.add_child(tests)
	var test_gems := UI.make_button("+1000 gemmes (test)", func(): GameData.add_gems(1000), 22)
	var test_gold := UI.make_button("+50 000 or (test)", func(): GameData.add_gold(50000), 22)
	for button in [test_gems, test_gold]:
		button.custom_minimum_size.y = 64
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tests.add_child(button)


## « 5★ 0,2 %  4★ 1,8 %  ... » (+ « mages possibles » pour la spéciale).
func _rates_text(info: Dictionary) -> String:
	var parts := []
	for rarity in info["rates"]:
		parts.append("%d★ %s %%" % [rarity, String.num(info["rates"][rarity] * 100.0, 1).replace(".", ",")])
	var text := "  ".join(parts)
	if info["mages"]:
		text += "  — mages possibles"
	return text


func _make_summon_button(summon_type: String, count: int) -> Button:
	var info: Dictionary = GameData.SUMMON_TYPES[summon_type]
	var currency := "or" if info["currency"] == "gold" else "gemmes"
	var text := "x%d\n%d %s" % [count, info["cost"] * count, currency]
	var button := UI.make_button(text, func(): _on_summon(summon_type, count), 24)
	button.custom_minimum_size.y = 90
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button
