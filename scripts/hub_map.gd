class_name HubMap
extends Control
## Plan circulaire de la cité, dessiné par le code : un rempart, une place au centre
## et des quartiers tout autour. Chaque quartier a un bouton pour interagir avec.

signal zone_pressed(zone: Dictionary)

const WALL_COLOR := Color("8c8a80")
const BORDER_COLOR := Color(0, 0, 0, 0.35)
const WALL_THICKNESS := 18.0
## Taille de la place centrale, par rapport au rayon de la cité.
const PLAZA_RATIO := 0.3

## Les quartiers, dans l'ordre des aiguilles d'une montre en partant du haut.
## « target » : l'écran ouvert quand on appuie (vide = pas encore disponible).
const ZONES := [
	{"name": "Salle de combat", "label": "Salle de\ncombat", "color": Color("3a7ca5"), "target": "",
		"info": "Affrontements et entraînements au combat. (Bientôt)"},
	{"name": "Salle d'invocation", "label": "Salle\nd'invocation", "color": Color("b8923a"), "target": "summon",
		"info": "Invoque de nouveaux héros."},
	{"name": "Armurerie", "label": "Armurerie", "color": Color("8a5a3c"), "target": "armory",
		"info": "Tirage d'armes, arsenal et équipement de tes héros."},
	{"name": "Laboratoire d'alchimie", "label": "Laboratoire\nd'alchimie", "color": Color("4a63c9"), "target": "",
		"info": "Prépare des potions et des objets. (Bientôt)"},
	{"name": "Chambre de synthèse", "label": "Chambre de\nsynthèse", "color": Color("7d7896"), "target": "synthesis",
		"info": "Sacrifie un héros pour en renforcer un autre."},
	{"name": "Terrain d'entraînement", "label": "Terrain\nd'entraînement", "color": Color("7a3fb0"), "target": "training",
		"info": "Tes héros y apprennent des compétences, même quand le jeu est fermé."},
	{"name": "Résidences", "label": "Résidences", "color": Color("b0304f"), "target": "collection",
		"info": "Là où vivent tes héros."},
]

## La place ouvre le clavier des codes secrets (voir HubScreen).
const PLAZA := {"name": "Place publique", "label": "Place\npublique", "color": Color("a89868"), "target": "code",
	"info": "Le cœur de la cité. Une vieille stèle attend qu'on y grave un mot de passe..."}

var zone_buttons: Array[Button] = []
var plaza_button: Button


func _ready() -> void:
	for zone in ZONES:
		var button := _make_zone_button(zone)
		zone_buttons.append(button)
	plaza_button = _make_zone_button(PLAZA)
	resized.connect(_place_buttons)
	_place_buttons()


func _draw() -> void:
	var center := size / 2.0
	var outer := _outer_radius()
	var inner := outer - WALL_THICKNESS
	var plaza := inner * PLAZA_RATIO
	var slice := TAU / ZONES.size()

	# Le rempart, avec des tours tout autour.
	draw_circle(center, outer, WALL_COLOR)
	for i in 16:
		var tower := center + Vector2.from_angle(TAU * i / 16) * (outer - WALL_THICKNESS / 2.0)
		draw_circle(tower, 12.0, WALL_COLOR.lightened(0.25))

	# Les quartiers : chacun est une part de l'anneau entre la place et le rempart.
	for i in ZONES.size():
		var start := -PI / 2.0 + i * slice
		var points := PackedVector2Array()
		var steps := 16
		for s in steps + 1:
			points.append(center + Vector2.from_angle(start + slice * s / steps) * inner)
		for s in range(steps, -1, -1):
			points.append(center + Vector2.from_angle(start + slice * s / steps) * plaza)
		draw_colored_polygon(points, ZONES[i]["color"])
		draw_line(center + Vector2.from_angle(start) * plaza, center + Vector2.from_angle(start) * inner, BORDER_COLOR, 3.0)

	# La place centrale.
	draw_circle(center, plaza, PLAZA["color"])
	draw_arc(center, plaza, 0.0, TAU, 64, BORDER_COLOR, 3.0)


## Place chaque bouton au milieu de son quartier.
func _place_buttons() -> void:
	var center := size / 2.0
	var inner := _outer_radius() - WALL_THICKNESS
	var plaza := inner * PLAZA_RATIO
	var slice := TAU / ZONES.size()

	for i in zone_buttons.size():
		var angle := -PI / 2.0 + slice * (i + 0.5)
		_center_button(zone_buttons[i], center + Vector2.from_angle(angle) * (plaza + inner) / 2.0)
	_center_button(plaza_button, center)
	queue_redraw()


func _center_button(button: Button, point: Vector2) -> void:
	button.reset_size()
	button.position = point - button.size / 2.0


func _outer_radius() -> float:
	return minf(size.x, size.y) / 2.0 - 8.0


func _make_zone_button(zone: Dictionary) -> Button:
	var button := UI.make_button(zone["label"], func(): zone_pressed.emit(zone), 22)
	button.add_theme_constant_override("outline_size", 6)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	var normal := UI.make_panel_style(Color(0, 0, 0, 0.35))
	normal.set_content_margin_all(8)
	var pressed := UI.make_panel_style(Color(1, 1, 1, 0.25))
	pressed.set_content_margin_all(8)
	UI.set_button_style(button, normal, pressed)
	add_child(button)
	return button
