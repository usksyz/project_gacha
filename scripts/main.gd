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
## Conseils du Système en attente (voir GameData.show_tip) : montrés un par un, quand aucune autre
## fenêtre de main.gd n'est ouverte.
var tip_queue: Array[String] = []
## Noms des fenêtres de main.gd : un conseil attend qu'elles soient fermées.
const WINDOW_NAMES := ["Tip", "RelationNews", "Challenge", "Facility", "Absence"]
## Tutoriel (voir GameData, game_state.gd) : l'écran de chaque étape. Son onglet est le seul permis.
const TUTORIAL_SCREENS := {"invocation": "summon", "equipe": "dungeons", "etage": "dungeons", "synthese": "synthesis"}
var tutorial_banner: PanelContainer
var tutorial_label: Label


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

	# Bandeau du tutoriel, sous la barre du haut : ce qu'il faut faire maintenant (voir _refresh_tutorial).
	tutorial_banner = PanelContainer.new()
	var banner_style := UI.make_panel_style(Color("2a2140"), Color("9b6be0"), 2)
	banner_style.set_corner_radius_all(0)
	tutorial_banner.add_theme_stylebox_override("panel", banner_style)
	tutorial_label = UI.make_label("", 22)
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.add_theme_color_override("font_color", Color("d9c4ff"))
	tutorial_banner.add_child(tutorial_label)
	layout.add_child(tutorial_banner)

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
	# Pendant le tutoriel, on reprend directement à l'écran de son étape.
	show_screen(TUTORIAL_SCREENS.get(GameData.tutorial_step, "hub"))
	if not GameData.absence_report.is_empty():
		_show_absence_report()
	GameData.facility_completed.connect(_show_facility_completed)
	GameData.relations_changed.connect(_show_relation_news)
	_show_relation_news()
	GameData.tip_requested.connect(_queue_tip)
	GameData.tutorial_changed.connect(_refresh_tutorial)
	_refresh_tutorial()
	GameData.show_tip("bienvenue")  # partie neuve : le Système accueille le Maître (une seule fois)
	if GameData.tutorial_step != "":
		GameData.show_tutorial_tip()  # la fenêtre de l'étape en cours, si elle n'a pas encore été lue


## Tutoriel : le bandeau dit quoi faire, et seul l'onglet de l'étape est permis (aucun pendant la
## synthèse, qui se fait dans la chambre de synthèse, ouverte par la fenêtre de l'étape).
func _refresh_tutorial() -> void:
	var step := GameData.tutorial_step
	tutorial_banner.visible = step != ""
	tutorial_label.text = SystemTips.tutorial_goal(step)
	for screen_name in nav_buttons:
		nav_buttons[screen_name].disabled = step != "" and TUTORIAL_SCREENS.get(step, "") != screen_name


## Un conseil du Système est demandé : il attend son tour (un seul à la fois, et pas deux fois le même).
func _queue_tip(tip_id: String) -> void:
	if not tip_id in tip_queue:
		tip_queue.append(tip_id)
	_show_next_tip.call_deferred()


## Ferme une fenêtre de main.gd : elle change de nom tout de suite (elle ne compte plus comme ouverte,
## voir _window_open), et elle est libérée juste après (pas pendant l'appui sur son bouton).
func _close_window(overlay: Control) -> void:
	overlay.name = "Closed"
	overlay.queue_free()


## Vrai si une fenêtre de main.gd est ouverte (un conseil attend alors qu'elle se ferme).
func _window_open() -> bool:
	for window_name in WINDOW_NAMES:
		if has_node(window_name):
			return true
	return false


## Affiche le prochain conseil en attente : fenêtre système « Conseil », bouton « Compris ».
## Il n'est noté comme vu (dans la sauvegarde) qu'une fois la fenêtre fermée.
func _show_next_tip() -> void:
	if tip_queue.is_empty() or _window_open():
		return
	var tip_id: String = tip_queue.pop_front()
	if tip_id in GameData.seen_tips or not (Settings.tips or GameData.is_tutorial_tip(tip_id)):
		_show_next_tip()
		return
	HubCity3D.paused = true
	var overlay := ColorRect.new()
	overlay.name = "Tip"
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
	box.add_child(UI.make_system_window(SystemTips.title(tip_id), SystemTips.lines(tip_id)))
	if not GameData.is_tutorial_tip(tip_id):
		var hint := UI.make_label("Paramètres : « Conseils du Système » pour les couper.", 18)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.modulate = Color(1, 1, 1, 0.5)
		box.add_child(hint)
	var ok := UI.make_button("Compris", func():
		_close_window(overlay)
		HubCity3D.paused = has_node("Facility")
		GameData.mark_tip_seen(tip_id)
		# Tutoriel : la synthèse se fait dans sa chambre ; une fois fini, on découvre la cité.
		if tip_id == "tuto_synthese" and GameData.tutorial_step == "synthese":
			show_screen("synthesis")
		elif tip_id == "tuto_fin":
			show_screen("hub")
		_show_next_tip(), 24)
	ok.custom_minimum_size.y = 80
	box.add_child(ok)


## Des héros se sont brouillés à la cité (Querelleur) : une fenêtre système l'annonce. Ensuite, les défis
## lancés par les héros, un par un (voir _show_next_challenge).
func _show_relation_news() -> void:
	if has_node("RelationNews") or has_node("Challenge"):
		return  # une fenêtre est déjà ouverte : elle montrera la suite à sa fermeture
	if GameData.relation_news.is_empty():
		_show_next_challenge()
		return
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
		_show_relation_news()
		_show_next_tip(), 24)
	ok.custom_minimum_size.y = 80
	box.add_child(ok)


## Un héros a défié son rival (voir GameData, personality.gd) : « Autoriser le duel » ou « Refuser ».
func _show_next_challenge() -> void:
	var next := GameData.next_challenge()
	if next.is_empty() or GameData.duel_problem(next["challenger"], next["rival"]) != "":
		return  # aucun défi, ou l'un des deux est parti en mission : le défi attendra son retour
	Settings.vibrate(150)
	var panel := DuelPanel.open(self, next["challenger"], next["rival"], true)
	panel.name = "Challenge"
	panel.finished.connect(func():
		panel.name = "ChallengeDone"  # (libéré juste après) : le défi suivant peut s'ouvrir
		_show_relation_news.call_deferred()
		_show_next_tip.call_deferred())


## Un bâtiment s'est construit tout seul (condition remplie) : une fenêtre l'annonce. Pendant qu'elle
## est ouverte, le hub 3D garde son animation de construction pour après.
func _show_facility_completed(title: String, lines: Array) -> void:
	Settings.vibrate(150)
	HubCity3D.paused = true
	var overlay := ColorRect.new()
	overlay.name = "Facility"
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
		_close_window(overlay)
		HubCity3D.paused = has_node("Facility") or has_node("Tip")
		if go_to_hub and GameData.tutorial_step == "":  # pas pendant le tutoriel (onglets fermés)
			show_screen("hub")
		_show_next_tip()  # un conseil attendait peut-être la fermeture (premier bâtiment)
	var see := UI.make_button("Voir dans la cité", func(): close.call(true), 24)
	see.custom_minimum_size.y = 80
	box.add_child(see)
	var later := UI.make_button("Plus tard", func(): close.call(false), 22)
	later.custom_minimum_size.y = 70
	box.add_child(later)


## Le jeu a été fermé en plein combat : on annonce comment les héros s'en sont sortis seuls.
func _show_absence_report() -> void:
	var overlay := ColorRect.new()
	overlay.name = "Absence"
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
		_close_window(overlay)
		GameData.absence_report = {}
		# Conseils de fin de combat (premier blessé, première mort), une fois le rapport lu.
		for tip_id in report.get("tips", []):
			GameData.show_tip(tip_id)
		_show_next_tip())
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
