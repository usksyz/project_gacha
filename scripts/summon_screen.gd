extends Control
## Écran d'invocation : boutons pour invoquer et affichage des héros obtenus.
## L'interface est construite par le code (voir _build_ui).

const BACKGROUND_COLOR := Color("1b1d2a")

var gems_label: Label
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
		var card := _make_hero_card(hero)
		card.modulate.a = 0.0
		results_grid.add_child(card)
		reveal_tween.tween_property(card, "modulate:a", 1.0, 0.15)


func _refresh_labels() -> void:
	gems_label.text = "Gemmes : %d" % GameData.gems
	pity_label.text = "5 étoiles garanti dans %d invocations" % GameData.summons_before_pity()
	roster_label.text = "Héros possédés : %d" % GameData.roster.size()
	summon_one_button.disabled = not GameData.can_afford(1)
	summon_ten_button.disabled = not GameData.can_afford(10)


# --- Construction de l'interface ---

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	margin.add_child(layout)

	gems_label = _make_label("", 32)
	layout.add_child(gems_label)
	pity_label = _make_label("", 24)
	layout.add_child(pity_label)

	var title := _make_label("Invocation", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	var results_area := CenterContainer.new()
	results_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(results_area)
	results_grid = GridContainer.new()
	results_grid.columns = 5
	results_grid.add_theme_constant_override("h_separation", 8)
	results_grid.add_theme_constant_override("v_separation", 8)
	results_area.add_child(results_grid)

	roster_label = _make_label("", 24)
	roster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(roster_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	layout.add_child(buttons)
	summon_one_button = _make_button("Invoquer x1\n%d gemmes" % GameData.SUMMON_COST, func(): _on_summon(1))
	buttons.add_child(summon_one_button)
	summon_ten_button = _make_button("Invoquer x10\n%d gemmes" % (GameData.SUMMON_COST * 10), func(): _on_summon(10))
	buttons.add_child(summon_ten_button)

	# Bouton temporaire pour tester sans limite de gemmes.
	var test_button := _make_button("+1000 gemmes (test)", func(): GameData.add_gems(1000))
	test_button.custom_minimum_size.y = 70
	layout.add_child(test_button)


func _make_hero_card(hero: Dictionary) -> Control:
	var color: Color = GameData.RARITY_COLORS[hero["rarity"]]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(120, 170)
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.6)
	style.border_color = color
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(content)

	var stars := _make_label("%d étoiles" % hero["rarity"], 15)
	stars.add_theme_color_override("font_color", color)
	content.add_child(stars)
	content.add_child(_make_label(hero["name"], 18))
	var role := _make_label(hero["role"], 14)
	role.modulate = Color(1, 1, 1, 0.7)
	content.add_child(role)

	for label in content.get_children():
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return card


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 110
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(on_pressed)
	return button
