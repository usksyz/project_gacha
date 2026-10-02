class_name HubCity3D
extends SubViewportContainer
## Le hub en 3D (nouveaux visuels ; les anciens gardent le plan HubMap) : la cité circulaire vue
## du dessus, d'après le plan du manhwa (rempart à pans, résidences, terrain d'entraînement, place
## publique, salle de combat, laboratoire...). Les bâtiments pas encore construits apparaissent en
## hologramme cyan, comme les constructions du Système dans le manhwa.
##
## Les héros y vivent : ils marchent jusqu'au terrain d'entraînement s'ils s'entraînent, jusqu'à leur
## bâtiment s'ils y sont assistants, et se promènent sinon (place publique, résidences...).
## Ceux qui partent (Tour, donjon journalier) disparaissent dans la faille ; ceux qui reviennent
## arrivent par la zone de débarquement ; les nouveaux sortent de la salle d'invocation.
##
## Un doigt : déplacer la vue. Deux doigts (ou la molette) : zoomer. Toucher : un lieu ou un héros.
## Tout est fait de formes simples (cubes, cylindres...) en attendant de vrais modèles.

signal zone_pressed(zone: Dictionary)
signal hero_pressed(hero: Dictionary)

# --- La cité (en mètres ; x vers la droite, z vers le bas de l'écran) ---

## Rayon du rempart et nombre de pans.
const CITY_RADIUS := 24.0
const WALL_SIDES := 16
## Le carrefour au centre de la cité : les chemins des héros y passent.
const CENTER := Vector3.ZERO

## Les lieux : position, rayon (pour les toucher) et nom (celui des quartiers de HubMap).
## « short » : nom affiché sur la cité ; « height » : hauteur où il s'affiche.
## « open » : un espace à ciel ouvert où les héros entrent (sinon ils s'arrêtent devant la porte).
const PLACES := {
	"combat": {"name": "Salle de combat", "short": "Salle de combat", "pos": Vector2(0, -15), "radius": 4.5, "height": 4.0},
	"synthese": {"name": "Chambre de synthèse", "short": "Synthèse", "pos": Vector2(-9, -13), "radius": 3.5, "height": 5.5},
	"armory": {"name": "Armurerie", "short": "Armurerie", "pos": Vector2(9, -14), "radius": 3.5, "height": 4.6},
	"forge": {"name": "Forge", "short": "Forge", "pos": Vector2(14.5, -12), "radius": 2.2, "height": 3.4},
	"plaza": {"name": "Place publique", "short": "Place publique", "pos": Vector2(8, -4), "radius": 5.0, "height": 3.0, "open": true},
	"atelier_magie": {"name": "Atelier de magie", "short": "Atelier\nde magie", "pos": Vector2(17, -4), "radius": 2.5, "height": 7.5},
	"lab": {"name": "Laboratoire d'alchimie", "short": "Laboratoire", "pos": Vector2(16, 5), "radius": 3.5, "height": 5.0},
	"bibliotheque": {"name": "Bibliothèque", "short": "Bibliothèque", "pos": Vector2(12, 12), "radius": 3.0, "height": 4.5},
	"summon": {"name": "Salle d'invocation", "short": "Invocation", "pos": Vector2(4, 16), "radius": 3.5, "height": 4.3},
	"landing": {"name": "Zone de débarquement", "short": "Débarquement", "pos": Vector2(-4, 17), "radius": 3.5, "height": 0.5, "open": true},
	"faille": {"name": "Faille spatio-temporelle", "short": "Faille", "pos": Vector2(-12, 17), "radius": 2.5, "height": 4.8},
	"training": {"name": "Terrain d'entraînement", "short": "Entraînement", "pos": Vector2(-12, 6), "radius": 5.0, "height": 1.0, "open": true},
	"residences": {"name": "Résidences", "short": "Résidences", "pos": Vector2(-14, -5), "radius": 5.5, "height": 3.0, "open": true},
}
## Bâtiment de chaque poste d'assistant (hero["post"]) : la forge est l'annexe de l'armurerie.
const POST_PLACES := {"synthese": "synthese", "forge": "forge", "atelier_magie": "atelier_magie",
	"laboratoire": "lab", "bibliotheque": "bibliotheque"}
## Lieux où les héros sans occupation vont se promener (la place revient plus souvent).
const IDLE_PLACES := ["plaza", "plaza", "residences", "residences", "center"]

## Les mannequins du terrain d'entraînement (décalage par rapport au centre du terrain).
const DUMMIES := [Vector2(-3, -2), Vector2(-1, -2), Vector2(1, -2), Vector2(3, -2),
	Vector2(-3, 1), Vector2(-1, 1), Vector2(1, 1), Vector2(3, 1)]
## Les maisons des résidences (décalage par rapport au centre du quartier) ; la première, rouge, est
## celle du Maître (comme sur le plan du manhwa).
const HOUSES := [Vector2(1.5, 1), Vector2(-2, -3), Vector2(2, -3.5), Vector2(-3.5, 1.5),
	Vector2(-1, 4.5), Vector2(3, 4), Vector2(-5, -1.5), Vector2(5, 0)]

# --- Couleurs ---

const GROUND_COLOR := Color("4f5866")
const OUTSIDE_COLOR := Color("21302a")
const ROAD_COLOR := Color("a88f84")
const WALL_COLOR := Color("8a877c")
const STONE_COLOR := Color("c3c4cc")
const HOLO_COLOR := Color(0.35, 0.95, 1.0, 0.28)

# --- Héros ---

## Au plus ce nombre de héros dans la cité (pour que le téléphone suive).
const MAX_WALKERS := 60
const WALK_SPEED := 2.6
const BODY_Y := 0.75
## Les noms des héros ne s'affichent que si la caméra est assez près.
const NAME_DISTANCE := 34.0

# --- Caméra ---

const PITCH := deg_to_rad(64.0)
const MIN_DISTANCE := 14.0
const MAX_DISTANCE := 62.0
## Un appui qui bouge de plus de ça (pixels) devient un glissement, pas un toucher.
const TAP_THRESHOLD := 12.0
## Les héros sont mis à jour (activités, arrivées, départs) à cet intervalle (secondes).
const REFRESH_SECONDS := 1.5

var viewport: SubViewport
var camera: Camera3D
var city_root: Node3D
var walkers_root: Node3D

var cam_target := Vector3(0, 0, 1)
var cam_distance := 50.0

## Héros en promenade : {"hero", "node", "body", "label", "path": [Vector3], "state", "activity",
## "area", "wait", "phase", "spot"}.
var walkers: Array[Dictionary] = []
## Numéros des héros déjà vus : un héros inconnu vient d'être invoqué (il sort de la salle d'invocation).
var known_ids := {}
var first_refresh := true
var refresh_timer := 0.0
## Ce qui décide de l'allure de la cité (bâtiments construits...) : on la reconstruit quand ça change.
var city_signature := ""

## Les noms affichés par-dessus la 3D, et ceux des lieux : [Label, point de la cité].
var overlay: Control
var place_labels: Array = []

var materials := {}
## Les morceaux en hologramme sont construits avec ce matériau (bâtiment pas encore là).
var holo := false
var portal_material: StandardMaterial3D

# Toucher
var pressing := false
var press_pos := Vector2.ZERO
var moved := false
var touches := {}
var pinch_distance := 0.0


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b1820")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9cc3d6")
	environment.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.1
	viewport.add_child(sun)

	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH  # toute la largeur de la cité tient dans l'écran
	camera.fov = 52.0
	viewport.add_child(camera)

	city_root = Node3D.new()
	viewport.add_child(city_root)
	walkers_root = Node3D.new()
	viewport.add_child(walkers_root)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(overlay)
	_update_camera()


func _ready() -> void:
	_rebuild_city_if_needed()
	_refresh_walkers()
	GameData.lobby_updated.connect(_refresh_walkers)
	GameData.training_updated.connect(_refresh_walkers)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	refresh_timer += delta
	if refresh_timer >= REFRESH_SECONDS:
		refresh_timer = 0.0
		_rebuild_city_if_needed()
		_refresh_walkers()
	for walker in walkers.duplicate():
		_animate_walker(walker, delta)
	if portal_material:
		var glow := 1.2 + sin(Time.get_ticks_msec() / 400.0) * 0.5
		portal_material.emission_energy_multiplier = glow
	_place_labels()


# ---------------------------------------------------------------------------
# La cité
# ---------------------------------------------------------------------------

func _rebuild_city_if_needed() -> void:
	var built: Array = GameData.buildings.duplicate()
	built.sort()
	var signature := "%s|%s" % [",".join(built), GameData.training_unlocked()]
	if signature == city_signature:
		return
	city_signature = signature
	for child in city_root.get_children():
		child.queue_free()
	for entry in place_labels:
		entry[0].queue_free()
	place_labels.clear()
	portal_material = null
	_build_city()


func _build_city() -> void:
	holo = false
	# Le sol : la forêt autour, puis le dallage de la cité.
	var outside := PlaneMesh.new()
	outside.size = Vector2(200, 200)
	_add(outside, OUTSIDE_COLOR, Vector3(0, -0.15, 0))
	_add(_cylinder(CITY_RADIUS, CITY_RADIUS, 0.3, 48), GROUND_COLOR, Vector3(0, -0.15, 0))
	_build_trees()
	_build_wall()

	# Les chemins : du carrefour central jusqu'à chaque lieu.
	_add(_cylinder(2.5, 2.5, 0.06, 24), ROAD_COLOR, Vector3(0, 0.02, 0))
	for key in PLACES:
		_build_road(CENTER, _door(key))

	_build_residences()
	_build_training()
	_build_plaza()
	_build_combat_hall()
	_build_synthesis()
	_build_armory()
	_build_lab()
	_build_magic_workshop()
	_build_library()
	_build_summon_hall()
	_build_landing()
	_build_rift()
	holo = false

	# Le nom de chaque lieu, au-dessus.
	for key in PLACES:
		var place: Dictionary = PLACES[key]
		var label := _make_label(place.get("short", place["name"]), 17, Color.WHITE)
		place_labels.append([label, _pos3(key) + Vector3(0, place.get("height", 3.5), 0)])


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # toujours la même forêt
	for i in 90:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(CITY_RADIUS + 3.0, CITY_RADIUS + 26.0)
		var spot := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var height := rng.randf_range(3.0, 6.0)
		_add(_cylinder(0.0, height * 0.35, height, 7), Color("27462f").lightened(rng.randf() * 0.15),
			spot + Vector3(0, height / 2.0 + 0.6, 0))
		_add(_cylinder(0.25, 0.25, 1.2, 6), Color("4a3726"), spot + Vector3(0, 0.6, 0))


## Le rempart à pans, avec une tour à chaque coin (comme le plan du manhwa).
func _build_wall() -> void:
	var side := 2.0 * CITY_RADIUS * sin(PI / WALL_SIDES)
	for i in WALL_SIDES:
		var a := TAU * i / WALL_SIDES
		var b := TAU * (i + 1) / WALL_SIDES
		var mid := (Vector3(cos(a), 0, sin(a)) + Vector3(cos(b), 0, sin(b))) * 0.5 * CITY_RADIUS
		var segment := _add(_box(Vector3(side + 0.3, 3.2, 1.2)), WALL_COLOR, mid + Vector3(0, 1.6, 0))
		segment.rotation.y = -(a + b) / 2.0 + PI / 2.0
		var corner := Vector3(cos(a), 0, sin(a)) * CITY_RADIUS
		_add(_cylinder(1.3, 1.5, 4.2, 10), WALL_COLOR.lightened(0.1), corner + Vector3(0, 2.1, 0))
		_add(_cylinder(1.5, 1.5, 0.4, 10), Color("4f6b4a"), corner + Vector3(0, 4.3, 0))  # mousse


func _build_road(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var road := _add(_box(Vector3(2.2, 0.05, length)), ROAD_COLOR, (from + to) / 2.0 + Vector3(0, 0.02, 0))
	road.rotation.y = atan2(to.x - from.x, to.z - from.z)


func _build_residences() -> void:
	var center := _pos3("residences")
	_add(_cylinder(6.0, 6.0, 0.05, 32), Color("6b3644"), center + Vector3(0, 0.01, 0))
	for i in HOUSES.size():
		var spot := center + Vector3(HOUSES[i].x, 0, HOUSES[i].y)
		var roof_color := Color("c0392b") if i == 0 else Color("5e3a3a")
		_add(_box(Vector3(2.4, 1.8, 2.2)), Color("9c8d7e"), spot + Vector3(0, 0.9, 0))
		var roof := PrismMesh.new()
		roof.size = Vector3(2.7, 1.1, 2.5)
		_add(roof, roof_color, spot + Vector3(0, 2.35, 0))


func _build_training() -> void:
	var center := _pos3("training")
	holo = not GameData.training_unlocked()  # pas encore ouvert : en hologramme
	_add(_box(Vector3(10, 0.05, 8)), Color("9a8866"), center + Vector3(0, 0.02, 0))
	for dummy in DUMMIES:
		var spot := center + Vector3(dummy.x, 0, dummy.y)
		_add(_cylinder(0.15, 0.18, 1.7, 8), Color("5a4630"), spot + Vector3(0, 0.85, 0))
		_add(_box(Vector3(1.1, 0.14, 0.14)), Color("5a4630"), spot + Vector3(0, 1.25, 0))
	for barrel in [Vector3(4.2, 0, 3.2), Vector3(4.2, 0, 2.4)]:
		_add(_cylinder(0.4, 0.4, 0.9, 10), Color("6e4e2e"), center + barrel + Vector3(0, 0.45, 0))
	holo = false


func _build_plaza() -> void:
	var center := _pos3("plaza")
	_add(_cylinder(5.0, 5.0, 0.05, 40), Color("a8945c"), center + Vector3(0, 0.02, 0))
	# La fontaine (et la vieille stèle des mots de passe).
	_add(_cylinder(2.0, 2.1, 0.5, 24), STONE_COLOR, center + Vector3(0, 0.25, 0))
	_add(_cylinder(1.8, 1.8, 0.1, 24), Color("4aa3c9"), center + Vector3(0, 0.5, 0))
	_add(_cylinder(0.9, 1.0, 0.8, 16), STONE_COLOR, center + Vector3(0, 0.9, 0))
	_add(_cylinder(0.35, 0.45, 1.6, 12), STONE_COLOR, center + Vector3(0, 1.6, 0))
	_add(_sphere(0.4), STONE_COLOR.lightened(0.2), center + Vector3(0, 2.5, 0))
	for angle in [0.4, 2.5, 4.6]:
		var bench := _add(_box(Vector3(1.6, 0.4, 0.5)), Color("6e5a44"),
			center + Vector3(cos(angle), 0, sin(angle)) * 3.8 + Vector3(0, 0.2, 0))
		bench.rotation.y = -angle + PI / 2.0


## La salle de combat : ronde, le toit marqué d'une spirale (cercles).
func _build_combat_hall() -> void:
	var center := _pos3("combat")
	_add(_cylinder(4.0, 4.2, 3.2, 28), Color("5f7488"), center + Vector3(0, 1.6, 0))
	_add(_cylinder(4.5, 4.5, 0.4, 28), Color("8aa3b8"), center + Vector3(0, 3.4, 0))
	for i in 3:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.8 + i * 1.1
		ring.outer_radius = 1.1 + i * 1.1
		_add(ring, Color("c9e3f2"), center + Vector3(0, 3.65, 0))


## La chambre de synthèse : une rotonde à colonnes, coiffée d'un dôme.
func _build_synthesis() -> void:
	var center := _pos3("synthese")
	holo = not "synthese" in GameData.buildings
	_add(_cylinder(3.2, 3.4, 0.5, 24), STONE_COLOR, center + Vector3(0, 0.25, 0))
	_add(_cylinder(2.1, 2.1, 3.0, 20), STONE_COLOR.darkened(0.15), center + Vector3(0, 2.0, 0))
	for i in 8:
		var angle := TAU * i / 8
		_add(_cylinder(0.22, 0.22, 3.0, 8), STONE_COLOR, center + Vector3(cos(angle) * 2.7, 2.0, sin(angle) * 2.7))
	_add(_cylinder(3.1, 3.1, 0.4, 24), STONE_COLOR, center + Vector3(0, 3.7, 0))
	var dome := _sphere(2.4)
	dome.height = 2.4
	_add(dome, STONE_COLOR.lightened(0.1), center + Vector3(0, 3.9, 0))
	holo = false


## L'armurerie (atelier en bois et pierre) et son annexe, la forge.
func _build_armory() -> void:
	var center := _pos3("armory")
	_add(_box(Vector3(5.5, 2.8, 4.0)), Color("8c7a66"), center + Vector3(0, 1.4, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(6.0, 1.6, 4.4)
	_add(roof, Color("7a4a32"), center + Vector3(0, 3.6, 0))
	_add(_box(Vector3(0.7, 1.6, 0.7)), Color("6b6b6b"), center + Vector3(1.8, 4.0, 0.8))

	var forge := _pos3("forge")
	holo = not "forge" in GameData.buildings
	_add(_box(Vector3(3.0, 2.2, 3.0)), Color("6f6359"), forge + Vector3(0, 1.1, 0))
	var forge_roof := PrismMesh.new()
	forge_roof.size = Vector3(3.3, 1.0, 3.3)
	_add(forge_roof, Color("5a3a2a"), forge + Vector3(0, 2.7, 0))
	_add(_box(Vector3(0.6, 1.8, 0.6)), Color("555555"), forge + Vector3(-0.8, 3.0, 0.6))
	if not holo:  # le feu de la forge
		_add(_sphere(0.35), Color("ff8a2a"), forge + Vector3(0, 0.6, 1.55), true)
	holo = false


## Le laboratoire d'alchimie : un socle à colonnes et une grande sphère bleue.
func _build_lab() -> void:
	var center := _pos3("lab")
	holo = not "laboratoire" in GameData.buildings
	_add(_cylinder(3.2, 3.5, 0.7, 24), STONE_COLOR, center + Vector3(0, 0.35, 0))
	for i in 6:
		var angle := TAU * i / 6
		_add(_cylinder(0.2, 0.2, 2.6, 8), STONE_COLOR, center + Vector3(cos(angle) * 2.8, 2.0, sin(angle) * 2.8))
	_add(_sphere(2.0), Color("3f7fd0"), center + Vector3(0, 2.8, 0), true)
	holo = false


## L'atelier de magie : une tour violette au toit pointu.
func _build_magic_workshop() -> void:
	var center := _pos3("atelier_magie")
	holo = not "atelier_magie" in GameData.buildings
	_add(_cylinder(1.8, 2.0, 5.0, 16), Color("5b4a7a"), center + Vector3(0, 2.5, 0))
	_add(_cylinder(0.0, 2.3, 2.6, 16), Color("3a2e5a"), center + Vector3(0, 6.3, 0))
	holo = false


func _build_library() -> void:
	var center := _pos3("bibliotheque")
	holo = not "bibliotheque" in GameData.buildings
	_add(_box(Vector3(5.0, 3.0, 3.6)), Color("6f7d96"), center + Vector3(0, 1.5, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(5.4, 1.4, 4.0)
	_add(roof, Color("3d4a66"), center + Vector3(0, 3.7, 0))
	holo = false


## La salle d'invocation : un escalier, des colonnes, et le cercle d'invocation qui brille.
func _build_summon_hall() -> void:
	var center := _pos3("summon")
	for step in 3:
		_add(_box(Vector3(6.0 - step, 0.3, 4.6 - step)), STONE_COLOR.darkened(0.05 * step),
			center + Vector3(0, 0.15 + 0.3 * step, 0))
	_add(_box(Vector3(4.0, 2.8, 2.6)), STONE_COLOR, center + Vector3(0, 2.3, 0.4))
	for x in [-1.6, -0.55, 0.55, 1.6]:
		_add(_cylinder(0.18, 0.18, 2.6, 8), Color.WHITE, center + Vector3(x, 2.2, -1.2))
	_add(_box(Vector3(4.4, 0.4, 3.0)), STONE_COLOR.lightened(0.1), center + Vector3(0, 3.9, 0.2))
	_add(_cylinder(1.0, 1.0, 0.05, 24), Color("6fd8ff"), center + Vector3(0, 0.95, -1.8), true)


func _build_landing() -> void:
	var center := _pos3("landing")
	_add(_box(Vector3(6.5, 0.05, 5.0)), Color("8a2f35"), center + Vector3(0, 0.02, 0))
	_add(_cylinder(1.6, 1.6, 0.06, 32), Color("5fd0ff"), center + Vector3(0, 0.06, 0), true)


## La faille spatio-temporelle : une arche de pierre et un passage qui palpite.
func _build_rift() -> void:
	var center := _pos3("faille")
	for x in [-1.6, 1.6]:
		_add(_box(Vector3(0.8, 4.0, 0.8)), Color("5c6670"), center + Vector3(x, 2.0, 0))
	_add(_box(Vector3(4.2, 0.8, 0.9)), Color("5c6670"), center + Vector3(0, 4.3, 0))
	var portal := QuadMesh.new()
	portal.size = Vector2(2.4, 3.8)
	var node := _add(portal, Color("8a5cff"), center + Vector3(0, 2.0, 0), true)
	portal_material = node.material_override
	portal_material.cull_mode = BaseMaterial3D.CULL_DISABLED


# ---------------------------------------------------------------------------
# Les héros
# ---------------------------------------------------------------------------

## Met à jour les héros de la cité : arrivées, départs, morts, et changements d'occupation.
func _refresh_walkers() -> void:
	var present := {}  # numéro -> héros qui doit être dans la cité
	for hero in GameData.alive_heroes():
		if not GameData.is_away(hero) and present.size() < MAX_WALKERS:
			present[hero["id"]] = hero

	for walker in walkers.duplicate():
		var hero: Dictionary = walker["hero"]
		if walker["activity"] == "away":
			continue  # il marche déjà vers la faille
		if not present.has(hero["id"]):
			if hero["alive"] and GameData.is_away(hero):
				walker["activity"] = "away"  # il part en mission : direction la faille
				_route(walker, "faille", _door("faille"))
			else:
				_remove_walker(walker)
			continue
		var activity := _activity_of(hero)
		if activity != walker["activity"]:
			walker["activity"] = activity
			_go_to_activity(walker)

	var shown := {}
	for walker in walkers:
		shown[walker["hero"]["id"]] = true
	for id in present:
		if shown.has(id):
			continue
		var hero: Dictionary = present[id]
		var walker := _add_walker(hero)
		if first_refresh:
			_place_at_activity(walker)  # au lancement, chacun est déjà à sa place
		elif not known_ids.has(id):
			_spawn_at(walker, "summon")  # nouveau héros : il sort de la salle d'invocation
		else:
			_spawn_at(walker, "landing")  # retour de mission
		known_ids[id] = true
	first_refresh = false


## Ce que fait un héros : "train" (terrain d'entraînement), "post:<bâtiment>" (assistant), "idle".
func _activity_of(hero: Dictionary) -> String:
	if hero.get("training", "") != "" and GameData.training_unlocked():
		return "train"
	var post: String = hero.get("post", "")
	if post != "" and post in GameData.buildings and POST_PLACES.has(post):
		return "post:" + post
	return "idle"


func _add_walker(hero: Dictionary) -> Dictionary:
	var node := Node3D.new()
	walkers_root.add_child(node)
	var body := Node3D.new()
	body.position.y = BODY_Y
	node.add_child(body)
	var color: Color = GameData.RARITY_COLORS[hero["rarity"]]
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.3
	_add(capsule, color, Vector3.ZERO, false, body)
	_add(_sphere(0.28), Color("e8c4a0"), Vector3(0, 0.88, 0), false, body)
	if hero["class"] == "Mage":  # un chapeau pointu pour reconnaître les mages
		_add(_cylinder(0.0, 0.34, 0.6, 10), Color("3a2e7a"), Vector3(0, 1.3, 0), false, body)
	var label := _make_label(hero["name"], 13, color.lightened(0.45))
	var walker := {"hero": hero, "node": node, "body": body, "label": label, "path": [],
		"state": "wait", "activity": _activity_of(hero), "area": "center", "wait": 0.0,
		"phase": randf() * TAU, "spot": Vector3.ZERO}
	walkers.append(walker)
	return walker


func _remove_walker(walker: Dictionary) -> void:
	walker["node"].queue_free()
	walker["label"].queue_free()
	walkers.erase(walker)


## Pose le héros directement là où il doit être (au lancement du jeu).
func _place_at_activity(walker: Dictionary) -> void:
	var target := _activity_target(walker)
	walker["node"].position = target[1]
	walker["area"] = target[0]
	walker["path"] = []
	_arrived(walker)


## Fait apparaître le héros à un lieu (salle d'invocation, zone de débarquement), puis il part.
func _spawn_at(walker: Dictionary, place: String) -> void:
	walker["node"].position = _door(place)
	walker["area"] = place
	_go_to_activity(walker)


func _go_to_activity(walker: Dictionary) -> void:
	var target := _activity_target(walker)
	_route(walker, target[0], target[1])


## Où va le héros pour son occupation : [lieu, point précis].
func _activity_target(walker: Dictionary) -> Array:
	var activity: String = walker["activity"]
	if activity == "train":
		var index := _rank_among(walker, "train") % DUMMIES.size()
		var dummy: Vector2 = DUMMIES[index]
		var spot := _pos3("training") + Vector3(dummy.x, 0, dummy.y + 0.9)
		walker["spot"] = spot
		return ["training", spot]
	if activity.begins_with("post:"):
		var place: String = POST_PLACES[activity.trim_prefix("post:")]
		var side := -0.8 if _rank_among(walker, activity) % 2 == 0 else 0.8
		var door := _door(place)
		var across := (door - CENTER).normalized().cross(Vector3.UP)
		var spot := door + across * side
		walker["spot"] = spot
		return [place, spot]
	var area: String = IDLE_PLACES.pick_random()
	return [area, _random_point(area)]


## Place du héros parmi ceux qui ont la même occupation (pour qu'ils ne se marchent pas dessus).
func _rank_among(walker: Dictionary, activity: String) -> int:
	var ids: Array = []
	for other in walkers:
		if other["activity"] == activity:
			ids.append(other["hero"]["id"])
	ids.sort()
	return maxi(0, ids.find(walker["hero"]["id"]))


## Un point au hasard dans un lieu où l'on se promène.
func _random_point(area: String) -> Vector3:
	var center := CENTER if area == "center" else _pos3(area)
	var radius: float = 2.2 if area == "center" else PLACES[area]["radius"] - 1.0
	var angle := randf() * TAU
	var dist := sqrt(randf()) * radius
	var point := center + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	if area == "plaza" and point.distance_to(center) < 2.6:  # pas dans la fontaine : on le pousse au bord
		point = center + Vector3(cos(angle), 0, sin(angle)) * 3.0
	return point


## Le chemin d'un lieu à un autre : on sort par la porte, on passe par le carrefour du centre.
func _route(walker: Dictionary, area: String, point: Vector3) -> void:
	var path: Array = []
	if walker["area"] != area:
		if walker["area"] != "center":
			path.append(_door(walker["area"]))
		path.append(CENTER + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
		if area != "center":
			path.append(_door(area))
	path.append(point)
	walker["path"] = path
	walker["area"] = area
	walker["state"] = "walk"
	walker["body"].rotation = Vector3.ZERO


func _arrived(walker: Dictionary) -> void:
	var activity: String = walker["activity"]
	if activity == "away":
		_remove_walker(walker)  # il passe la faille
	elif activity == "train":
		walker["state"] = "train"
	elif activity.begins_with("post:"):
		walker["state"] = "work"
	else:
		walker["state"] = "wait"
		walker["wait"] = randf_range(2.0, 7.0)


func _animate_walker(walker: Dictionary, delta: float) -> void:
	var node: Node3D = walker["node"]
	var body: Node3D = walker["body"]
	walker["phase"] += delta
	var path: Array = walker["path"]
	if not path.is_empty():
		var goal: Vector3 = path[0]
		var to := goal - node.position
		to.y = 0.0
		var step := WALK_SPEED * delta
		if to.length() <= step:
			node.position = Vector3(goal.x, 0, goal.z)
			path.pop_front()
			if path.is_empty():
				body.position.y = BODY_Y
				_arrived(walker)
		else:
			node.position += to.normalized() * step
			node.rotation.y = atan2(to.x, to.z)
			body.position.y = BODY_Y + absf(sin(walker["phase"] * 9.0)) * 0.12  # les pas
		return
	match walker["state"]:
		"wait":
			walker["wait"] -= delta
			if walker["wait"] <= 0.0:
				var area: String = IDLE_PLACES.pick_random()
				_route(walker, area, _random_point(area))
		"train":
			# Il frappe le mannequin : petits bonds en avant, en se penchant.
			var dummy: Vector3 = walker["spot"] - Vector3(0, 0, 0.9)
			node.rotation.y = atan2(dummy.x - node.position.x, dummy.z - node.position.z)
			var hit := absf(sin(walker["phase"] * 5.0))
			body.position.y = BODY_Y + hit * 0.18
			body.rotation.x = hit * 0.35
		"work":
			body.rotation.z = sin(walker["phase"] * 2.0) * 0.12  # il s'affaire


# ---------------------------------------------------------------------------
# Caméra et toucher
# ---------------------------------------------------------------------------

func _update_camera() -> void:
	cam_target.y = 0.0
	if cam_target.length() > CITY_RADIUS - 4.0:
		cam_target = cam_target.normalized() * (CITY_RADIUS - 4.0)
	cam_distance = clampf(cam_distance, MIN_DISTANCE, MAX_DISTANCE)
	camera.position = cam_target + Vector3(0, sin(PITCH), cos(PITCH)) * cam_distance
	camera.basis = Basis.looking_at(cam_target - camera.position)  # regarde le point visé


func _gui_input(event: InputEvent) -> void:
	# Deux doigts : on zoome en écartant ou en rapprochant les doigts.
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		pinch_distance = _touch_spread()
		if touches.size() >= 2:
			moved = true  # pas un toucher
		accept_event()
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() >= 2:
			var spread := _touch_spread()
			if pinch_distance > 0.0 and spread > 0.0:
				cam_distance *= pinch_distance / spread
				_update_camera()
			pinch_distance = spread
		accept_event()
	elif event is InputEventMagnifyGesture:
		cam_distance /= event.factor
		_update_camera()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_distance *= 0.9
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_distance *= 1.1
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressing = true
				moved = false
				press_pos = event.position
			else:
				if pressing and not moved:
					_tap(event.position)
				pressing = false
		accept_event()
	elif event is InputEventMouseMotion and pressing:
		if event.position.distance_to(press_pos) > TAP_THRESHOLD:
			moved = true
		if moved and touches.size() < 2:
			# Un doigt : la cité suit le doigt.
			var units_per_pixel := 2.0 * cam_distance * tan(deg_to_rad(camera.fov) / 2.0) / maxf(size.x, 1.0)
			cam_target -= Vector3(event.relative.x, 0, event.relative.y / sin(PITCH)) * units_per_pixel
			_update_camera()
		accept_event()


func _touch_spread() -> float:
	if touches.size() < 2:
		return 0.0
	var points: Array = touches.values()
	return (points[0] as Vector2).distance_to(points[1])


## Un toucher : d'abord un héros (s'il y en a un sous le doigt), sinon un lieu.
func _tap(screen_pos: Vector2) -> void:
	var best_walker: Dictionary = {}
	var best := 34.0
	for walker in walkers:
		var head: Vector3 = walker["node"].global_position + Vector3(0, 1.2, 0)
		if camera.is_position_behind(head):
			continue
		var dist := camera.unproject_position(head).distance_to(screen_pos)
		if dist < best:
			best = dist
			best_walker = walker
	if not best_walker.is_empty():
		hero_pressed.emit(best_walker["hero"])
		return

	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.001:
		return
	var ground := origin + direction * (-origin.y / direction.y)
	var best_key := ""
	var best_dist := INF
	for key in PLACES:
		var dist: float = Vector2(ground.x, ground.z).distance_to(PLACES[key]["pos"])
		if dist <= PLACES[key]["radius"] + 0.5 and dist < best_dist:
			best_dist = dist
			best_key = key
	if best_key != "":
		zone_pressed.emit(_zone_info(best_key))


## Les informations d'un lieu, au même format que les quartiers de HubMap (pour HubScreen).
func _zone_info(key: String) -> Dictionary:
	var place_name: String = PLACES[key]["name"]
	for zone in HubMap.ZONES + [HubMap.PLAZA] + HubScreen.OUTSIDE_ZONES:
		if zone["name"] == place_name:
			return zone
	# Les bâtiments construits avec le bouton « Construction » (forge, atelier, bibliothèque).
	for id in GameData.BUILDINGS:
		var building: Dictionary = GameData.BUILDINGS[id]
		if building["name"] == place_name:
			var built: bool = id in GameData.buildings
			var info: String = building["info"]
			info += "" if built else " Pas encore construit (bouton « Construction »)."
			var target := "forge" if id == "forge" and built else ""
			return {"name": place_name, "target": target, "info": info}
	return {"name": place_name, "target": "", "info": ""}


# ---------------------------------------------------------------------------
# Petits outils de construction
# ---------------------------------------------------------------------------

func _pos3(key: String) -> Vector3:
	var pos: Vector2 = PLACES[key]["pos"]
	return Vector3(pos.x, 0, pos.y)


## La porte d'un lieu : là où les héros s'arrêtent (côté carrefour). Un espace ouvert : son centre.
func _door(key: String) -> Vector3:
	if key == "center":
		return CENTER
	var pos := _pos3(key)
	if PLACES[key].get("open", false):
		return pos
	return pos + (CENTER - pos).normalized() * (PLACES[key]["radius"] + 0.8)


## Ajoute une forme à la cité (ou à « parent »). « glow » : elle brille (cercle d'invocation, sphère...).
## Avec « holo », la forme est un hologramme cyan transparent (bâtiment pas encore construit).
func _add(mesh: Mesh, color: Color, pos: Vector3, glow := false, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, glow)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else city_root).add_child(node)
	return node


func _material(color: Color, glow: bool) -> StandardMaterial3D:
	if holo:
		color = HOLO_COLOR
		glow = true
	var key := "%s|%s|%s" % [color.to_html(), glow, holo]
	if materials.has(key) and not glow:
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow:
		material.emission_enabled = true
		material.emission = Color(color, 1.0)
		material.emission_energy_multiplier = 1.2
	if holo:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[key] = material
	return material


func _box(box_size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return mesh


func _cylinder(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


## Un nom affiché par-dessus la cité (texte à l'écran, de taille fixe quel que soit le zoom).
func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := UI.make_label(text, font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(label)
	return label


## Place chaque nom au-dessus de son lieu ou de son héros (les noms des héros seulement de près).
func _place_labels() -> void:
	for entry in place_labels:
		_stick_label(entry[0], entry[1])
	var show_names := cam_distance < NAME_DISTANCE
	for walker in walkers:
		var label: Label = walker["label"]
		label.visible = show_names
		if show_names:
			_stick_label(label, walker["node"].position + Vector3(0, 2.2, 0))


func _stick_label(label: Label, point: Vector3) -> void:
	label.visible = not camera.is_position_behind(point)
	if not label.visible:
		return
	label.reset_size()
	label.position = camera.unproject_position(point) - Vector2(label.size.x / 2.0, label.size.y)
