class_name HubCity3D
extends SubViewportContainer
## Le hub en 3D (nouveaux visuels ; les anciens gardent le plan HubMap) : la cité circulaire vue
## du dessus, disposée d'après le plan du manhwa : rempart à 12 pans, résidences sur toute la moitié
## ouest (rues en croix et en anneau, arbres), salle de combat au nord, grande place publique au
## nord-est, face à la faille (une arche dans le rempart), laboratoire à l'est, terrain
## d'entraînement au sud-ouest, zone de débarquement au sud.
##
## Un bâtiment pas encore construit est un terrain balisé « à construire ». Quand il se construit,
## il monte du sol en hologramme cyan, avec des pixels qui scintillent, puis devient solide
## (comme les animations de construction du Système dans le manhwa).
##
## Les héros y vivent : ils suivent les rues jusqu'au terrain d'entraînement s'ils s'entraînent,
## jusqu'à leur bâtiment s'ils y sont assistants, et se promènent sinon (place, rues des résidences).
## Ceux qui partent (Tour, donjon journalier) passent la faille ; ceux qui reviennent arrivent par la
## zone de débarquement ; les nouveaux sortent de la salle d'invocation.
##
## Un doigt : déplacer la vue. Deux doigts (ou la molette) : zoomer. Toucher : un lieu ou un héros.
## Tout est fait de formes simples (cubes, cylindres...) en attendant de vrais modèles.

signal zone_pressed(zone: Dictionary)
signal hero_pressed(hero: Dictionary)

# --- La cité (en mètres ; x vers la droite, z vers le bas de l'écran, le nord en haut) ---

## Rayon du rempart (jusqu'aux coins) et nombre de pans.
const CITY_RADIUS := 26.0
const WALL_SIDES := 12

## Le réseau des rues : des carrefours reliés entre eux (une croix et un anneau, comme le plan).
const CROSSINGS := {
	"C": Vector2(0, 0), "N": Vector2(-1, -9), "NW": Vector2(-9, -9), "NE": Vector2(6, -6),
	"E": Vector2(9, 2), "SE": Vector2(8, 10), "S": Vector2(2, 11), "SW": Vector2(-8, 10), "W": Vector2(-13, 1),
}
const STREETS := [["C", "N"], ["C", "E"], ["C", "S"], ["C", "W"], ["N", "NW"], ["N", "NE"], ["NE", "E"],
	["E", "SE"], ["SE", "S"], ["S", "SW"], ["SW", "W"], ["W", "NW"]]

## Les lieux : position, rayon (pour les toucher), nom (celui des quartiers de HubMap), carrefour
## auquel mène leur porte (« link »), nom affiché (« short ») et hauteur de ce nom (« height »).
## « open » : un espace à ciel ouvert où les héros entrent (sinon ils s'arrêtent devant la porte).
## « building » : bâtiment à construire (GameData.BUILDINGS) ; sans lui, un terrain balisé.
const PLACES := {
	"combat": {"name": "Salle de combat", "short": "Salle de combat", "pos": Vector2(-1, -17),
		"radius": 4.5, "link": "N", "height": 5.0},
	"synthese": {"name": "Chambre de synthèse", "short": "Synthèse", "pos": Vector2(-11, -16),
		"radius": 3.2, "link": "NW", "height": 6.5, "building": "synthese"},
	"armory": {"name": "Armurerie", "short": "Armurerie", "pos": Vector2(5, -13),
		"radius": 2.8, "link": "N", "height": 5.0},
	"forge": {"name": "Forge", "short": "Forge", "pos": Vector2(10, -17),
		"radius": 2.2, "link": "NE", "height": 4.0, "building": "forge"},
	"plaza": {"name": "Place publique", "short": "Place publique", "pos": Vector2(13, -8),
		"radius": 6.0, "link": "NE", "height": 3.5, "open": true},
	"faille": {"name": "Faille spatio-temporelle", "short": "Faille", "pos": Vector2(19.8, -11.4),
		"radius": 2.6, "link": "plaza", "height": 8.5},
	"atelier_magie": {"name": "Atelier de magie", "short": "Atelier de magie", "pos": Vector2(20.5, -1),
		"radius": 2.4, "link": "E", "height": 8.0, "building": "atelier_magie"},
	"lab": {"name": "Laboratoire d'alchimie", "short": "Laboratoire", "pos": Vector2(14.5, 4),
		"radius": 3.6, "link": "E", "height": 8.8, "building": "laboratoire"},
	"bibliotheque": {"name": "Bibliothèque", "short": "Bibliothèque", "pos": Vector2(17, 12),
		"radius": 2.8, "link": "SE", "height": 5.0, "building": "bibliotheque"},
	"summon": {"name": "Salle d'invocation", "short": "Invocation", "pos": Vector2(9, 17.5),
		"radius": 3.4, "link": "SE", "height": 5.0},
	"landing": {"name": "Zone de débarquement", "short": "Débarquement", "pos": Vector2(1, 19.5),
		"radius": 3.5, "link": "S", "height": 1.0, "open": true},
	"training": {"name": "Terrain d'entraînement", "short": "Entraînement", "pos": Vector2(-13, 12.5),
		"radius": 4.6, "link": "SW", "height": 1.5, "open": true},
	"residences": {"name": "Résidences", "short": "Résidences", "pos": Vector2(-15, -4),
		"radius": 4.0, "link": "W", "height": 4.0, "open": true},
}
## Bâtiment de chaque poste d'assistant (hero["post"]) : la forge est l'annexe de l'armurerie.
const POST_PLACES := {"synthese": "synthese", "forge": "forge", "atelier_magie": "atelier_magie",
	"laboratoire": "lab", "bibliotheque": "bibliotheque"}
## Où les héros sans occupation vont se promener (la place et les rues reviennent plus souvent).
const IDLE_PLACES := ["plaza", "plaza", "streets", "streets", "streets", "center"]

## Les mannequins du terrain d'entraînement (décalage par rapport au centre du terrain).
const DUMMIES := [Vector2(-2.6, -1.6), Vector2(-0.9, -1.6), Vector2(0.9, -1.6), Vector2(2.6, -1.6),
	Vector2(-2.6, 1.2), Vector2(-0.9, 1.2), Vector2(0.9, 1.2), Vector2(2.6, 1.2)]

# --- Couleurs ---

const STONE_GROUND := Color("5a5d63")
const GRASS_COLOR := Color("35532f")
const ROAD_COLOR := Color("9c8276")
const WALL_COLOR := Color("8f8b80")
const STONE_COLOR := Color("cfd0d6")
const HOLO_COLOR := Color(0.4, 0.95, 1.0, 0.45)
const HOUSE_WALLS := [Color("d8ccb4"), Color("c9b89a"), Color("b9a58a"), Color("ddd3c2")]
const HOUSE_ROOFS := [Color("8e3b2f"), Color("6b4a3a"), Color("505c6e"), Color("7a3b44")]

# --- Héros ---

## Au plus ce nombre de héros dans la cité (pour que le téléphone suive).
const MAX_WALKERS := 60
const WALK_SPEED := 2.6
const BODY_Y := 0.75
## Les noms des héros ne s'affichent que si la caméra est assez près.
const NAME_DISTANCE := 34.0

# --- Caméra ---

const PITCH := deg_to_rad(62.0)
const MIN_DISTANCE := 14.0
const MAX_DISTANCE := 70.0
## Un appui qui bouge de plus de ça (pixels) devient un glissement, pas un toucher.
const TAP_THRESHOLD := 12.0
## Les héros sont mis à jour (activités, arrivées, départs) à cet intervalle (secondes).
const REFRESH_SECONDS := 1.5
## Durée de l'animation de construction (secondes).
const BUILD_SECONDS := 2.6

var viewport: SubViewport
var camera: Camera3D
var city_root: Node3D
var walkers_root: Node3D

var cam_target := Vector3(0, 0, 1)
var cam_distance := 56.0

## Héros en promenade : {"hero", "node", "body", "label", "path": [Vector3], "state", "activity",
## "area", "wait", "phase", "spot"}.
var walkers: Array[Dictionary] = []
## Numéros des héros déjà vus : un héros inconnu vient d'être invoqué (il sort de la salle d'invocation).
var known_ids := {}
var first_refresh := true
var refresh_timer := 0.0
## Ce qui décide de l'allure de la cité (bâtiments construits...) : on la reconstruit quand ça change.
var city_signature := ""
## Bâtiments construits au dernier passage : un nouveau venu a droit à l'animation de construction.
var known_buildings: Array = []

## Le chemin des héros : les carrefours et les portes des lieux (AStar3D trouve le trajet par les rues).
var astar := AStar3D.new()
var door_ids := {}
## Des points le long des rues des résidences, pour s'y promener.
var street_spots: Array[Vector3] = []
## Rues déjà tracées (segments 2D), pour placer maisons et arbres à côté.
var road_segments: Array = []
## Le groupe de formes de chaque lieu (pour l'animation de construction).
var place_groups := {}
var current_group: Node3D

## Les noms affichés par-dessus la 3D, et ceux des lieux : [Label, point de la cité].
var overlay: Control
var place_labels: Array = []

var materials := {}
var holo_material: StandardMaterial3D
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

	# L'ambiance : fin d'après-midi, brume bleutée (comme les vues de la cité du manhwa).
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("10202a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7fa6c4")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.95
	environment.fog_enabled = true
	environment.fog_light_color = Color("35606e")
	environment.fog_density = 0.0028
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.1
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.15
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(40), 0)
	sun.light_color = Color("ffe3bf")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.75
	sun.directional_shadow_max_distance = 120.0
	viewport.add_child(sun)

	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH  # toute la largeur de la cité tient dans l'écran
	camera.fov = 52.0
	camera.far = 300.0
	viewport.add_child(camera)

	city_root = Node3D.new()
	viewport.add_child(city_root)
	walkers_root = Node3D.new()
	viewport.add_child(walkers_root)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(overlay)

	holo_material = StandardMaterial3D.new()
	holo_material.albedo_color = HOLO_COLOR
	holo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	holo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	holo_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	holo_material.emission_enabled = true
	holo_material.emission = Color(HOLO_COLOR, 1.0)
	holo_material.emission_energy_multiplier = 1.6
	_build_paths()
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
		portal_material.emission_energy_multiplier = 1.1 + sin(Time.get_ticks_msec() / 420.0) * 0.5
	_place_labels()


# ---------------------------------------------------------------------------
# Les chemins
# ---------------------------------------------------------------------------

## Le réseau de chemins : les carrefours, reliés par les rues, et la porte de chaque lieu,
## reliée à son carrefour (ou à la place, pour la faille).
func _build_paths() -> void:
	var ids := {}
	for key in CROSSINGS:
		var id := astar.get_available_point_id()
		astar.add_point(id, _v3(CROSSINGS[key]))
		ids[key] = id
	for street in STREETS:
		astar.connect_points(ids[street[0]], ids[street[1]])
	for key in PLACES:
		var id := astar.get_available_point_id()
		astar.add_point(id, _door(key))
		door_ids[key] = id
	for key in PLACES:
		var link: String = PLACES[key]["link"]
		astar.connect_points(door_ids[key], door_ids[link] if PLACES.has(link) else ids[link])
	# Des points de promenade le long des rues de l'ouest (les résidences).
	for street in STREETS:
		var a := _v3(CROSSINGS[street[0]])
		var b := _v3(CROSSINGS[street[1]])
		var steps := int(a.distance_to(b) / 2.0)
		for i in steps + 1:
			var point := a.lerp(b, float(i) / maxi(steps, 1))
			if point.x < -2.0:
				street_spots.append(point)


# ---------------------------------------------------------------------------
# La cité
# ---------------------------------------------------------------------------

func _rebuild_city_if_needed() -> void:
	var built: Array = GameData.buildings.duplicate()
	built.sort()
	var signature := "%s|%s" % [",".join(built), GameData.training_unlocked()]
	if signature == city_signature:
		return
	var first_build := city_signature == ""
	city_signature = signature
	for child in city_root.get_children():
		child.queue_free()
	for entry in place_labels:
		entry[0].queue_free()
	place_labels.clear()
	place_groups.clear()
	road_segments.clear()
	portal_material = null
	_build_city()
	# Un bâtiment qui vient d'être construit monte du sol en hologramme.
	if not first_build:
		for key in PLACES:
			var building: String = PLACES[key].get("building", "")
			if building != "" and building in built and not building in known_buildings:
				_play_construction(key)
	known_buildings = built


func _build_city() -> void:
	current_group = city_root
	_build_ground()
	_build_wall()
	_build_streets()
	_build_combat_hall()
	_build_armory()
	_build_plaza()
	_build_rift()
	_build_training()
	_build_landing()
	_build_summon_hall()
	for key in PLACES:
		var building: String = PLACES[key].get("building", "")
		current_group = Node3D.new()
		city_root.add_child(current_group)
		place_groups[key] = current_group
		if building != "" and not building in GameData.buildings:
			_build_plot(key)
			continue
		match key:
			"synthese": _build_synthesis()
			"forge": _build_forge()
			"lab": _build_lab()
			"atelier_magie": _build_magic_workshop()
			"bibliotheque": _build_library()
	current_group = city_root
	_build_houses()
	_build_trees()
	_build_lamps()

	# Le nom de chaque lieu, au-dessus (en gris : pas encore construit ou fermé).
	for key in PLACES:
		var place: Dictionary = PLACES[key]
		var text: String = place["short"]
		var color := Color.WHITE
		var building: String = place.get("building", "")
		if building != "" and not building in GameData.buildings:
			text += "\n(à construire)"
			color = Color(1, 1, 1, 0.6)
		elif key == "training" and not GameData.training_unlocked():
			text += "\n(fermé)"
			color = Color(1, 1, 1, 0.6)
		var label := _make_label(text, 17, color)
		place_labels.append([label, _pos3(key) + Vector3(0, place["height"], 0)])


func _build_ground() -> void:
	var outside := PlaneMesh.new()
	outside.size = Vector2(260, 260)
	_add_textured(outside, GRASS_COLOR.darkened(0.25), Vector3(0, -0.2, 0), 0.06)
	_add_textured(_cylinder(CITY_RADIUS, CITY_RADIUS, 0.3, WALL_SIDES), STONE_GROUND, Vector3(0, -0.15, 0), 0.25)
	# De la verdure dans les résidences (la moitié ouest), comme sur le plan.
	for patch in [Vector3(-14, 0, -8), Vector3(-17, 0, 4), Vector3(-6, 0, 4), Vector3(-5, 0, -13), Vector3(-19, 0, -2)]:
		_add_textured(_cylinder(4.5, 4.5, 0.04, 20), GRASS_COLOR, patch + Vector3(0, 0.01, 0), 0.3)


## Le rempart à pans, avec des créneaux et une tour moussue à chaque coin.
func _build_wall() -> void:
	var side := 2.0 * CITY_RADIUS * sin(PI / WALL_SIDES)
	var merlon_transforms: Array[Transform3D] = []
	for i in WALL_SIDES:
		var a := TAU * i / WALL_SIDES
		var b := TAU * (i + 1) / WALL_SIDES
		var corner_a := Vector3(cos(a), 0, sin(a)) * CITY_RADIUS
		var corner_b := Vector3(cos(b), 0, sin(b)) * CITY_RADIUS
		var mid := (corner_a + corner_b) * 0.5
		var angle := atan2(corner_b.x - corner_a.x, corner_b.z - corner_a.z)
		var segment := _add_textured(_box(Vector3(1.8, 3.6, side)), WALL_COLOR, mid + Vector3(0, 1.8, 0), 0.5)
		segment.rotation.y = angle
		var count := int(side / 1.6)
		for m in count:
			var point := corner_a.lerp(corner_b, (m + 0.5) / count)
			merlon_transforms.append(Transform3D(Basis(Vector3.UP, angle), point + Vector3(0, 3.95, 0)))
		var tower := _add(_box(Vector3(3.2, 5.2, 3.2)), WALL_COLOR.lightened(0.08), corner_a + Vector3(0, 2.6, 0))
		tower.rotation.y = a
		var moss := _add(_box(Vector3(3.3, 0.35, 3.3)), Color("3f5a3a"), corner_a + Vector3(0, 5.35, 0))
		moss.rotation.y = a
	_multi(_box(Vector3(1.9, 0.7, 0.8)), merlon_transforms, [], WALL_COLOR.lightened(0.05))


func _build_streets() -> void:
	# La petite place du carrefour central.
	_add(_cylinder(2.8, 2.8, 0.06, 24), ROAD_COLOR.lightened(0.08), Vector3(0, 0.03, 0))
	for street in STREETS:
		_road(_v3(CROSSINGS[street[0]]), _v3(CROSSINGS[street[1]]), 2.6)
	for key in PLACES:
		var link: String = PLACES[key]["link"]
		var to := _pos3(link) if PLACES.has(link) else _v3(CROSSINGS[link])
		_road(_door(key), to, 1.8)


func _road(from: Vector3, to: Vector3, width: float) -> void:
	var length := from.distance_to(to)
	if length < 0.3:
		return
	var road := _add(_box(Vector3(width, 0.06, length + width * 0.5)), ROAD_COLOR, (from + to) / 2.0 + Vector3(0, 0.03, 0))
	road.rotation.y = atan2(to.x - from.x, to.z - from.z)
	road_segments.append([Vector2(from.x, from.z), Vector2(to.x, to.z)])


## Les maisons des résidences, le long des rues de l'ouest, sans déborder sur les autres lieux.
func _build_houses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # toujours les mêmes maisons
	var placed: Array[Vector2] = []
	var first := true
	for x in range(-23, 1, 4):
		for z in range(-15, 12, 4):
			var spot := Vector2(x + rng.randf_range(-0.8, 0.8), z + rng.randf_range(-0.8, 0.8))
			if spot.length() > CITY_RADIUS - 4.5 or not _free_spot(spot, 2.4, 2.2):
				continue
			placed.append(spot)
			var size := Vector3(rng.randf_range(2.4, 3.4), rng.randf_range(1.8, 2.6), rng.randf_range(2.2, 3.0))
			var turn := 0.0 if rng.randf() < 0.5 else PI / 2.0
			var walls: Color = HOUSE_WALLS[rng.randi() % HOUSE_WALLS.size()]
			var roof_color: Color = HOUSE_ROOFS[rng.randi() % HOUSE_ROOFS.size()]
			if first:
				roof_color = Color("c0392b")  # la maison rouge du Maître, comme sur le plan
				first = false
			var base := Vector3(spot.x, 0, spot.y)
			var house := _add(_box(size), walls, base + Vector3(0, size.y / 2.0, 0))
			house.rotation.y = turn
			var roof := PrismMesh.new()
			roof.size = Vector3(size.x + 0.4, 1.2, size.z + 0.4)
			var roof_node := _add(roof, roof_color, base + Vector3(0, size.y + 0.6, 0))
			roof_node.rotation.y = turn
			if rng.randf() < 0.5:
				_add(_box(Vector3(0.45, 1.0, 0.45)), Color("6a6460"), base + Vector3(size.x * 0.25, size.y + 0.9, 0).rotated(Vector3.UP, turn))
	# Gardées pour que les arbres ne poussent pas dans les maisons.
	set_meta("houses", placed)


## Des arbres dans la cité (entre les maisons, le long du rempart) et la forêt tout autour.
func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var houses: Array = get_meta("houses", [])
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var crown_colors: Array[Color] = []
	var tries := 0
	var inside := 0
	while inside < 70 and tries < 900:
		tries += 1
		var spot := Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24))
		if spot.length() > CITY_RADIUS - 3.2 or not _free_spot(spot, 1.6, 1.5):
			continue
		var crowded := false
		for house in houses:
			if spot.distance_to(house) < 2.6:
				crowded = true
				break
		if crowded:
			continue
		inside += 1
		_tree(Vector3(spot.x, 0, spot.y), rng.randf_range(0.8, 1.2), rng, trunks, crowns, crown_colors)
	for i in 230:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(CITY_RADIUS + 2.5, CITY_RADIUS + 40.0)
		_tree(Vector3(cos(angle) * dist, 0, sin(angle) * dist), rng.randf_range(1.2, 2.0), rng, trunks, crowns, crown_colors)
	_multi(_cylinder(0.18, 0.25, 1.4, 6), trunks, [], Color("4a3726"))
	_multi(_sphere(1.0, 8, 5), crowns, crown_colors, Color.WHITE)


func _tree(spot: Vector3, size_factor: float, rng: RandomNumberGenerator, trunks: Array[Transform3D],
		crowns: Array[Transform3D], colors: Array[Color]) -> void:
	trunks.append(Transform3D(Basis.from_scale(Vector3.ONE * size_factor), spot + Vector3(0, 0.7 * size_factor, 0)))
	for blob in 2:
		var offset := Vector3(rng.randf_range(-0.5, 0.5), 1.9 + blob * 0.8, rng.randf_range(-0.5, 0.5)) * size_factor
		var radius := (1.2 - blob * 0.3) * size_factor
		crowns.append(Transform3D(Basis.from_scale(Vector3(radius, radius * 0.85, radius)), spot + offset))
		colors.append(Color("2f5a33").lerp(Color("4d7a3e"), rng.randf()))


## Des lampadaires le long des grandes rues (leur lanterne brille).
func _build_lamps() -> void:
	var posts: Array[Transform3D] = []
	var bulbs: Array[Transform3D] = []
	for street in STREETS:
		var a := _v3(CROSSINGS[street[0]])
		var b := _v3(CROSSINGS[street[1]])
		var side := (b - a).normalized().cross(Vector3.UP) * 1.6
		var count := int(a.distance_to(b) / 6.0)
		for i in count:
			var point := a.lerp(b, (i + 0.5) / count) + (side if i % 2 == 0 else -side)
			posts.append(Transform3D(Basis(), point + Vector3(0, 1.1, 0)))
			bulbs.append(Transform3D(Basis(), point + Vector3(0, 2.3, 0)))
	_multi(_cylinder(0.07, 0.09, 2.2, 6), posts, [], Color("2e2f33"))
	var bulb := _multi(_sphere(0.2, 8, 4), bulbs, [], Color("ffd27a"))
	bulb.material_override = _material(Color("ffd27a"), true)


## Un endroit libre : loin des rues et des lieux.
func _free_spot(spot: Vector2, road_margin: float, place_margin: float) -> bool:
	for segment in road_segments:
		if Geometry2D.get_closest_point_to_segment(spot, segment[0], segment[1]).distance_to(spot) < road_margin:
			return false
	for key in PLACES:
		if key == "residences":
			continue
		if spot.distance_to(PLACES[key]["pos"]) < PLACES[key]["radius"] + place_margin:
			return false
	return spot.length() > 3.5  # pas sur la place du carrefour


## La salle de combat : un grand bâtiment rond, le toit marqué d'une spirale (cercles).
func _build_combat_hall() -> void:
	var center := _pos3("combat")
	_add(_cylinder(4.6, 4.8, 0.5, 32), STONE_COLOR.darkened(0.1), center + Vector3(0, 0.25, 0))
	_add(_cylinder(4.0, 4.2, 3.4, 32), Color("6f879b"), center + Vector3(0, 2.2, 0))
	for i in 12:
		var angle := TAU * i / 12
		_add(_box(Vector3(0.5, 3.4, 0.5)), Color("9ab0c2"), center + Vector3(cos(angle) * 4.2, 2.2, sin(angle) * 4.2))
	_add(_cylinder(4.6, 4.6, 0.4, 32), Color("9ab0c2"), center + Vector3(0, 4.1, 0))
	for i in 4:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.6 + i * 0.95
		ring.outer_radius = 0.9 + i * 0.95
		_add(ring, Color("d7ecf7"), center + Vector3(0, 4.35 + (3 - i) * 0.12, 0))
	_add(_cylinder(0.5, 0.6, 0.8, 12), Color("d7ecf7"), center + Vector3(0, 4.8, 0))


## L'armurerie : un atelier de pierre au toit de tuiles, une enclume devant.
func _build_armory() -> void:
	var center := _pos3("armory")
	_add(_box(Vector3(5.0, 2.8, 3.8)), Color("8d8378"), center + Vector3(0, 1.4, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(5.6, 1.5, 4.3)
	_add(roof, Color("5b6d86"), center + Vector3(0, 3.55, 0))
	var door := _door("armory")
	_add(_box(Vector3(0.8, 0.5, 0.4)), Color("3a3a3e"), door + Vector3(1.2, 0.45, 0))  # l'enclume
	_add(_box(Vector3(0.4, 0.4, 0.4)), Color("5a4630"), door + Vector3(1.2, 0.2, 0))


## L'annexe de l'armurerie : la forge, sa cheminée et son feu.
func _build_forge() -> void:
	var center := _pos3("forge")
	_add(_box(Vector3(3.2, 2.2, 3.0)), Color("75695e"), center + Vector3(0, 1.1, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(3.6, 1.1, 3.4)
	_add(roof, Color("5a3a2a"), center + Vector3(0, 2.75, 0))
	_add(_box(Vector3(0.8, 2.4, 0.8)), Color("5a5a5a"), center + Vector3(-0.9, 3.2, 0.5))
	_add(_sphere(0.4, 10, 6), Color("ff8a2a"), _door("forge") + Vector3(0, 0.6, 0), true)


## La place publique : un dallage en roue (comme le plan), la fontaine au centre, des bancs.
func _build_plaza() -> void:
	var center := _pos3("plaza")
	_add_textured(_cylinder(6.0, 6.0, 0.06, 40), Color("c2a874"), center + Vector3(0, 0.04, 0), 0.4)
	for i in 8:
		var spoke := _add(_box(Vector3(0.25, 0.08, 5.8)), Color("8f7a52"),
			center + Vector3(cos(TAU * i / 8), 0, sin(TAU * i / 8)) * 3.2 + Vector3(0, 0.05, 0))
		spoke.rotation.y = -TAU * i / 8 + PI / 2.0
	var rim := TorusMesh.new()
	rim.inner_radius = 5.6
	rim.outer_radius = 6.0
	_add(rim, Color("8f7a52"), center + Vector3(0, 0.02, 0))
	_add(_cylinder(2.0, 2.1, 0.6, 28), STONE_COLOR, center + Vector3(0, 0.3, 0))
	_add(_cylinder(1.8, 1.8, 0.1, 28), Color("4fb0d8"), center + Vector3(0, 0.6, 0), true)
	_add(_cylinder(0.9, 1.0, 0.8, 16), STONE_COLOR, center + Vector3(0, 1.0, 0))
	_add(_cylinder(0.35, 0.45, 1.5, 12), STONE_COLOR, center + Vector3(0, 1.8, 0))
	_add(_sphere(0.45, 12, 6), Color("e6f6ff"), center + Vector3(0, 2.7, 0), true)
	for angle in [0.6, 2.2, 3.8, 5.4]:
		var bench := _add(_box(Vector3(1.6, 0.45, 0.5)), Color("6e5a44"),
			center + Vector3(cos(angle), 0, sin(angle)) * 4.6 + Vector3(0, 0.22, 0))
		bench.rotation.y = -angle + PI / 2.0


## La faille spatio-temporelle : une immense arche dans le rempart, envahie de racines, face à
## la place (comme le manhwa), et un passage violet qui palpite.
func _build_rift() -> void:
	var center := _pos3("faille")
	var facing := atan2(-center.x, -center.z)  # tournée vers le centre de la cité
	var arch := Node3D.new()
	arch.position = center
	arch.rotation.y = facing
	current_group.add_child(arch)
	for x in [-2.6, 2.6]:
		_add(_box(Vector3(1.4, 6.5, 1.8)), Color("6b7178"), Vector3(x, 3.25, 0), false, arch)
	var top := TorusMesh.new()
	top.inner_radius = 2.0
	top.outer_radius = 3.2
	var ring := _add(top, Color("6b7178"), Vector3(0, 6.2, 0), false, arch)
	ring.rotation.x = PI / 2.0
	var portal := _add(_cylinder(2.2, 2.2, 0.2, 24), Color("9a6cff"), Vector3(0, 3.6, 0), true, arch)
	portal.rotation.x = PI / 2.0
	portal.scale = Vector3(1.0, 1.0, 1.6)
	portal_material = portal.material_override.duplicate() as StandardMaterial3D
	portal.material_override = portal_material
	# Les racines qui s'enroulent autour des piliers.
	for root_spot in [Vector3(-3.3, 1.2, 0.6), Vector3(-3.0, 0.8, -0.5), Vector3(3.3, 1.2, 0.5), Vector3(3.1, 0.9, -0.6)]:
		var root := _add(_cylinder(0.15, 0.35, 3.0, 6), Color("4b3427"), root_spot, false, arch)
		root.rotation.z = 0.5 if root_spot.x < 0 else -0.5
	for crown in [Vector3(-3.5, 7.0, 0), Vector3(3.5, 7.2, 0), Vector3(0, 8.6, 0)]:
		_add(_sphere(1.4, 8, 5), Color("335c37"), crown, false, arch)


## Le terrain d'entraînement : du sable, des mannequins, un râtelier, des tonneaux, une barrière.
func _build_training() -> void:
	var center := _pos3("training")
	_add_textured(_cylinder(4.8, 4.8, 0.06, 32), Color("b39e78"), center + Vector3(0, 0.03, 0), 0.5)
	for dummy in DUMMIES:
		var spot := center + Vector3(dummy.x, 0, dummy.y)
		_add(_cylinder(0.12, 0.15, 1.6, 6), Color("5a4630"), spot + Vector3(0, 0.8, 0))
		_add(_box(Vector3(1.0, 0.12, 0.12)), Color("5a4630"), spot + Vector3(0, 1.2, 0))
		_add(_sphere(0.2, 8, 4), Color("a08860"), spot + Vector3(0, 1.75, 0))
	var rack := _add(_box(Vector3(2.0, 1.2, 0.3)), Color("6e4e2e"), center + Vector3(-1.0, 0.6, 3.6))
	rack.rotation.y = 0.2
	for barrel in [Vector3(3.4, 0, 2.6), Vector3(3.0, 0, 3.3)]:
		_add(_cylinder(0.4, 0.4, 0.9, 10), Color("6e4e2e"), center + barrel + Vector3(0, 0.45, 0))
	if not GameData.training_unlocked():  # fermé : une barrière en travers
		for i in 6:
			var angle := TAU * i / 6
			_add(_cylinder(0.08, 0.08, 1.0, 6), Color("8a6a40"), center + Vector3(cos(angle), 0, sin(angle)) * 4.8 + Vector3(0, 0.5, 0))


func _build_landing() -> void:
	var center := _pos3("landing")
	_add(_box(Vector3(7.0, 0.06, 5.0)), Color("8e3a3a"), center + Vector3(0, 0.04, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 1.4
	ring.outer_radius = 1.7
	_add(ring, Color("5fd0ff"), center + Vector3(0, 0.1, 0), true)
	_add(_cylinder(1.4, 1.4, 0.03, 24), Color("2a6f8a"), center + Vector3(0, 0.08, 0))


## La salle d'invocation : un escalier, une colonnade, et le cercle d'invocation qui brille.
func _build_summon_hall() -> void:
	var center := _pos3("summon")
	var facing := atan2(-center.x, -center.z)
	var hall := Node3D.new()
	hall.position = center
	hall.rotation.y = facing
	current_group.add_child(hall)
	for step in 3:
		_add(_box(Vector3(6.2 - step * 0.6, 0.3, 5.0 - step * 0.6)), STONE_COLOR.darkened(0.05 * step),
			Vector3(0, 0.15 + 0.3 * step, 0), false, hall)
	_add(_box(Vector3(4.4, 3.0, 2.6)), STONE_COLOR, Vector3(0, 2.4, -0.6), false, hall)
	for x in [-1.8, -0.6, 0.6, 1.8]:
		_add(_cylinder(0.2, 0.2, 2.8, 10), Color.WHITE, Vector3(x, 2.3, 1.2), false, hall)
	var pediment := PrismMesh.new()
	pediment.size = Vector3(5.0, 1.0, 3.4)
	_add(pediment, STONE_COLOR.lightened(0.1), Vector3(0, 4.4, 0.2), false, hall)
	_add(_cylinder(0.9, 0.9, 0.04, 24), Color("6fd8ff"), Vector3(0, 0.95, 0.4), true, hall)


## La chambre de synthèse : une rotonde à colonnes, coiffée d'un dôme, porte lumineuse.
func _build_synthesis() -> void:
	var center := _pos3("synthese")
	_add(_cylinder(3.1, 3.3, 0.5, 24), STONE_COLOR, center + Vector3(0, 0.25, 0))
	_add(_cylinder(2.1, 2.1, 3.0, 20), STONE_COLOR.darkened(0.12), center + Vector3(0, 2.0, 0))
	for i in 10:
		var angle := TAU * i / 10
		_add(_cylinder(0.2, 0.2, 3.0, 8), STONE_COLOR, center + Vector3(cos(angle) * 2.7, 2.0, sin(angle) * 2.7))
	_add(_cylinder(3.0, 3.0, 0.4, 24), STONE_COLOR, center + Vector3(0, 3.7, 0))
	var dome := _sphere(2.4, 16, 8)
	dome.height = 2.6
	_add(dome, STONE_COLOR.lightened(0.08), center + Vector3(0, 3.9, 0))
	var door := center + (_door("synthese") - center).normalized() * 2.15
	_add(_box(Vector3(0.9, 1.8, 0.15)), Color("6fd8ff"), door + Vector3(0, 1.4, 0), true).look_at_from_position(
		door + Vector3(0, 1.4, 0), center + Vector3(0, 1.4, 0))


## Le laboratoire d'alchimie : un socle à colonnes et une grande sphère bleue.
func _build_lab() -> void:
	var center := _pos3("lab")
	_add(_cylinder(3.4, 3.6, 0.7, 28), STONE_COLOR, center + Vector3(0, 0.35, 0))
	for i in 8:
		var angle := TAU * i / 8
		_add(_cylinder(0.22, 0.22, 3.0, 8), STONE_COLOR, center + Vector3(cos(angle) * 3.0, 2.2, sin(angle) * 3.0))
	_add(_cylinder(3.2, 3.2, 0.35, 28), STONE_COLOR, center + Vector3(0, 3.8, 0))
	_add(_cylinder(1.6, 2.4, 0.6, 24), STONE_COLOR.darkened(0.1), center + Vector3(0, 4.25, 0))
	_add(_sphere(2.0, 20, 10), Color("2f62b0"), center + Vector3(0, 6.3, 0), true)  # posée sur le toit


## L'atelier de magie : une tour violette au toit pointu, un cristal qui flotte au-dessus.
func _build_magic_workshop() -> void:
	var center := _pos3("atelier_magie")
	_add(_cylinder(1.8, 2.0, 5.0, 16), Color("5b4a7a"), center + Vector3(0, 2.5, 0))
	_add(_cylinder(0.0, 2.3, 2.6, 16), Color("3a2e5a"), center + Vector3(0, 6.3, 0))
	_add(_sphere(0.45, 8, 4), Color("c9a2ff"), center + Vector3(0, 8.2, 0), true)


func _build_library() -> void:
	var center := _pos3("bibliotheque")
	_add(_box(Vector3(5.0, 3.0, 3.6)), Color("8a93a8"), center + Vector3(0, 1.5, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(5.4, 1.4, 4.0)
	_add(roof, Color("3d4a66"), center + Vector3(0, 3.7, 0))
	for x in [-1.8, -0.6, 0.6, 1.8]:
		_add(_cylinder(0.16, 0.16, 2.8, 8), Color.WHITE, center + Vector3(x, 1.4, 2.0))


## Un terrain pas encore construit : de la terre, des piquets, une corde et un panneau.
func _build_plot(key: String) -> void:
	var center := _pos3(key)
	var half: float = PLACES[key]["radius"] * 0.8
	_add(_box(Vector3(half * 2, 0.05, half * 2)), Color("6e5a45"), center + Vector3(0, 0.03, 0))
	var corners := [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)]
	for i in 4:
		_add(_cylinder(0.08, 0.08, 0.9, 6), Color("c9a86a"), center + corners[i] + Vector3(0, 0.45, 0))
		var next: Vector3 = corners[(i + 1) % 4]
		var rope := _add(_box(Vector3(0.04, 0.04, half * 2)), Color("e8d9a8"), center + (corners[i] + next) / 2.0 + Vector3(0, 0.75, 0))
		rope.rotation.y = atan2(next.x - corners[i].x, next.z - corners[i].z)
	_add(_box(Vector3(0.9, 0.6, 0.08)), Color("a07a4a"), center + Vector3(0, 1.0, half))
	_add(_cylinder(0.06, 0.06, 1.0, 6), Color("6e4e2e"), center + Vector3(0, 0.5, half))


## Animation de construction : le bâtiment monte du sol en hologramme cyan, des pixels scintillent
## autour, puis il devient solide.
func _play_construction(key: String) -> void:
	var group: Node3D = place_groups.get(key)
	if group == null:
		return
	var originals := {}
	for node in group.find_children("*", "MeshInstance3D", true, false):
		originals[node] = node.material_override
		node.material_override = holo_material
	group.scale = Vector3(1.0, 0.02, 1.0)
	var tween := create_tween()
	tween.tween_property(group, "scale:y", 1.0, BUILD_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		for node in originals:
			if is_instance_valid(node):
				node.material_override = originals[node])
	# Les pixels de l'hologramme, qui apparaissent et disparaissent.
	var center := _pos3(key)
	var radius: float = PLACES[key]["radius"]
	for i in 26:
		var pixel := _add(_box(Vector3.ONE * randf_range(0.2, 0.6)), HOLO_COLOR,
			center + Vector3(randf_range(-radius, radius), randf_range(0.3, 5.0), randf_range(-radius, radius)), false, city_root)
		pixel.material_override = holo_material
		pixel.visible = false
		var blink := create_tween()
		blink.tween_interval(randf_range(0.0, BUILD_SECONDS * 0.8))
		for flash in 3:
			blink.tween_callback(func(): pixel.visible = true)
			blink.tween_interval(randf_range(0.05, 0.2))
			blink.tween_callback(func(): pixel.visible = false)
			blink.tween_interval(randf_range(0.05, 0.25))
		blink.tween_callback(pixel.queue_free)


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
				_route(walker, "faille", _pos3("faille"))
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
	_add(_sphere(0.28, 12, 6), Color("e8c4a0"), Vector3(0, 0.88, 0), false, body)
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
		var spot := _pos3("training") + Vector3(dummy.x, 0, dummy.y + 0.8)
		walker["spot"] = spot
		return ["training", spot]
	if activity.begins_with("post:"):
		var place: String = POST_PLACES[activity.trim_prefix("post:")]
		var side := -0.8 if _rank_among(walker, activity) % 2 == 0 else 0.8
		var door := _door(place)
		var across := (door - _pos3(place)).normalized().cross(Vector3.UP)
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


## Un point au hasard là où l'on se promène : sur la place, au carrefour, ou dans une rue des résidences.
func _random_point(area: String) -> Vector3:
	if area == "streets":
		var spot: Vector3 = street_spots.pick_random()
		return spot + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
	var center := Vector3.ZERO if area == "center" else _pos3(area)
	var radius: float = 2.3 if area == "center" else PLACES[area]["radius"] - 1.0
	var angle := randf() * TAU
	var dist := sqrt(randf()) * radius
	if area == "plaza":
		dist = randf_range(2.8, radius)  # pas dans la fontaine
	return center + Vector3(cos(angle) * dist, 0, sin(angle) * dist)


## Le chemin jusqu'à un point : par les rues (AStar3D), puis droit vers le point.
func _route(walker: Dictionary, area: String, point: Vector3) -> void:
	var path: Array = []
	if walker["area"] != area or area == "streets":
		var from_id := astar.get_closest_point(walker["node"].position)
		var to_id := astar.get_closest_point(point)
		if door_ids.has(area):
			to_id = door_ids[area]
		for step in astar.get_point_path(from_id, to_id):
			path.append(step + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)))
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
			var dummy: Vector3 = walker["spot"] - Vector3(0, 0, 0.8)
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
# Les noms affichés par-dessus la cité
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Petits outils de construction
# ---------------------------------------------------------------------------

func _v3(point: Vector2) -> Vector3:
	return Vector3(point.x, 0, point.y)


func _pos3(key: String) -> Vector3:
	return _v3(PLACES[key]["pos"])


## La porte d'un lieu : là où les héros s'arrêtent, du côté de la rue qui y mène.
## Un espace ouvert : son centre.
func _door(key: String) -> Vector3:
	var pos := _pos3(key)
	if PLACES[key].get("open", false):
		return pos
	var link: String = PLACES[key]["link"]
	var toward := _pos3(link) if PLACES.has(link) else _v3(CROSSINGS[link])
	return pos + (toward - pos).normalized() * (PLACES[key]["radius"] + 0.8)


## Ajoute une forme à la cité (dans le groupe en cours, ou dans « parent »).
## « glow » : elle brille (cercle d'invocation, sphère du laboratoire, feu de la forge...).
func _add(mesh: Mesh, color: Color, pos: Vector3, glow := false, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, glow)
	(parent if parent else current_group).add_child(node)
	return node


## Beaucoup de formes identiques d'un coup (arbres, créneaux, lampadaires) : plus léger pour le téléphone.
## « colors » : une couleur par forme (vide = « color » pour toutes).
func _multi(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], color: Color) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		if multimesh.use_colors:
			multimesh.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = multimesh.use_colors
	node.material_override = material
	city_root.add_child(node)
	return node


func _material(color: Color, glow: bool) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), glow]
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.7
	materials[key] = material
	return material


## Ajoute une forme avec un léger grain (voir _textured).
func _add_textured(mesh: Mesh, color: Color, pos: Vector3, grain: float) -> MeshInstance3D:
	var node := _add(mesh, color, pos)
	node.material_override = _textured(color, grain)
	return node


## Un matériau avec un léger grain (bruit), pour que les grands sols ne soient pas tout plats.
## « grain » : finesse du grain (par mètre).
func _textured(color: Color, grain: float) -> StandardMaterial3D:
	var key := "tex|%s|%s" % [color.to_html(), grain]
	if materials.has(key):
		return materials[key]
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, color.darkened(0.18))
	ramp.set_color(1, color.lightened(0.12))
	texture.color_ramp = ramp
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.95
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * grain
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


func _sphere(radius: float, segments := 16, rings := 8) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh
