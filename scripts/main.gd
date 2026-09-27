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

var screens := {}
var nav_buttons := {}
var title_label: Label
var gems_label: Label


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
	for screen in screens.values():
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.add_child(screen)

	GameData.gems_changed.connect(func(_amount): _refresh_gems())
	_refresh_gems()
	show_screen("hub")


## Affiche l'écran demandé et cache les autres.
func show_screen(screen_name: String) -> void:
	for key in screens:
		screens[key].visible = key == screen_name
	nav_buttons[screen_name].button_pressed = true
	title_label.text = MENU[screen_name]
	var screen: Control = screens[screen_name]
	if screen.has_method("on_shown"):
		screen.on_shown()


func _refresh_gems() -> void:
	gems_label.text = "%d gemmes" % GameData.gems


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
	gems_label = UI.make_label("", 28)
	gems_label.add_theme_color_override("font_color", ACCENT_COLOR)
	gems_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(gems_label)
	return bar


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
