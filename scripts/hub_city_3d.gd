class_name HubCity3D
extends SubViewportContainer
## Le hub en 3D (nouveaux visuels ; les anciens gardent le plan HubMap) : la cité volante, vue du
## dessus, posée sur un rocher qui flotte dans le néant (étoiles, brume cyan, rochers et cristaux
## en suspension, courants d'énergie). Style médiéval sombre ; les modèles sont dans CityModels.
## Disposition d'après le plan du manhwa : rempart à 12 pans, résidences sur toute la moitié ouest
## (rues en croix et en anneau), salle de combat au nord, grande place publique au nord-est face à
## la faille (une arche dans le rempart), laboratoire à l'est, terrain d'entraînement au sud-ouest,
## zone de débarquement au sud.
##
## Un bâtiment pas encore construit n'apparaît pas (on le voit en hologramme dans le menu
## Construction). Quand il est construit (payé, ou condition remplie comme le terrain
## d'entraînement), la caméra va vers lui et il monte du sol en hologramme cyan, des pixels
## scintillent, puis il devient solide. L'animation attend qu'aucune fenêtre ne couvre la cité.
##
## Les héros y vivent : ils suivent les rues jusqu'au terrain d'entraînement s'ils s'entraînent,
## jusqu'à leur bâtiment s'ils y sont assistants, et se promènent sinon (place, rues des résidences).
## Ceux qui partent (Tour, donjon journalier) passent la faille ; ceux qui reviennent arrivent par la
## zone de débarquement ; les nouveaux sortent de la salle d'invocation.
##
## Un doigt : déplacer la vue. Deux doigts (ou la molette) : zoomer. Toucher : un lieu ou un héros.

signal zone_pressed(zone: Dictionary)
signal hero_pressed(hero: Dictionary)
## L'animation de construction d'un lieu vient de se terminer (le tutoriel attend celle de la synthèse).
signal construction_finished(key: String)

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
## « building » : bâtiment à construire (GameData.BUILDINGS) ; « condition » : il apparaît tout seul
## quand la condition est remplie. Sans les deux, le lieu est là dès le début.
const PLACES := {
	"combat": {"name": "Salle de combat", "short": "Salle de combat", "pos": Vector2(-1, -17),
		"radius": 4.8, "link": "N", "height": 6.8},
	"synthese": {"name": "Chambre de synthèse", "short": "Synthèse", "pos": Vector2(-11, -16),
		"radius": 3.4, "link": "NW", "height": 7.5, "building": "synthese"},
	"armory": {"name": "Armurerie", "short": "Armurerie", "pos": Vector2(5, -13),
		"radius": 2.8, "link": "N", "height": 7.0},
	"forge": {"name": "Forge", "short": "Forge", "pos": Vector2(10, -17),
		"radius": 2.2, "link": "NE", "height": 5.2, "building": "forge"},
	"plaza": {"name": "Place publique", "short": "Place publique", "pos": Vector2(13, -8),
		"radius": 6.0, "link": "NE", "height": 3.8, "open": true},
	"faille": {"name": "Faille spatio-temporelle", "short": "Faille", "pos": Vector2(19.8, -11.4),
		"radius": 2.8, "link": "plaza", "height": 9.5},
	"atelier_magie": {"name": "Atelier de magie", "short": "Atelier de magie", "pos": Vector2(20.5, -1),
		"radius": 2.4, "link": "E", "height": 10.8, "building": "atelier_magie"},
	"lab": {"name": "Laboratoire d'alchimie", "short": "Laboratoire", "pos": Vector2(14.5, 4),
		"radius": 3.6, "link": "E", "height": 8.8, "building": "laboratoire"},
	"bibliotheque": {"name": "Bibliothèque", "short": "Bibliothèque", "pos": Vector2(17, 12),
		"radius": 2.8, "link": "SE", "height": 8.2, "building": "bibliotheque"},
	"summon": {"name": "Salle d'invocation", "short": "Invocation", "pos": Vector2(9, 17.5),
		"radius": 3.4, "link": "SE", "height": 5.6},
	"landing": {"name": "Zone de débarquement", "short": "Débarquement", "pos": Vector2(1, 19.5),
		"radius": 3.5, "link": "S", "height": 1.8, "open": true},
	"training": {"name": "Terrain d'entraînement", "short": "Entraînement", "pos": Vector2(-13, 12.5),
		"radius": 4.6, "link": "SW", "height": 2.0, "open": true, "condition": "training"},
	"residences": {"name": "Résidences", "short": "Résidences", "pos": Vector2(-15, -4),
		"radius": 4.0, "link": "W", "height": 5.0, "open": true},
}
## Bâtiment (lieu de la cité) de chaque poste d'assistant (hero["post"]).
const POST_PLACES := {"synthese": "synthese", "forge": "forge", "atelier_magie": "atelier_magie",
	"laboratoire": "lab", "bibliotheque": "bibliotheque"}
## Où les héros sans occupation vont se promener (la place et les rues reviennent plus souvent).
const IDLE_PLACES := ["plaza", "plaza", "streets", "streets", "streets", "center"]

# --- Couleurs ---

const GROUND_COLOR := Color("5b5d63")
const ROAD_COLOR := Color("8e857c")
const GRASS_COLOR := Color("34492f")
const ROCK_COLOR := Color("4b4a52")
const MIST_COLOR := Color(0.38, 0.9, 1.0, 0.035)
const HOUSE_ROOFS := [CityModels.SLATE, CityModels.RED_ROOF, Color("4a3b33"), Color("2f3a4a")]

## Le ciel du néant : presque noir, des nappes de brume cyan et violette, des étoiles.
const VOID_SHADER := """
shader_type sky;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 color = mix(vec3(0.008, 0.016, 0.03), vec3(0.03, 0.07, 0.09), smoothstep(-0.9, 0.6, d.y));
	color += vec3(0.04, 0.2, 0.24) * pow(fbm(d * 3.0 + vec3(TIME * 0.01, 0.0, 0.0)), 3.0) * 1.6;
	color += vec3(0.16, 0.05, 0.24) * pow(fbm(d * 2.2 + vec3(7.0)), 4.0) * 1.6;
	float star = hash(floor(d * 260.0));
	if (star > 0.9972) {
		color += vec3(0.75, 0.88, 1.0) * (star - 0.9972) * 360.0;
	}
	COLOR = color;
}
"""

# --- Héros ---

## Au plus ce nombre de héros dans la cité (pour que le téléphone suive).
const MAX_WALKERS := 60
const WALK_SPEED := 2.6
const BODY_Y := 0.75
## Les noms des héros ne s'affichent que si la caméra est assez près.
const NAME_DISTANCE := 34.0

# --- Caméra ---

const PITCH := deg_to_rad(60.0)
const MIN_DISTANCE := 14.0
const MAX_DISTANCE := 80.0
## Un appui qui bouge de plus de ça (pixels) devient un glissement, pas un toucher.
const TAP_THRESHOLD := 12.0
## Les héros sont mis à jour (activités, arrivées, départs) à cet intervalle (secondes).
const REFRESH_SECONDS := 1.5
## Durée de l'animation de construction (secondes).
const BUILD_SECONDS := 2.8

## Vrai pendant qu'une fenêtre de notification couvre l'écran (main.gd) : les animations attendent.
static var paused := false
## Vrai pendant qu'une fenêtre du hub est ouverte (construction, affectations...) : idem.
var hold := false

var viewport: SubViewport
var camera: Camera3D
var city_root: Node3D
var walkers_root: Node3D
## Ce qui tourne lentement autour de la cité (rochers, courants d'énergie).
var orbit: Node3D
var models := CityModels.new()

var cam_target := Vector3(0, 0, 1)
var cam_distance := 60.0

## Héros en promenade : {"hero", "node", "body", "label", "path": [Vector3], "state", "activity",
## "area", "wait", "phase", "spot"}.
var walkers: Array[Dictionary] = []
## Numéros des héros déjà vus : un héros inconnu vient d'être invoqué (il sort de la salle d'invocation).
var known_ids := {}
var first_refresh := true
var refresh_timer := 0.0
## Les lieux construits au dernier passage (pour reconnaître une nouvelle construction).
var built_places: Array = []
var city_built := false
## Les constructions qui attendent leur animation (lieux).
var pending_constructions: Array[String] = []
var animating := false

## Le chemin des héros : les carrefours et les portes des lieux (AStar3D trouve le trajet par les rues).
var astar := AStar3D.new()
var door_ids := {}
## Des points le long des rues des résidences, pour s'y promener.
var street_spots: Array[Vector3] = []
## Rues tracées (segments 2D), pour placer maisons et arbres à côté.
var road_segments: Array = []
## Le groupe de formes de chaque lieu (pour l'animation de construction).
var place_groups := {}
var portal_material: StandardMaterial3D

## Les noms affichés par-dessus la 3D, et ceux des lieux : [Label, point de la cité, lieu].
var overlay: Control
var place_labels: Array = []
## Tutoriel : la flèche « Touche ici » au-dessus de la chambre de synthèse (voir _place_tutorial_pointer).
var tutorial_pointer: Label

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

	# L'ambiance : le crépuscule dans le néant, lumière froide, brume cyan.
	var sky_material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = VOID_SHADER
	sky_material.shader = shader
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6c7fa3")
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("1f3a46")
	environment.fog_density = 0.004
	environment.fog_sky_affect = 0.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.02
	environment.glow_hdr_threshold = 0.9
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.1
	environment.adjustment_contrast = 1.08
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(deg_to_rad(-52), deg_to_rad(38), 0)
	moon.light_color = Color("d6defa")
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.shadow_opacity = 0.8
	moon.directional_shadow_max_distance = 140.0
	viewport.add_child(moon)

	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH  # toute la largeur de la cité tient dans l'écran
	camera.fov = 54.0
	camera.far = 400.0
	viewport.add_child(camera)

	city_root = Node3D.new()
	viewport.add_child(city_root)
	orbit = Node3D.new()
	viewport.add_child(orbit)
	walkers_root = Node3D.new()
	viewport.add_child(walkers_root)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(overlay)

	_build_paths()
	_build_void()
	_update_camera()


func _ready() -> void:
	_update_city()
	_refresh_walkers()
	GameData.lobby_updated.connect(_refresh_walkers)
	GameData.training_updated.connect(_refresh_walkers)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	refresh_timer += delta
	if refresh_timer >= REFRESH_SECONDS:
		refresh_timer = 0.0
		_update_city()
		_refresh_walkers()
	if not pending_constructions.is_empty() and not animating and not hold and not paused:
		_play_construction(pending_constructions.pop_front())
	for walker in walkers.duplicate():
		_animate_walker(walker, delta)
	orbit.rotation.y += delta * 0.015
	if portal_material:
		portal_material.emission_energy_multiplier = 1.2 + sin(Time.get_ticks_msec() / 420.0) * 0.5
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

## Vrai si le lieu est dans la cité (construit, ou sa condition remplie).
func _is_built(key: String) -> bool:
	var place: Dictionary = PLACES[key]
	if place.has("building"):
		return place["building"] in GameData.buildings
	if place.get("condition", "") == "training":
		return GameData.training_unlocked()
	return true


## Construit la cité au premier passage, puis ajoute les nouveaux bâtiments (avec animation).
func _update_city() -> void:
	var built: Array = PLACES.keys().filter(_is_built)
	if not city_built:
		# Tutoriel : la chambre de synthèse vient d'être construite (étage 1 conquis) et le Maître n'a pas
		# encore vu sa fenêtre : on la laisse hors de la cité, elle sera construite sous ses yeux (animation).
		if GameData.tutorial_step == "synthese" and not "tuto_synthese" in GameData.seen_tips:
			built.erase("synthese")
		city_built = true
		built_places = built
		_build_city()
		return
	for key in built:
		if key in built_places:
			continue
		built_places.append(key)
		_build_place(key)
		place_groups[key].visible = false  # caché jusqu'à son animation
		pending_constructions.append(key)


func _build_city() -> void:
	_build_island()
	_build_wall()
	_build_streets()
	for key in PLACES:
		if key in built_places:
			_build_place(key)
	_build_houses()
	_build_trees()
	_build_lamps()


## Le modèle d'un lieu (CityModels), posé à sa place et tourné vers sa rue, et son nom.
func _build_place(key: String) -> void:
	var group := Node3D.new()
	group.position = _pos3(key)
	if not PLACES[key].get("open", false):
		var toward := _door(key) - _pos3(key)
		group.rotation.y = atan2(toward.x, toward.z)  # la porte (+Z du modèle) face à la rue
	city_root.add_child(group)
	place_groups[key] = group
	models.build(key, group)
	var portal := group.find_child("Portal", true, false) as MeshInstance3D
	if portal:  # la faille palpite
		portal_material = portal.material_override.duplicate() as StandardMaterial3D
		portal.material_override = portal_material
	if key == "residences":
		return  # le quartier est fait des maisons (_build_houses) ; son nom suffit
	var place: Dictionary = PLACES[key]
	var label := _make_label(place["short"], 17, Color.WHITE)
	place_labels.append([label, _pos3(key) + Vector3(0, place["height"], 0), key])


## Le sol de la cité et le rocher qui la porte, avec ses racines et ses cristaux.
func _build_island() -> void:
	var ground := models.add(CityModels.cylinder(CITY_RADIUS, CITY_RADIUS, 0.3, WALL_SIDES),
		models.mat("cobbles", GROUND_COLOR), Vector3(0, -0.15, 0), city_root)
	ground.name = "Ground"
	models.add(CityModels.cylinder(CITY_RADIUS + 1.2, CITY_RADIUS + 0.4, 2.0, WALL_SIDES * 2),
		models.mat("rock", ROCK_COLOR), Vector3(0, -1.32, 0), city_root)
	models.add(CityModels.cylinder(CITY_RADIUS + 0.4, 4.0, 22.0, 18), models.mat("rock", ROCK_COLOR),
		Vector3(0, -13.3, 0), city_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 9:  # des pointes de roche sous le rocher
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(4.0, 16.0)
		var length := rng.randf_range(8.0, 16.0)
		var spike := models.add(CityModels.cylinder(rng.randf_range(3.0, 5.0), 0.3, length, 7),
			models.mat("rock", ROCK_COLOR.darkened(0.1)), Vector3(cos(angle) * dist, -length / 2.0 - 4.0, sin(angle) * dist), city_root)
		spike.rotation.y = rng.randf() * TAU
	for i in 14:  # les cristaux cyan qui sortent de la roche
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(CITY_RADIUS - 6.0, CITY_RADIUS)
		var crystal := models.add(CityModels.cylinder(0.0, rng.randf_range(0.4, 0.8), rng.randf_range(2.0, 4.0), 5),
			models.glow(CityModels.CYAN, 1.6), Vector3(cos(angle) * dist, rng.randf_range(-7.0, -2.5), sin(angle) * dist), city_root)
		crystal.rotation = Vector3(rng.randf_range(2.2, 3.0), angle, 0)  # pointés vers le bas et dehors
	for i in 22:  # des racines qui pendent du bord
		var angle := rng.randf() * TAU
		var length := rng.randf_range(2.0, 6.0)
		var root := models.add(CityModels.cylinder(0.12, 0.04, length, 5), models.mat("wood", Color("2e2219")),
			Vector3(cos(angle), 0, sin(angle)) * (CITY_RADIUS + 0.9) + Vector3(0, -2.0 - length / 2.0, 0), city_root)
		root.rotation.z = rng.randf_range(-0.2, 0.2)
	# De la verdure sombre dans les résidences.
	for patch in [Vector3(-14, 0, -8), Vector3(-17, 0, 4), Vector3(-6, 0, 4), Vector3(-5, 0, -13), Vector3(-19, 0, -2)]:
		models.add(CityModels.cylinder(4.3, 4.3, 0.05, 20), models.mat("grass", GRASS_COLOR), patch + Vector3(0, 0.02, 0), city_root)


## Le néant autour de la cité : des rochers et des cristaux en suspension, des courants d'énergie.
func _build_void() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 18:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(CITY_RADIUS + 8.0, CITY_RADIUS + 45.0)
		var rock := Node3D.new()
		rock.position = Vector3(cos(angle) * dist, rng.randf_range(-22.0, 6.0), sin(angle) * dist)
		rock.rotation.y = rng.randf() * TAU
		orbit.add_child(rock)
		var size := rng.randf_range(1.2, 4.0)
		var top := models.add(CityModels.sphere(size, 7, 4), models.mat("rock", ROCK_COLOR), Vector3.ZERO, rock)
		top.scale = Vector3(1.0, 0.45, rng.randf_range(0.7, 1.2))
		models.add(CityModels.cylinder(size * 0.8, 0.1, size * 1.8, 6), models.mat("rock", ROCK_COLOR.darkened(0.15)),
			Vector3(0, -size * 0.9, 0), rock)
		if rng.randf() < 0.5:
			models.add(CityModels.cylinder(0.0, size * 0.25, size * 1.1, 5), models.glow(CityModels.CYAN, 1.6),
				Vector3(size * 0.2, size * 0.5, 0), rock)
		elif rng.randf() < 0.6:
			models.add(CityModels.sphere(size * 0.6, 7, 4), models.mat("plain", Color("23392a")), Vector3(0, size * 0.4, 0), rock)
	# Les courants d'énergie : de grands anneaux de brume cyan, inclinés, qui tournent.
	var mist := StandardMaterial3D.new()
	mist.albedo_color = MIST_COLOR
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.cull_mode = BaseMaterial3D.CULL_DISABLED
	var streak := mist.duplicate() as StandardMaterial3D
	streak.albedo_color = Color(MIST_COLOR, 0.12)
	for i in 6:  # chaque courant : deux anneaux, un large et pâle, un fin et plus vif
		var ring := TorusMesh.new()
		var radius := 36.0 + (i / 2) * 7.0
		var width := 2.4 if i % 2 == 0 else 0.5
		ring.inner_radius = radius - width
		ring.outer_radius = radius + width
		ring.rings = 96
		var node := MeshInstance3D.new()
		node.mesh = ring
		node.material_override = mist if i % 2 == 0 else streak
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var current := i / 2
		node.rotation = Vector3(0.25 - current * 0.18, current * 1.3, 0.12 * current)
		node.position.y = -6.0 + current * 3.0
		orbit.add_child(node)


## Le rempart à pans, en grosses pierres, avec des créneaux et des tours au toit pointu.
func _build_wall() -> void:
	var side := 2.0 * CITY_RADIUS * sin(PI / WALL_SIDES)
	var merlons: Array[Transform3D] = []
	for i in WALL_SIDES:
		var a := TAU * i / WALL_SIDES
		var b := TAU * (i + 1) / WALL_SIDES
		var corner_a := Vector3(cos(a), 0, sin(a)) * CITY_RADIUS
		var corner_b := Vector3(cos(b), 0, sin(b)) * CITY_RADIUS
		var angle := atan2(corner_b.x - corner_a.x, corner_b.z - corner_a.z)
		var segment := models.add(CityModels.box(Vector3(1.8, 3.8, side)), models.mat("stone", CityModels.STONE),
			(corner_a + corner_b) * 0.5 + Vector3(0, 1.9, 0), city_root)
		segment.rotation.y = angle
		var count := int(side / 1.5)
		for m in count:
			var point := corner_a.lerp(corner_b, (m + 0.5) / count)
			merlons.append(Transform3D(Basis(Vector3.UP, angle), point + Vector3(0, 4.15, 0)))
		var tower := models.add(CityModels.box(Vector3(3.0, 6.0, 3.0)), models.mat("stone", CityModels.DARK_STONE),
			corner_a + Vector3(0, 3.0, 0), city_root)
		tower.rotation.y = -a
		var roof := models.add(CityModels.cylinder(0.0, 2.4, 3.2, 4), models.mat("roof", CityModels.SLATE),
			corner_a + Vector3(0, 7.6, 0), city_root)
		roof.rotation.y = -a + PI / 4.0
		models.add(CityModels.box(Vector3(0.25, 0.7, 0.08)), models.glow(CityModels.WINDOW, 1.2),
			corner_a * 0.94 + Vector3(0, 4.2, 0), city_root).look_at_from_position(corner_a * 0.94 + Vector3(0, 4.2, 0), Vector3(0, 4.2, 0))
	_multi(CityModels.box(Vector3(1.6, 0.8, 0.75)), merlons, [], models.mat("stone", CityModels.STONE))


func _build_streets() -> void:
	models.add(CityModels.cylinder(3.0, 3.0, 0.08, 24), models.mat("cobbles", ROAD_COLOR.lightened(0.08)), Vector3(0, 0.03, 0), city_root)
	for street in STREETS:
		_road(_v3(CROSSINGS[street[0]]), _v3(CROSSINGS[street[1]]), 2.8)
	for key in PLACES:
		var link: String = PLACES[key]["link"]
		var to := _pos3(link) if PLACES.has(link) else _v3(CROSSINGS[link])
		_road(_door(key), to, 1.9)


func _road(from: Vector3, to: Vector3, width: float) -> void:
	var length := from.distance_to(to)
	if length < 0.3:
		return
	var road := models.add(CityModels.box(Vector3(width, 0.07, length + width * 0.5)), models.mat("cobbles", ROAD_COLOR),
		(from + to) / 2.0 + Vector3(0, 0.035, 0), city_root)
	road.rotation.y = atan2(to.x - from.x, to.z - from.z)
	road_segments.append([Vector2(from.x, from.z), Vector2(to.x, to.z)])


## Les maisons à colombages des résidences, le long des rues de l'ouest.
func _build_houses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # toujours les mêmes maisons
	var placed: Array[Vector2] = []
	var first := true
	for x in range(-23, 1, 4):
		for z in range(-15, 12, 4):
			var spot := Vector2(x + rng.randf_range(-0.8, 0.8), z + rng.randf_range(-0.8, 0.8))
			if spot.length() > CITY_RADIUS - 4.5 or not _free_spot(spot, 2.4, 2.4):
				continue
			placed.append(spot)
			var group := Node3D.new()
			group.position = Vector3(spot.x, 0, spot.y)
			group.rotation.y = [0.0, PI / 2.0, PI, -PI / 2.0][rng.randi() % 4]
			city_root.add_child(group)
			var size := Vector3(rng.randf_range(2.4, 3.2), rng.randf_range(2.6, 3.4), rng.randf_range(2.2, 2.8))
			var roof: Color = HOUSE_ROOFS[rng.randi() % HOUSE_ROOFS.size()]
			if first:
				roof = Color("8e2a22")  # la maison rouge du Maître, comme sur le plan
				first = false
			models.house(group, size, roof, rng.randf() < 0.6)
	set_meta("houses", placed)


## Des arbres sombres dans la cité (entre les maisons, le long du rempart).
func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var houses: Array = get_meta("houses", [])
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var colors: Array[Color] = []
	var planted := 0
	var tries := 0
	while planted < 55 and tries < 900:
		tries += 1
		var spot := Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24))
		if spot.length() > CITY_RADIUS - 3.2 or not _free_spot(spot, 1.7, 1.5):
			continue
		var crowded := false
		for house in houses:
			if spot.distance_to(house) < 2.7:
				crowded = true
				break
		if crowded:
			continue
		planted += 1
		var size := rng.randf_range(0.8, 1.2)
		var base := Vector3(spot.x, 0, spot.y)
		trunks.append(Transform3D(Basis.from_scale(Vector3.ONE * size), base + Vector3(0, 0.7 * size, 0)))
		for blob in 2:
			var offset := Vector3(rng.randf_range(-0.4, 0.4), 1.9 + blob * 0.8, rng.randf_range(-0.4, 0.4)) * size
			var radius := (1.15 - blob * 0.3) * size
			crowns.append(Transform3D(Basis.from_scale(Vector3(radius, radius * 0.9, radius)), base + offset))
			colors.append(Color("1f3a26").lerp(Color("35573a"), rng.randf()))
	_multi(CityModels.cylinder(0.16, 0.24, 1.4, 6), trunks, [], models.mat("wood", Color("3b2a1f")))
	var leaves := StandardMaterial3D.new()
	leaves.vertex_color_use_as_albedo = true
	leaves.roughness = 1.0
	_multi(CityModels.sphere(1.0, 8, 5), crowns, colors, leaves)


## Des lanternes le long des grandes rues (leur lumière chaude brille dans le soir).
func _build_lamps() -> void:
	var posts: Array[Transform3D] = []
	var bulbs: Array[Transform3D] = []
	for street in STREETS:
		var a := _v3(CROSSINGS[street[0]])
		var b := _v3(CROSSINGS[street[1]])
		var side := (b - a).normalized().cross(Vector3.UP) * 1.7
		var count := int(a.distance_to(b) / 5.0)
		for i in count:
			var point := a.lerp(b, (i + 0.5) / count) + (side if i % 2 == 0 else -side)
			posts.append(Transform3D(Basis(), point + Vector3(0, 1.1, 0)))
			bulbs.append(Transform3D(Basis(), point + Vector3(0, 2.3, 0)))
	_multi(CityModels.cylinder(0.06, 0.09, 2.2, 6), posts, [], models.mat("plain", Color("1f2024")))
	_multi(CityModels.box(Vector3(0.28, 0.36, 0.28)), bulbs, [], models.glow(CityModels.WINDOW, 2.2))


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
	return spot.length() > 3.8  # pas sur la place du carrefour


## Animation de construction : la caméra va vers le bâtiment, qui monte du sol en hologramme cyan
## pendant que des pixels scintillent autour, puis devient solide.
func _play_construction(key: String) -> void:
	var group: Node3D = place_groups.get(key)
	if group == null:
		return
	animating = true
	var center := _pos3(key)
	var look := create_tween().set_parallel()
	look.tween_property(self, "cam_target", center, 0.8).set_trans(Tween.TRANS_SINE)
	look.tween_property(self, "cam_distance", 30.0, 0.8).set_trans(Tween.TRANS_SINE)
	look.tween_method(func(_value): _update_camera(), 0.0, 1.0, 0.8)
	await look.finished

	var originals := {}
	for node in group.find_children("*", "MeshInstance3D", true, false):
		originals[node] = node.material_override
		node.material_override = models.holo_material()
	group.visible = true
	group.scale = Vector3(1.0, 0.02, 1.0)
	var rise := create_tween()
	rise.tween_property(group, "scale:y", 1.0, BUILD_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.tween_interval(0.3)
	rise.tween_callback(func():
		for node in originals:
			if is_instance_valid(node):
				node.material_override = originals[node]
		animating = false
		construction_finished.emit(key))
	# Les pixels de l'hologramme, qui apparaissent et disparaissent.
	var radius: float = PLACES[key]["radius"]
	for i in 34:
		var pixel := models.add(CityModels.box(Vector3.ONE * randf_range(0.2, 0.7)), models.holo_material(),
			center + Vector3(randf_range(-radius, radius), randf_range(0.3, 6.0), randf_range(-radius, radius)), city_root)
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
	models.add(capsule, models.mat("plain", color), Vector3.ZERO, body)
	models.add(CityModels.sphere(0.28, 12, 6), models.mat("plain", Color("e8c4a0")), Vector3(0, 0.88, 0), body)
	if hero["class"] == "Mage":  # un chapeau pointu pour reconnaître les mages
		models.add(CityModels.cylinder(0.0, 0.34, 0.6, 10), models.mat("plain", Color("3a2e7a")), Vector3(0, 1.3, 0), body)
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
		var index := _rank_among(walker, "train") % CityModels.DUMMIES.size()
		var dummy: Vector2 = CityModels.DUMMIES[index]
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
	var radius: float = 2.4 if area == "center" else PLACES[area]["radius"] - 1.0
	var angle := randf() * TAU
	var dist := sqrt(randf()) * radius
	if area == "plaza":
		dist = randf_range(2.9, radius)  # pas dans la fontaine
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


## Un toucher : d'abord un héros (s'il y en a un sous le doigt), sinon un lieu construit.
func _tap(screen_pos: Vector2) -> void:
	var best_walker: Dictionary = {}
	var best := 34.0
	for walker in walkers:
		# Tutoriel : on vise la chambre de synthèse, un héros qui passe devant ne doit pas prendre le toucher.
		if GameData.tutorial_step != "":
			break
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
	for key in built_places:
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
			var target := "forge" if id == "forge" else ""
			return {"name": place_name, "target": target, "info": building["info"]}
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
## Le nom d'un bâtiment qui attend son animation reste caché.
func _place_labels() -> void:
	for entry in place_labels:
		_stick_label(entry[0], entry[1])
		if entry[2] in pending_constructions or not place_groups[entry[2]].visible:
			entry[0].visible = false
	_place_tutorial_pointer()
	var show_names := cam_distance < NAME_DISTANCE
	for walker in walkers:
		var label: Label = walker["label"]
		label.visible = show_names
		if show_names:
			_stick_label(label, walker["node"].position + Vector3(0, 2.2, 0))


## Tutoriel (étape synthèse) : une flèche dorée qui sautille au-dessus de la chambre de synthèse, une fois
## son animation de construction finie, pour montrer où toucher.
func _place_tutorial_pointer() -> void:
	var show: bool = GameData.tutorial_step == "synthese" and "synthese" in built_places \
		and not "synthese" in pending_constructions and not animating
	if not show:
		if tutorial_pointer:
			tutorial_pointer.visible = false
		return
	if tutorial_pointer == null:
		tutorial_pointer = _make_label("Touche ici\n▼", 30, Color("f5c542"))
	var bounce := sin(Time.get_ticks_msec() / 180.0) * 0.6
	_stick_label(tutorial_pointer, _pos3("synthese") + Vector3(0, PLACES["synthese"]["height"] + 2.5 + bounce, 0))


func _stick_label(label: Label, point: Vector3) -> void:
	label.visible = not camera.is_position_behind(point)
	if not label.visible:
		return
	label.reset_size()
	label.position = camera.unproject_position(point) - Vector2(label.size.x / 2.0, label.size.y)


# ---------------------------------------------------------------------------
# Petits outils
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


## Beaucoup de formes identiques d'un coup (arbres, créneaux, lanternes) : plus léger pour le téléphone.
## « colors » : une couleur par forme (vide = la couleur du matériau pour toutes).
func _multi(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], material: Material) -> MultiMeshInstance3D:
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
	node.material_override = material
	city_root.add_child(node)
	return node
