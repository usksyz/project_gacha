extends Control
## Écran principal : barre du haut (gemmes), écran actif au milieu,
## barre de menus en bas pour passer d'un écran à l'autre.

const BACKGROUND_COLOR := Color("1b1d2a")
const BAR_COLOR := Color("12131c")
const ACCENT_COLOR := Color("f5b82e")

## Nom affiché dans la barre de menus pour chaque écran.
const MENU := {
	"hub": "Hub",
	"summon": "Invocation",
	"collection": "Collection",
	"dungeons": "Donjons",
}

## Écrans ouverts depuis le hub, sans bouton dans la barre de menus (nom affiché en haut).
const HUB_SCREENS := {
	"training": "Terrain d'entraînement",
	"armory": "Armurerie",
	"forge": "Forge",
	"synthesis": "Chambre de synthèse",
}

var screens := {}
var nav_buttons := {}
var title_label: Label
## Or et gemmes, en haut à droite (les gemmes avec leur cristal, avec les nouveaux visuels).
var money_box: HBoxContainer
var settings_panel: SettingsPanel


func _ready() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)

	layout.add_child(_build_top_bar())

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.clip_contents = true
	layout.add_child(content)

	layout.add_child(_build_nav_bar())

	var hub := HubScreen.new()
	hub.navigate.connect(show_screen)
	screens["hub"] = hub
	screens["summon"] = SummonScreen.new()
	screens["collection"] = CollectionScreen.new()
	screens["dungeons"] = DungeonsScreen.new()
	var training := TrainingScreen.new()
	training.navigate.connect(show_screen)
	screens["training"] = training
	var armory := ArmoryScreen.new()
	armory.navigate.connect(show_screen)
	screens["armory"] = armory
	var forge := ForgeScreen.new()
	forge.navigate.connect(show_screen)
	screens["forge"] = forge
	var synthesis := SynthesisScreen.new()
	synthesis.navigate.connect(show_screen)
	screens["synthesis"] = synthesis
	for screen in screens.values():
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.add_child(screen)

	# Les paramètres s'affichent par-dessus tout le reste.
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)

	GameData.gems_changed.connect(func(_amount): _refresh_money())
	GameData.gold_changed.connect(func(_amount): _refresh_money())
	Settings.visuals_changed.connect(_refresh_money)
	_refresh_money()
	show_screen("hub")
	if not GameData.absence_report.is_empty():
		_show_absence_report()
	GameData.facility_completed.connect(_show_facility_completed)
	GameData.relations_changed.connect(_show_relation_news)
	if not GameData.relation_news.is_empty():
		_show_relation_news()


## Des héros se sont brouillés à la cité (Querelleur) : une fenêtre système l'annonce.
func _show_relation_news() -> void:
	if GameData.relation_news.is_empty() or has_node("RelationNews"):
		return  # rien à dire, ou la fenêtre est déjà ouverte (elle montrera tout à sa fermeture)
	Settings.vibrate(150)
	var overlay := ColorRect.new()
	overlay.name = "RelationNews"
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 600
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var lines := GameData.relation_news.duplicate()
	var shown := lines.size()
	lines.append("Rappel : les héros n'ont pas le droit de se battre à la cité. Le conflit se règle par un duel.")
	box.add_child(UI.make_system_window("Hostilité", lines, true))
	var ok := UI.make_button("Compris", func():
		overlay.free()
		# Les annonces arrivées pendant que la fenêtre était ouverte restent, et s'affichent ensuite.
		GameData.relation_news = GameData.relation_news.slice(shown)
		GameData.save_game()
		_show_relation_news(), 24)
	ok.custom_minimum_size.y = 80
	box.add_child(ok)


## Un bâtiment s'est construit tout seul (condition remplie) : une fenêtre l'annonce. Pendant qu'elle
## est ouverte, le hub 3D garde son animation de construction pour après.
func _show_facility_completed(title: String, lines: Array) -> void:
	Settings.vibrate(150)
	HubCity3D.paused = true
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 600
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	box.add_child(UI.make_system_window(title, lines))
	var close := func(go_to_hub: bool):
		overlay.queue_free()
		HubCity3D.paused = false
		if go_to_hub:
			show_screen("hub")
	var see := UI.make_button("Voir dans la cité", func(): close.call(true), 24)
	see.custom_minimum_size.y = 80
	box.add_child(see)
	var later := UI.make_button("Plus tard", func(): close.call(false), 22)
	later.custom_minimum_size.y = 70
	box.add_child(later)


## Le jeu a été fermé en plein combat : on annonce comment les héros s'en sont sortis seuls.
func _show_absence_report() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	overlay.add_child(margin)
	var scroll := UI.make_scroll()
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)

	var report: Dictionary = GameData.absence_report["report"]
	box.add_child(UI.make_system_window("Pendant ton absence", [
		"Le combat de l'étage %d a continué sans toi." % GameData.absence_report["floor"],
		"Tes héros se sont débrouillés seuls.",
	]))
	for window in UI.make_battle_report_windows(report):
		box.add_child(window)
	var ok := UI.make_button("Compris", func():
		overlay.queue_free()
		GameData.absence_report = {})
	ok.custom_minimum_size.y = 90
	box.add_child(ok)


## Affiche l'écran demandé et cache les autres.
func show_screen(screen_name: String) -> void:
	for key in screens:
		screens[key].visible = key == screen_name
	if nav_buttons.has(screen_name):
		nav_buttons[screen_name].button_pressed = true
		title_label.text = MENU[screen_name]
	else:
		# Écran du hub : c'est l'onglet Hub qui reste allumé dans la barre de menus.
		nav_buttons["hub"].button_pressed = true
		title_label.text = HUB_SCREENS[screen_name]
	var screen: Control = screens[screen_name]
	if screen.has_method("on_shown"):
		screen.on_shown()


func _refresh_money() -> void:
	for child in money_box.get_children():
		money_box.remove_child(child)
		child.queue_free()
	# Mode dev : un badge rouge, et de l'or et des gemmes infinis (∞).
	if Settings.dev_mode:
		var badge := UI.make_label("DEV", 20)
		badge.add_theme_color_override("font_color", Color("e05252"))
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		money_box.add_child(badge)
		money_box.add_child(UI.make_gem_amount("  ∞ or   ∞", 24, ACCENT_COLOR))
		return
	money_box.add_child(UI.make_gem_amount("%d or   %d" % [GameData.gold, GameData.gems], 24, ACCENT_COLOR))


func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	var style := UI.make_panel_style(BAR_COLOR)
	style.set_corner_radius_all(0)
	style.content_margin_left = 24
	style.content_margin_right = 24
	bar.add_theme_stylebox_override("panel", style)
	bar.custom_minimum_size.y = 80

	var row := HBoxContainer.new()
	bar.add_child(row)
	title_label = UI.make_label("", 32)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)
	money_box = HBoxContainer.new()
	money_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(money_box)

	# Bouton des paramètres : une roue dentée.
	var settings_button := UI.make_button("", func(): settings_panel.open())
	settings_button.custom_minimum_size = Vector2(72, 72)
	settings_button.flat = true
	var gear := GearIcon.new()
	gear.set_anchors_preset(Control.PRESET_FULL_RECT)
	gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_button.add_child(gear)
	row.add_child(settings_button)
	return bar


## Icône de roue dentée, dessinée avec des formes simples :
## 8 dents (des rectangles tournés), un disque, et un trou au milieu.
class GearIcon extends Control:
	const COLOR := Color("c9cbd6")

	func _draw() -> void:
		var center := size / 2
		var radius := minf(size.x, size.y) * 0.24
		for i in 8:
			draw_set_transform(center, i * TAU / 8)
			draw_rect(Rect2(-radius * 0.28, -radius * 1.4, radius * 0.56, radius * 0.8), COLOR)
		draw_set_transform(Vector2.ZERO)
		draw_circle(center, radius, COLOR)
		draw_circle(center, radius * 0.42, BAR_COLOR)


func _build_nav_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 120
	bar.add_theme_constant_override("separation", 0)

	var normal := UI.make_panel_style(BAR_COLOR)
	normal.set_corner_radius_all(0)
	var selected := UI.make_panel_style(BAR_COLOR.lightened(0.12))
	selected.set_corner_radius_all(0)
	selected.border_color = ACCENT_COLOR
	selected.border_width_top = 5

	# Un seul bouton du groupe peut être enfoncé à la fois : celui de l'écran actif.
	var group := ButtonGroup.new()
	for screen_name in MENU:
		var button := UI.make_button(MENU[screen_name], func(): show_screen(screen_name), 24)
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_pressed_color", ACCENT_COLOR)
		button.add_theme_color_override("font_hover_pressed_color", ACCENT_COLOR)
		UI.set_button_style(button, normal, selected)
		bar.add_child(button)
		nav_buttons[screen_name] = button
	return bar
