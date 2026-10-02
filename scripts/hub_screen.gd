class_name HubScreen
extends Control
## Le hub : la cité vue du ciel. Appuyer sur un quartier ouvre l'écran correspondant,
## ou affiche une description si le quartier n'est pas encore disponible.

## Demande à l'écran principal d'afficher un autre écran.
signal navigate(screen_name: String)

## Les lieux en dehors des remparts.
const OUTSIDE_ZONES := [
	{"name": "Faille spatio-temporelle", "target": "dungeons",
		"info": "Le passage vers les donjons."},
	{"name": "Zone de débarquement", "target": "",
		"info": "Là où reviennent tes héros après une expédition. (Bientôt)"},
]

var info_label: Label
## La cité (HubCity3D ou HubMap) et la colonne qui la contient.
var map: Control
var map_layout: VBoxContainer

## Clavier des codes secrets, ouvert par la Place publique (aussi disponible dans les paramètres).
var code_pad: CodePad

## Fenêtre de construction des bâtiments de magie (il faut un mage).
var construction_panel: ConstructionPanel
## Fenêtre des affectations : les héros assistants de chaque bâtiment construit.
var assignment_panel: AssignmentPanel


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	map_layout = layout
	map = _make_map()
	layout.add_child(map)
	Settings.visuals_changed.connect(_swap_map)

	var outside := HBoxContainer.new()
	outside.add_theme_constant_override("separation", 16)
	layout.add_child(outside)
	for zone in OUTSIDE_ZONES:
		var button := UI.make_button(zone["name"], func(): _on_zone_pressed(zone), 20)
		button.custom_minimum_size.y = 80
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outside.add_child(button)

	var city_buttons := HBoxContainer.new()
	city_buttons.add_theme_constant_override("separation", 16)
	layout.add_child(city_buttons)
	for entry in [["Construction", func(): construction_panel.open()],
			["Affectations", func(): assignment_panel.open()]]:
		var button := UI.make_button(entry[0], entry[1], 22)
		button.custom_minimum_size.y = 70
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		city_buttons.add_child(button)

	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b")))
	info_panel.custom_minimum_size.y = 100
	layout.add_child(info_panel)
	info_label = UI.make_label(_default_info(), 22)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_panel.add_child(info_label)

	code_pad = CodePad.new()
	add_child(code_pad)
	construction_panel = ConstructionPanel.new()
	add_child(construction_panel)
	assignment_panel = AssignmentPanel.new()
	add_child(assignment_panel)


## La cité : en 3D avec les nouveaux visuels (HubCity3D, où l'on voit vivre les héros),
## sinon l'ancien plan dessiné (HubMap), gardé pour comparer.
func _make_map() -> Control:
	var new_map: Control
	if Settings.new_visuals:
		var city := HubCity3D.new()
		city.zone_pressed.connect(_on_zone_pressed)
		city.hero_pressed.connect(_on_hero_pressed)
		new_map = city
	else:
		var plan := HubMap.new()
		plan.zone_pressed.connect(_on_zone_pressed)
		new_map = plan
	new_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return new_map


## Changement de visuels (paramètres) : on remplace la cité par l'autre version.
func _swap_map() -> void:
	var index := map.get_index()
	map.queue_free()
	map = _make_map()
	map_layout.add_child(map)
	map_layout.move_child(map, index)
	info_label.text = _default_info()


func _default_info() -> String:
	if Settings.new_visuals:
		return "Glisse pour te déplacer, pince pour zoomer. Touche un lieu ou un héros."
	return "Appuie sur un lieu de la cité."


## Un héros touché dans la cité 3D : ce qu'il est en train de faire.
func _on_hero_pressed(hero: Dictionary) -> void:
	var doing := "se promène dans la cité"
	if hero.get("training", "") != "" and GameData.training_unlocked():
		doing = "s'entraîne au terrain (%s)" % hero["training"]
	elif hero.get("post", "") != "" and GameData.BUILDINGS.has(hero["post"]):
		doing = "travaille comme assistant : %s" % GameData.BUILDINGS[hero["post"]]["name"]
	info_label.text = "%s (%s, %s, niv. %d) %s." % [hero["name"], "★".repeat(hero["rarity"]),
		hero["class"], hero["level"], doing]


func on_shown() -> void:
	code_pad.visible = false
	construction_panel.visible = false
	assignment_panel.visible = false


func _on_zone_pressed(zone: Dictionary) -> void:
	info_label.text = "%s : %s" % [zone["name"], zone["info"]]
	# Le terrain d'entraînement ne s'ouvre qu'après quelques tirages d'armes.
	if zone["target"] == "training" and not GameData.training_unlocked():
		info_label.text = "%s : encore fermé. Il s'ouvre après %d armes tirées à l'Armurerie (%d / %d)." % [
			zone["name"], GameData.TRAINING_UNLOCK_DRAWS, GameData.weapon_draws, GameData.TRAINING_UNLOCK_DRAWS]
		return
	# La chambre de synthèse se construit d'abord (bouton « Construction »).
	if zone["target"] == "synthesis" and not "synthese" in GameData.buildings:
		info_label.text = "%s : pas encore construite. Construis-la avec le bouton « Construction » (%d gemmes)." \
			% [zone["name"], GameData.BUILDINGS["synthese"]["cost"]]
		return
	# Le laboratoire d'alchimie est un bâtiment de magie : il faut le construire (avec un mage).
	if zone["name"] == GameData.BUILDINGS["laboratoire"]["name"]:
		if "laboratoire" in GameData.buildings:
			info_label.text = "%s : construit. %s (Bientôt)" % [zone["name"], GameData.BUILDINGS["laboratoire"]["info"]]
		else:
			info_label.text = "%s : pas encore construit. Il faut un mage parmi tes héros (bouton « Construction »)." % zone["name"]
		return
	if zone["target"] == "code":
		code_pad.open()
	elif zone["target"] != "":
		navigate.emit(zone["target"])