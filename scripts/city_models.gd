class_name CityModels
extends RefCounted
## Les modèles 3D de la cité (hub 3D et aperçus en hologramme du menu Construction), dans un style
## médiéval sombre : pierre, briques, tuiles d'ardoise, colombages, bois, fenêtres éclairées.
## Tout est fait de formes simples (cubes, cylindres, prismes) habillées de textures dessinées par
## le code (briques, pavés, tuiles, planches...), en attendant de vrais modèles.
##
## Chaque bâtiment est construit autour de l'origine, sa porte tournée vers +Z : la cité le pose
## ensuite à sa place et le tourne vers sa rue.
## Avec « holo » à vrai, tout est construit en hologramme cyan (menu Construction, animation de construction).

# --- Couleurs (teintes posées sur les textures en niveaux de gris) ---

const STONE := Color("7c808a")
const DARK_STONE := Color("575b66")
const PALE_STONE := Color("b3b5bd")
const SLATE := Color("3f4756")
const RED_ROOF := Color("6b3029")
const PLASTER := Color("bcae94")
const BEAM := Color("3a291d")
const WOOD := Color("6e4f35")
const WINDOW := Color("ffb45e")
const CYAN := Color("62e3ff")
const HOLO_COLOR := Color(0.4, 0.95, 1.0, 0.42)

## Les mannequins du terrain d'entraînement (décalage par rapport à son centre) : les héros viennent
## s'y entraîner (voir HubCity3D).
const DUMMIES := [Vector2(-2.6, -1.6), Vector2(-0.9, -1.6), Vector2(0.9, -1.6), Vector2(2.6, -1.6),
	Vector2(-2.6, 1.2), Vector2(-0.9, 1.2), Vector2(0.9, 1.2), Vector2(2.6, 1.2)]

## Vrai : tout ce qui est construit est un hologramme cyan.
var holo := false

var _materials := {}
var _holo_material: StandardMaterial3D
## Les textures, dessinées une seule fois pour toute la partie.
static var _textures := {}


# ---------------------------------------------------------------------------
# Les bâtiments
# ---------------------------------------------------------------------------

## Construit le modèle « key » dans « parent » (autour de son origine, porte vers +Z).
func build(key: String, parent: Node3D) -> void:
	match key:
		"combat": _combat_hall(parent)
		"synthese": _synthesis(parent)
		"armory": _armory(parent)
		"forge": _forge(parent)
		"plaza": _plaza(parent)
		"faille": _rift(parent)
		"atelier_magie": _magic_tower(parent)
		"lab": _lab(parent)
		"bibliotheque": _library(parent)
		"summon": _summon_hall(parent)
		"landing": _landing(parent)
		"training": _training(parent, DUMMIES)


## Une maison à colombages : rez-de-chaussée en pierre, étage en torchis et poutres, toit pentu,
## cheminée, fenêtres éclairées. « size » : largeur, hauteur des murs, profondeur.
func house(parent: Node3D, size: Vector3, roof_color: Color, chimney: bool) -> void:
	var low := size.y * 0.45
	add(box(Vector3(size.x, low, size.z)), mat("bricks", DARK_STONE), Vector3(0, low / 2.0, 0), parent)
	var up := size.y - low
	add(box(Vector3(size.x + 0.2, up, size.z + 0.2)), mat("plaster", PLASTER), Vector3(0, low + up / 2.0, 0), parent)
	# Les poutres du colombage : les coins, une traverse et des croix de Saint-André sur la façade.
	for x in [-1, 1]:
		for z in [-1, 1]:
			add(box(Vector3(0.18, up, 0.18)), mat("wood", BEAM),
				Vector3(x * (size.x / 2.0 + 0.1), low + up / 2.0, z * (size.z / 2.0 + 0.1)), parent)
	for z in [-1, 1]:
		add(box(Vector3(size.x + 0.3, 0.16, 0.16)), mat("wood", BEAM), Vector3(0, low + 0.05, z * (size.z / 2.0 + 0.12)), parent)
		add(box(Vector3(size.x + 0.3, 0.16, 0.16)), mat("wood", BEAM), Vector3(0, size.y - 0.05, z * (size.z / 2.0 + 0.12)), parent)
		var brace := add(box(Vector3(0.12, up * 1.2, 0.1)), mat("wood", BEAM), Vector3(-size.x * 0.25, low + up / 2.0, z * (size.z / 2.0 + 0.13)), parent)
		brace.rotation.z = 0.6
	# Les fenêtres éclairées de l'étage et la porte.
	for x in [-size.x * 0.22, size.x * 0.22]:
		add(box(Vector3(0.42, 0.5, 0.06)), glow(WINDOW, 1.4), Vector3(x, low + up * 0.5, size.z / 2.0 + 0.13), parent)
		add(box(Vector3(0.42, 0.5, 0.06)), glow(WINDOW, 1.4), Vector3(x, low + up * 0.5, -size.z / 2.0 - 0.13), parent)
	add(box(Vector3(0.6, 1.0, 0.08)), mat("wood", WOOD), Vector3(0, 0.5, size.z / 2.0 + 0.04), parent)
	# Le toit (débordant) et sa cheminée.
	add(prism(Vector3(size.x + 0.7, size.x * 0.55, size.z + 0.7)), mat("roof", roof_color),
		Vector3(0, size.y + size.x * 0.275, 0), parent)
	if chimney:
		add(box(Vector3(0.45, 1.3, 0.45)), mat("bricks", DARK_STONE), Vector3(size.x * 0.25, size.y + 0.9, -size.z * 0.2), parent)


## La salle de combat : une arène ronde en pierre, contreforts, toit en spirale (cercles en gradins).
func _combat_hall(parent: Node3D) -> void:
	add(cylinder(4.9, 5.1, 0.6, 32), mat("bricks", DARK_STONE), Vector3(0, 0.3, 0), parent)
	add(cylinder(4.1, 4.3, 3.6, 32), mat("bricks", STONE), Vector3(0, 2.4, 0), parent)
	for i in 12:
		var angle := TAU * i / 12
		var buttress := add(box(Vector3(0.6, 3.8, 0.9)), mat("bricks", DARK_STONE),
			Vector3(sin(angle) * 4.35, 2.2, cos(angle) * 4.35), parent)
		buttress.rotation.y = angle
		if i % 2 == 0:  # meurtrières éclairées
			var slit := add(box(Vector3(0.18, 0.8, 0.06)), glow(WINDOW, 1.0),
				Vector3(sin(angle + 0.13) * 4.33, 2.8, cos(angle + 0.13) * 4.33), parent)
			slit.rotation.y = angle + 0.13
	add(cylinder(4.7, 4.7, 0.45, 32), mat("stone", PALE_STONE), Vector3(0, 4.35, 0), parent)
	for i in 4:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.6 + i * 0.95
		ring.outer_radius = 0.95 + i * 0.95
		add(ring, mat("stone", PALE_STONE.lightened(0.1)), Vector3(0, 4.6 + (3 - i) * 0.16, 0), parent)
	add(cylinder(0.45, 0.6, 1.0, 12), mat("stone", PALE_STONE), Vector3(0, 5.3, 0), parent)
	add(sphere(0.3, 10, 5), glow(CYAN, 1.6), Vector3(0, 6.0, 0), parent)
	_arch_door(parent, Vector3(0, 0, 4.25), 1.4, 2.2)
	for x in [-1.5, 1.5]:
		_banner(parent, Vector3(x, 0, 4.5), RED_ROOF)


## La chambre de synthèse : une rotonde à colonnes sur des marches, coiffée d'un dôme, porte lumineuse.
func _synthesis(parent: Node3D) -> void:
	for step in 3:
		add(cylinder(3.5 - step * 0.25, 3.6 - step * 0.25, 0.25, 28), mat("stone", PALE_STONE.darkened(0.06 * step)),
			Vector3(0, 0.125 + step * 0.25, 0), parent)
	add(cylinder(2.1, 2.1, 3.0, 24), mat("bricks", STONE), Vector3(0, 2.25, 0), parent)
	for i in 10:
		var angle := TAU * i / 10
		add(cylinder(0.2, 0.22, 3.0, 8), mat("stone", PALE_STONE), Vector3(sin(angle) * 2.75, 2.25, cos(angle) * 2.75), parent)
	add(cylinder(3.05, 3.05, 0.4, 28), mat("stone", PALE_STONE), Vector3(0, 3.95, 0), parent)
	var dome := sphere(2.5, 18, 9)
	dome.height = 2.8
	add(dome, mat("roof", SLATE.lightened(0.15)), Vector3(0, 4.1, 0), parent)
	add(cylinder(0.05, 0.25, 1.0, 8), mat("stone", PALE_STONE), Vector3(0, 6.0, 0), parent)
	add(box(Vector3(0.95, 1.9, 0.12)), glow(CYAN, 1.8), Vector3(0, 1.7, 2.12), parent)


## L'armurerie : rez-de-chaussée en pierre, étage à colombages, toit d'ardoise, enseigne,
## râtelier d'armes et enclume devant.
func _armory(parent: Node3D) -> void:
	house(parent, Vector3(5.0, 3.6, 3.8), SLATE, true)
	add(box(Vector3(1.0, 0.7, 0.08)), mat("wood", WOOD), Vector3(1.6, 2.0, 2.05), parent)  # l'enseigne
	add(box(Vector3(0.5, 0.25, 0.1)), mat("plain", Color("9aa1aa")), Vector3(1.6, 2.0, 2.1), parent)
	var rack := add(box(Vector3(1.6, 1.1, 0.25)), mat("wood", WOOD), Vector3(-1.4, 0.55, 2.6), parent)
	rack.rotation.y = 0.1
	for x in [-1.9, -1.6, -1.3, -1.0]:
		add(box(Vector3(0.06, 1.3, 0.06)), mat("plain", Color("aab0b8")), Vector3(x, 0.9, 2.75), parent)
	add(box(Vector3(0.8, 0.45, 0.35)), mat("plain", Color("2c2d31")), Vector3(1.2, 0.55, 2.8), parent)
	add(cylinder(0.25, 0.3, 0.35, 8), mat("wood", WOOD), Vector3(1.2, 0.17, 2.8), parent)


## La forge : un atelier de pierre ouvert sur l'avant, le feu qui rougeoie, une grosse cheminée.
func _forge(parent: Node3D) -> void:
	add(box(Vector3(3.2, 2.4, 3.0)), mat("bricks", DARK_STONE), Vector3(0, 1.2, -0.2), parent)
	add(prism(Vector3(3.8, 1.3, 3.6)), mat("roof", RED_ROOF), Vector3(0, 3.05, -0.2), parent)
	add(box(Vector3(1.0, 3.2, 1.0)), mat("bricks", DARK_STONE), Vector3(-0.9, 3.0, -0.8), parent)
	add(box(Vector3(0.6, 0.15, 0.6)), glow(Color("ff7a26"), 2.0), Vector3(-0.9, 4.65, -0.8), parent)
	add(box(Vector3(1.6, 1.2, 0.1)), glow(Color("ff7a26"), 1.6), Vector3(0, 0.8, 1.32), parent)  # le feu
	add(box(Vector3(0.8, 0.45, 0.35)), mat("plain", Color("2c2d31")), Vector3(1.1, 0.5, 2.0), parent)
	add(cylinder(0.35, 0.35, 0.8, 10), mat("wood", WOOD), Vector3(-1.2, 0.4, 2.0), parent)


## La place publique : un pavage en roue, la fontaine, la vieille stèle aux runes, des bancs.
func _plaza(parent: Node3D) -> void:
	add(cylinder(6.0, 6.0, 0.08, 48), mat("cobbles", Color("9d9488")), Vector3(0, 0.04, 0), parent)
	for i in 12:
		var angle := TAU * i / 12
		var spoke := add(box(Vector3(0.3, 0.1, 4.0)), mat("stone", PALE_STONE), Vector3(sin(angle) * 3.9, 0.06, cos(angle) * 3.9), parent)
		spoke.rotation.y = angle
	for radius in [2.6, 5.8]:
		var rim := TorusMesh.new()
		rim.inner_radius = radius - 0.2
		rim.outer_radius = radius + 0.2
		add(rim, mat("stone", PALE_STONE), Vector3(0, 0.05, 0), parent)
	add(cylinder(2.0, 2.15, 0.6, 28), mat("bricks", PALE_STONE), Vector3(0, 0.3, 0), parent)
	add(cylinder(1.85, 1.85, 0.1, 28), glow(Color("2f8fb8"), 0.5), Vector3(0, 0.58, 0), parent)
	add(cylinder(0.8, 0.95, 0.9, 16), mat("stone", PALE_STONE), Vector3(0, 1.0, 0), parent)
	add(cylinder(0.25, 0.4, 1.6, 12), mat("stone", PALE_STONE), Vector3(0, 2.2, 0), parent)
	add(sphere(0.4, 12, 6), glow(Color("bfefff"), 1.2), Vector3(0, 3.1, 0), parent)
	# La stèle des mots de passe, couverte de runes.
	add(box(Vector3(0.8, 2.4, 0.4)), mat("stone", DARK_STONE), Vector3(0, 1.2, 4.6), parent)
	add(box(Vector3(0.5, 1.6, 0.05)), glow(CYAN, 1.0), Vector3(0, 1.3, 4.82), parent)
	for angle in [0.9, 2.3, 3.9, 5.3]:
		var bench := add(box(Vector3(1.6, 0.45, 0.5)), mat("wood", WOOD), Vector3(sin(angle) * 4.7, 0.22, cos(angle) * 4.7), parent)
		bench.rotation.y = angle


## La faille spatio-temporelle : une immense arche de pierre envahie de racines, et un passage
## violet qui palpite (« portal » : renvoie son matériau pour l'animer).
func _rift(parent: Node3D) -> void:
	for x in [-2.7, 2.7]:
		add(box(Vector3(1.5, 6.8, 2.0)), mat("bricks", DARK_STONE), Vector3(x, 3.4, 0), parent)
		add(box(Vector3(1.9, 0.6, 2.4)), mat("stone", STONE), Vector3(x, 0.3, 0), parent)
	var top := TorusMesh.new()
	top.inner_radius = 2.1
	top.outer_radius = 3.4
	var ring := add(top, mat("bricks", DARK_STONE), Vector3(0, 6.4, 0), parent)
	ring.rotation.x = PI / 2.0
	var portal := add(cylinder(2.3, 2.3, 0.15, 28), glow(Color("8f5cff"), 1.2), Vector3(0, 3.8, 0), parent)
	portal.rotation.x = PI / 2.0
	portal.scale = Vector3(1.0, 1.0, 1.55)
	portal.name = "Portal"
	for root_spot in [Vector3(-3.4, 1.4, 0.8), Vector3(-3.1, 1.0, -0.7), Vector3(3.4, 1.5, 0.7),
			Vector3(3.2, 0.9, -0.8), Vector3(-1.2, 8.6, 0.4), Vector3(1.5, 8.4, -0.3)]:
		var root := add(cylinder(0.12, 0.38, 3.4, 6), mat("wood", Color("3b2a20")), root_spot, parent)
		root.rotation.z = 0.55 if root_spot.x < 0 else -0.55
	for crown in [Vector3(-3.4, 7.4, 0), Vector3(3.6, 7.6, 0)]:
		add(sphere(1.3, 8, 5), mat("plain", Color("26402c")), crown, parent)


## L'atelier de magie : une tour de pierre au toit pointu, fenêtres violettes, cristal flottant.
func _magic_tower(parent: Node3D) -> void:
	add(cylinder(2.0, 2.2, 0.5, 16), mat("stone", STONE), Vector3(0, 0.25, 0), parent)
	add(cylinder(1.7, 1.9, 5.4, 16), mat("bricks", STONE), Vector3(0, 3.2, 0), parent)
	add(cylinder(2.0, 2.0, 0.35, 16), mat("stone", PALE_STONE), Vector3(0, 6.0, 0), parent)
	add(cylinder(0.0, 2.2, 3.2, 16), mat("roof", Color("3b2f55")), Vector3(0, 7.75, 0), parent)
	for i in 4:
		var angle := TAU * i / 4 + 0.4
		var window := add(box(Vector3(0.35, 0.7, 0.06)), glow(Color("b98bff"), 1.4),
			Vector3(sin(angle) * 1.82, 2.6 + i * 0.8, cos(angle) * 1.82), parent)
		window.rotation.y = angle
	add(sphere(0.45, 6, 3), glow(Color("c9a2ff"), 2.0), Vector3(0, 10.0, 0), parent)
	_arch_door(parent, Vector3(0, 0, 1.85), 0.9, 1.6)


## Le laboratoire d'alchimie : un socle à colonnes et une grande sphère de verre bleu posée dessus.
func _lab(parent: Node3D) -> void:
	add(cylinder(3.4, 3.6, 0.7, 28), mat("bricks", PALE_STONE), Vector3(0, 0.35, 0), parent)
	add(cylinder(2.2, 2.2, 3.0, 20), mat("bricks", STONE), Vector3(0, 2.2, 0), parent)
	for i in 8:
		var angle := TAU * i / 8
		add(cylinder(0.22, 0.24, 3.0, 8), mat("stone", PALE_STONE), Vector3(sin(angle) * 3.0, 2.2, cos(angle) * 3.0), parent)
	add(cylinder(3.25, 3.25, 0.35, 28), mat("stone", PALE_STONE), Vector3(0, 3.85, 0), parent)
	add(cylinder(1.6, 2.4, 0.6, 24), mat("stone", STONE), Vector3(0, 4.3, 0), parent)
	add(sphere(2.0, 20, 10), glow(Color("2f62b0"), 0.9), Vector3(0, 6.3, 0), parent)
	var runes := TorusMesh.new()
	runes.inner_radius = 2.15
	runes.outer_radius = 2.3
	add(runes, glow(CYAN, 1.4), Vector3(0, 6.3, 0), parent)
	_arch_door(parent, Vector3(0, 0.7, 2.25), 1.0, 1.7)


## La bibliothèque : une grande salle gothique, hautes fenêtres éclairées, toit raide, flèche.
func _library(parent: Node3D) -> void:
	add(box(Vector3(5.0, 3.4, 3.6)), mat("bricks", STONE), Vector3(0, 1.7, 0), parent)
	add(prism(Vector3(5.4, 2.4, 4.0)), mat("roof", SLATE), Vector3(0, 4.6, 0), parent)
	for x in [-1.7, -0.6, 0.6, 1.7]:
		add(box(Vector3(0.4, 1.6, 0.06)), glow(WINDOW, 1.2), Vector3(x, 1.9, 1.83), parent)
		add(box(Vector3(0.4, 1.6, 0.06)), glow(WINDOW, 1.2), Vector3(x, 1.9, -1.83), parent)
	add(box(Vector3(0.9, 1.6, 0.9)), mat("bricks", STONE), Vector3(1.8, 5.2, 0), parent)
	add(cylinder(0.0, 0.7, 2.0, 4), mat("roof", SLATE), Vector3(1.8, 7.0, 0), parent)
	_arch_door(parent, Vector3(0, 0, 1.82), 1.1, 1.9)


## La salle d'invocation : un temple sur des marches, colonnade, fronton, braseros, cercle qui brille.
func _summon_hall(parent: Node3D) -> void:
	for step in 3:
		add(box(Vector3(6.4 - step * 0.6, 0.3, 5.2 - step * 0.6)), mat("stone", PALE_STONE.darkened(0.05 * step)),
			Vector3(0, 0.15 + 0.3 * step, 0), parent)
	add(box(Vector3(4.4, 3.2, 2.6)), mat("bricks", PALE_STONE), Vector3(0, 2.5, -0.7), parent)
	for x in [-1.8, -0.6, 0.6, 1.8]:
		add(cylinder(0.2, 0.22, 3.0, 10), mat("stone", PALE_STONE.lightened(0.1)), Vector3(x, 2.4, 1.2), parent)
	add(box(Vector3(4.9, 0.35, 3.8)), mat("stone", PALE_STONE), Vector3(0, 4.05, 0.1), parent)
	add(prism(Vector3(4.9, 1.1, 3.8)), mat("roof", SLATE), Vector3(0, 4.75, 0.1), parent)
	add(cylinder(0.85, 0.85, 0.04, 24), glow(CYAN, 1.8), Vector3(0, 0.95, 0.4), parent)
	for x in [-2.6, 2.6]:  # les braseros
		add(cylinder(0.3, 0.15, 0.9, 8), mat("plain", Color("2c2d31")), Vector3(x, 1.35, 1.9), parent)
		add(sphere(0.25, 6, 3), glow(Color("ff9a3a"), 2.2), Vector3(x, 1.9, 1.9), parent)


## La zone de débarquement : un dallage sombre, un cercle de téléportation et ses runes.
func _landing(parent: Node3D) -> void:
	add(box(Vector3(7.0, 0.08, 5.2)), mat("cobbles", Color("6a4a46")), Vector3(0, 0.04, 0), parent)
	for radius in [1.6, 2.2]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius - 0.1
		ring.outer_radius = radius + 0.08
		add(ring, glow(CYAN, 1.5), Vector3(0, 0.1, 0), parent)
	add(cylinder(1.5, 1.5, 0.03, 24), glow(Color("1d4a5c"), 0.6), Vector3(0, 0.09, 0), parent)
	for corner in [Vector3(-3.2, 0, -2.3), Vector3(3.2, 0, -2.3), Vector3(-3.2, 0, 2.3), Vector3(3.2, 0, 2.3)]:
		add(box(Vector3(0.4, 1.4, 0.4)), mat("bricks", DARK_STONE), corner + Vector3(0, 0.7, 0), parent)
		add(sphere(0.18, 6, 3), glow(CYAN, 1.6), corner + Vector3(0, 1.55, 0), parent)


## Le terrain d'entraînement : du sable, des mannequins, une cible, un râtelier, une palissade.
## « dummies » : la place des mannequins (les héros viennent s'y entraîner).
func _training(parent: Node3D, dummies: Array = []) -> void:
	add(cylinder(4.8, 4.8, 0.08, 36), mat("sand", Color("a89272")), Vector3(0, 0.04, 0), parent)
	for spot in dummies:
		var at := Vector3(spot.x, 0, spot.y)
		add(cylinder(0.11, 0.14, 1.6, 6), mat("wood", WOOD), at + Vector3(0, 0.8, 0), parent)
		add(box(Vector3(1.0, 0.12, 0.12)), mat("wood", WOOD), at + Vector3(0, 1.2, 0), parent)
		add(sphere(0.22, 8, 4), mat("plain", Color("8f7a58")), at + Vector3(0, 1.75, 0), parent)
	var target := add(cylinder(0.7, 0.7, 0.12, 16), mat("plain", Color("b8a888")), Vector3(3.6, 1.2, -2.2), parent)
	target.rotation.x = PI / 2.0
	var bullseye := add(cylinder(0.35, 0.35, 0.14, 16), mat("plain", RED_ROOF), Vector3(3.6, 1.2, -2.13), parent)
	bullseye.rotation.x = PI / 2.0
	add(box(Vector3(2.0, 1.2, 0.3)), mat("wood", WOOD), Vector3(-1.0, 0.6, 3.7), parent)
	for barrel in [Vector3(3.4, 0, 2.6), Vector3(3.0, 0, 3.3)]:
		add(cylinder(0.4, 0.4, 0.9, 10), mat("wood", WOOD), barrel + Vector3(0, 0.45, 0), parent)
	for i in 28:  # la palissade, ouverte du côté de la rue
		var angle := TAU * i / 28
		if absf(angle - PI / 2.0) < 0.4:
			continue
		add(cylinder(0.09, 0.09, 1.0, 5), mat("wood", WOOD), Vector3(cos(angle) * 4.85, 0.5, sin(angle) * 4.85), parent)


## Une porte en arc, sombre, avec un peu de lumière derrière.
func _arch_door(parent: Node3D, at: Vector3, width: float, height: float) -> void:
	add(box(Vector3(width + 0.3, height + 0.2, 0.2)), mat("stone", PALE_STONE), at + Vector3(0, (height + 0.2) / 2.0, 0), parent)
	add(box(Vector3(width, height, 0.24)), glow(WINDOW.darkened(0.35), 0.8), at + Vector3(0, height / 2.0, 0.02), parent)


## Une bannière sur un mât.
func _banner(parent: Node3D, at: Vector3, color: Color) -> void:
	add(cylinder(0.05, 0.05, 3.2, 6), mat("wood", BEAM), at + Vector3(0, 1.6, 0), parent)
	add(box(Vector3(0.7, 1.3, 0.04)), mat("plain", color), at + Vector3(0.37, 2.5, 0), parent)


# ---------------------------------------------------------------------------
# Formes
# ---------------------------------------------------------------------------

func add(mesh: Mesh, material: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = _holo() if holo else material
	parent.add_child(node)
	return node


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func prism(size: Vector3) -> PrismMesh:
	var mesh := PrismMesh.new()
	mesh.size = size
	return mesh


static func cylinder(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


static func sphere(radius: float, segments := 16, rings := 8) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


# ---------------------------------------------------------------------------
# Matériaux et textures
# ---------------------------------------------------------------------------

## Un matériau : « kind » = la texture ("plain", "stone", "bricks", "cobbles", "roof", "wood",
## "plaster", "sand", "rock", "grass"), « color » = sa teinte.
func mat(kind: String, color: Color) -> Material:
	var key := "%s|%s" % [kind, color.to_html()]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	if kind != "plain":
		material.albedo_texture = texture(kind)
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * TEXTURE_SCALES.get(kind, 0.5)
	_materials[key] = material
	return material


## Un matériau qui brille (fenêtres, feu, runes, cristaux). « energy » : la force de la lueur.
func glow(color: Color, energy: float) -> Material:
	var key := "glow|%s|%s" % [color.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_materials[key] = material
	return material


## L'hologramme : cyan, transparent, qui brille (animation de construction, menu Construction).
func _holo() -> StandardMaterial3D:
	if _holo_material == null:
		_holo_material = StandardMaterial3D.new()
		_holo_material.albedo_color = HOLO_COLOR
		_holo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_holo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_holo_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_holo_material.emission_enabled = true
		_holo_material.emission = Color(HOLO_COLOR, 1.0)
		_holo_material.emission_energy_multiplier = 1.3
	return _holo_material


func holo_material() -> StandardMaterial3D:
	return _holo()


## Combien de fois la texture se répète par mètre.
const TEXTURE_SCALES := {"stone": 0.35, "bricks": 0.55, "cobbles": 0.3, "roof": 0.7, "wood": 0.6,
	"plaster": 0.4, "sand": 0.25, "rock": 0.12, "grass": 0.2}


## Une texture en niveaux de gris (teintée ensuite par le matériau), dessinée pixel par pixel.
static func texture(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	# Deux bruits qui se raccordent sur les bords (pas de couture quand la texture se répète) :
	# le grain de la matière, et des cellules (les pavés, les veines de la roche).
	var noise := FastNoiseLite.new()
	noise.seed = kind.hash()
	noise.frequency = 0.05
	var grain_image := noise.get_seamless_image(size, size)
	var cells := FastNoiseLite.new()
	cells.seed = kind.hash() + 1
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cells.frequency = 0.07
	var cell_image := cells.get_seamless_image(size, size)
	for y in size:
		for x in size:
			var grain := (grain_image.get_pixel(x, y).r - 0.5) * 0.2
			var cell := cell_image.get_pixel(x, y).r
			image.set_pixel(x, y, Color.from_hsv(0, 0, clampf(_texel(kind, x, y, grain, cell), 0.0, 1.0)))
	image.generate_mipmaps()
	var result := ImageTexture.create_from_image(image)
	_textures[kind] = result
	return result


## La clarté d'un pixel de texture (0 = noir, 1 = blanc), selon son motif.
## « grain » : le grain de la matière (-0.1 à 0.1) ; « cell » : le bruit cellulaire (0 à 1).
static func _texel(kind: String, x: int, y: int, grain: float, cell: float) -> float:
	match kind:
		"bricks", "stone":
			# Des pierres taillées en rangées décalées, séparées par du mortier sombre.
			var row_height := 16 if kind == "bricks" else 32
			var brick_width := 32 if kind == "bricks" else 64
			var row := y / row_height
			var shifted := (x + (brick_width / 2 if row % 2 == 1 else 0)) % 128
			var column := shifted / brick_width
			if y % row_height < 2 or shifted % brick_width < 2:
				return 0.32 + grain
			var shade := 0.7 + (absi(hash(Vector2i(column, row))) % 100) / 100.0 * 0.24
			return shade + grain * 1.5 - cell * 0.08
		"cobbles":
			# Des pavés ronds : le bruit cellulaire dessine les pierres et leurs joints sombres.
			return 0.4 + smoothstep(0.05, 0.35, cell) * 0.45 + grain
		"roof":
			# Des tuiles (ou ardoises) en écailles : plus sombres en bas de chaque rangée.
			var row_height := 8
			var row := y / row_height
			var tile := (x + (8 if row % 2 == 1 else 0)) % 16
			var depth := float(y % row_height) / row_height
			return 0.88 - depth * 0.38 - (0.3 if tile < 1 else 0.0) + grain
		"wood":
			# Des planches verticales avec leurs veines.
			if x % 16 < 1:
				return 0.28
			return 0.7 + sin(y * 0.3 + grain * 40.0) * 0.07 + grain
		"plaster":
			return 0.86 + grain * 1.3
		"rock":
			return 0.45 + cell * 0.35 + grain * 2.0
	return 0.8 + grain * 2.0
