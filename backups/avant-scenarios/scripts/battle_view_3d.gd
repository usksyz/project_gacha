class_name BattleView3D
extends Control
## Le champ de bataille en vue isométrique semi-3D (cahier, onglet « Combat v2 », sections 1 et 9 : étape C2).
## La simulation ne change pas (battle.gd, BattleMap, MapGenerator) : cette vue ne fait que la montrer. Elle
## est la seule carte du combat dans BattleView (la vue de dessus est retirée), qui garde tout le reste : titre,
## chrono, barre du boss, encart de l'équipe, journal, boutons d'ordres, fenêtres système.
## - La carte : une colonne de blocs par case (hauteur 0 à 4 niveaux, BattleMap.heights), couleur selon son
##   type (BattleMap.kinds) et le gabarit de la carte (village, prairie, ville en ruine, cité...), en
##   MultiMesh ; les décors de MapGenerator (« structures » : arbres, maisons, clocher...) ont leur forme.
## - La caméra : orthographique (pas de perspective, les distances restent lisibles), inclinée de PITCH_DEG
##   vers le bas et tournée de 45° ; un bouton la tourne de 90°.
## - Les combattants : des formes simples (corps selon la classe, tête selon le camp), une ombre au sol.
## - Par-dessus, en 2D (overlay) : barres de vie et d'endurance, étiquettes (PEUR, REPOS, AGONIE...), noms,
##   chiffres des coups, traits des tirs, ordres en cours.
## - Les murs et toits devant le héros choisi deviennent transparents.
## Gestes : un doigt déplace la caméra ; deux doigts (ou la molette) zooment ; un toucher (sans glisser)
## choisit un héros ou donne un ordre : le signal « tapped » renvoie le combattant touché, ou la case touchée
## par lancer de rayon (le niveau compte : le toit plutôt que la rue en dessous). BattleView décide de l'ordre.

## Un toucher : le combattant touché ({} s'il n'y en a pas), le point de la carte (en cases) et s'il est dedans.
signal tapped(unit: Dictionary, map_pos: Vector2, inside: bool)

## Hauteur d'un niveau de case (en largeurs de case) : un étage de maison.
const LEVEL := 0.8
## Épaisseur du sol sous la carte (le socle).
const BASE_DEPTH := 0.6
## Caméra : inclinaison vers le bas et angle de côté (cahier : environ 35° et 45°), zoom (largeur vue, en cases).
const PITCH_DEG := 35.0
const YAW_DEG := 45.0
const ZOOM_DEFAULT := 21.0
const ZOOM_MIN := 7.0
const ZOOM_MAX := 34.0
const CAMERA_DISTANCE := 40.0
## Un doigt qui glisse de plus que ceci (pixels) déplace la caméra au lieu de toucher.
const TAP_THRESHOLD := 14.0
## Distance (pixels, au zoom par défaut) à laquelle un toucher « attrape » un combattant.
const TAP_RADIUS_PX := 34.0
## Transparence des murs et toits devant le héros choisi, et fréquence du calcul (secondes).
const FADED_ALPHA := 0.22
const FADE_REFRESH := 0.15
## Personnages.
const BODY_RADIUS := 0.27
const BODY_HEIGHT := 0.85
const HEAD_RADIUS := 0.19
const BOSS_SCALE := 1.4
## Vitesse à laquelle un combattant monte ou descend à l'écran (niveaux par seconde) : on le voit grimper.
const CLIMB_DISPLAY_SPEED := 3.0
## Réglages de performance (cahier : 30 images par seconde sur téléphone). À changer ici s'il le faut :
## ombres du soleil, anticrénelage, résolution de l'écran 3D (2 = moitié).
const SHADOWS := true
const MSAA := Viewport.MSAA_2X
const RENDER_SHRINK := 1

## Couleurs par gabarit (MapGenerator.template_for) : sol, sol alterné, bloc, toit, pente, pierre ; murs des maisons
## et route (cartes, étape 2 ; absents : le bloc, ROAD_COLOR).
const PALETTES := {
	"village": {"ground": Color("56683a"), "ground2": Color("4e6034"), "block": Color("8a6a4c"), "roof": Color("9a5038"),
		"slope": Color("6a7a40"), "stone": Color("7a7468"), "wall": Color("d6c8a4"), "road": Color("8f7752")},
	"prairie": {"ground": Color("5f8a3e"), "ground2": Color("578238"), "block": Color("3f6a2a"), "roof": Color("9a5038"),
		"slope": Color("74963e"), "stone": Color("80807a"), "wall": Color("cfc0a0")},
	"foret": {"ground": Color("3f5a2e"), "ground2": Color("39532a"), "block": Color("3a5a28"), "roof": Color("8a4c36"),
		"slope": Color("4c6634"), "stone": Color("6e6e66"), "road": Color("6e5a3c")},
	"relief": {"ground": Color("6e6446"), "ground2": Color("665c40"), "block": Color("6a6258"), "roof": Color("8a4c36"),
		"slope": Color("7c7050"), "stone": Color("7e7a72")},
	"ville": {"ground": Color("5e5a54"), "ground2": Color("56524c"), "block": Color("5a4e46"), "roof": Color("8a4434"),
		"slope": Color("6a645a"), "stone": Color("6e6a64"), "wall": Color("8a7e6e")},
	"cite": {"ground": Color("66604e"), "ground2": Color("5e5848"), "block": Color("5a4128"), "roof": Color("8a4434"),
		"slope": Color("7a7464"), "stone": Color("8a8e96")},
	"arene": {"ground": Color("a08e64"), "ground2": Color("98865e"), "block": Color("7a6a4a"), "roof": Color("8a4434"),
		"slope": Color("a89870"), "stone": Color("8a8478")},
}
const LADDER_COLOR := Color("c99a5b")
const BELL_COLOR := Color("d8b04a")
const GRASS_COLOR := Color("7ea84a")
const FOLIAGE_COLOR := Color("355e26")
const TRUNK_COLOR := Color("5a3e26")
## (cartes, étape 2) La route de terre et le sentier.
const ROAD_COLOR := Color("8a7350")
## (point 8) La toile des tentes et le feu de camp.
const TENT_COLOR := Color("b49a6a")
const FIRE_COLOR := Color("ff9a3a")
const HERO_COLOR := Color("4caf6a")
const ENEMY_COLOR := Color("e05252")
const BOSS_COLOR := Color("8a3aa8")
const ORDER_COLOR := Color("f5d142")
## Couleur du corps selon la classe (héros et monstres) ; les autres : gris.
const CLASS_COLORS := {
	"Novice": Color("b8a78a"), "Apprenti guerrier": Color("a0a8b4"), "Apprenti voleur": Color("6a7a5a"),
	"Guerrier": Color("8c96a6"), "Chevalier": Color("c8d0dc"), "Archer": Color("4f8a3a"), "Assassin": Color("4a3a5a"),
	"Mage": Color("4a6ad0"), "Soigneur": Color("e8e4d8"),
}
const STAMINA_COLOR := Color("e8c547")
const STAMINA_TIRED_COLOR := Color("7a7466")
## Perception (C3) : un ennemi que personne ne voit (corps et anneau gris).
const UNSEEN_COLOR := Color("5c5c66")
const STRIKE_TIME := 0.25
const FLOAT_TIME := 0.9
const BUBBLE_TIME := 1.5
## Brouillard de guerre (cartes, étape 4 ; demande du porteur du projet : « noir là où les héros n'ont jamais vu, puis
## sombre si ce n'est plus dans leur champ de vision ») : lumière des cases jamais vues et déjà vues, rafraîchie
## toutes les FOG_REFRESH secondes ; autour d'un héros (FOG_AROUND cases), on voit toujours.
const FOG_UNSEEN := 0.12
const FOG_REMEMBERED := 0.5
const FOG_REFRESH := 0.2
const FOG_AROUND := 1.6

## Les formes de base (une MultiMesh opaque et une transparente pour chacune).
enum Shape {BOX, SPHERE, PRISM, CYLINDER, RAMP}

var view: BattleView
var battle: Battle
var container: SubViewportContainer
var viewport: SubViewport
var camera: Camera3D
var sun: DirectionalLight3D
var overlay: Control
var rotate_button: Button
var fps_label: Label
## (point 8) L'ambiance (assombrie la nuit) et la lumière du feu de camp.
var environment: Environment
var fire_light: OmniLight3D
## (point 9) Le calque de débogage montré (« » : aucun), ses valeurs par case et leur prochain calcul.
var layer_button: Button
var debug_layer := ""
var _layer_values := PackedFloat32Array()
var _layer_timer := 0.0

var cam_target := Vector3.ZERO
var zoom := ZOOM_DEFAULT
var turn := 0           # quart de tour de la caméra (0 à 3)
var yaw := YAW_DEG      # angle de côté affiché (glisse vers YAW_DEG + turn x 90)

## Les pièces du décor : {"cell": Vector2i, "shape": Shape, "xf": Transform3D, "color": Color, "solid": bool}
## (« solid » : un mur ou un toit qui peut cacher un héros, donc devenir transparent).
var parts: Array[Dictionary] = []
## Hauteur visible de chaque case (le haut de sa colonne, ou d'un décor plus haut : arbre, toit pointu).
var tops := PackedFloat32Array()
var opaque_mm := {}     # Shape → MultiMeshInstance3D
var faded_mm := {}
var faded_cells := {}   # Vector2i → vrai : cases rendues transparentes
var fade_timer := 0.0
var units_root: Node3D
var unit_nodes := {}    # numéro → {"root", "body", "head", "shadow", "ring", "halo", "body_mat", "head_mat"}
var display_y := {}     # numéro → hauteur affichée (glisse vers la vraie quand il monte ou descend)
## Brouillard de guerre (cartes, étape 4) : la lumière de chaque case (1 : vue en ce moment, FOG_REMEMBERED : déjà vue,
## FOG_UNSEEN : jamais vue), les cases déjà vues, et le prochain calcul. Pas de brouillard en duel.
var fog := PackedFloat32Array()
var seen_ever := PackedByteArray()
var fog_timer := 0.0
var fog_on := true

# Gestes.
var pressing := false
var moved := false
var press_pos := Vector2.ZERO
var touches := {}
var pinch_distance := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	container = SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = RENDER_SHRINK
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = MSAA
	container.add_child(viewport)

	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("12141c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8a94b0")
	environment.ambient_light_energy = 0.75
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)

	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-58), deg_to_rad(28), 0)
	sun.light_color = Color("fff1d8")
	sun.light_energy = 1.0
	sun.shadow_enabled = SHADOWS
	sun.shadow_opacity = 0.55
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	viewport.add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.near = 1.0
	camera.far = 120.0
	viewport.add_child(camera)

	units_root = Node3D.new()
	viewport.add_child(units_root)

	# Par-dessus la 3D : barres, étiquettes, chiffres (dessinés en 2D aux positions projetées).
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)

	rotate_button = UI.make_button("Tourner", _rotate_view, 18)
	rotate_button.custom_minimum_size = Vector2(110, 52)
	rotate_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rotate_button.offset_left = -118
	rotate_button.offset_right = -8
	rotate_button.offset_top = 8
	rotate_button.offset_bottom = 60
	add_child(rotate_button)
	# (Recensement « Techniques », point 9) Mode dev : les calques de débogage (regards, recherche, terrain).
	layer_button = UI.make_button("Calques", _next_layer, 16)
	layer_button.custom_minimum_size = Vector2(110, 44)
	layer_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	layer_button.offset_left = -118
	layer_button.offset_right = -8
	layer_button.offset_top = 66
	layer_button.offset_bottom = 110
	add_child(layer_button)

	# Mode dev : images par seconde.
	fps_label = UI.make_label("", 16)
	fps_label.position = Vector2(8, 8)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.add_theme_color_override("font_color", Color("9fe0a0"))
	add_child(fps_label)


## Prépare la vue pour ce combat (la carte ne change pas pendant le combat).
func setup(owner_view: BattleView) -> void:
	view = owner_view
	battle = owner_view.battle
	_apply_daylight()
	fog_on = not battle.quest.get("duel", false)
	fog = PackedFloat32Array()
	fog.resize(battle.map.kinds.size())
	fog.fill(FOG_UNSEEN if fog_on else 1.0)
	seen_ever = PackedByteArray()
	seen_ever.resize(battle.map.kinds.size())
	seen_ever.fill(0)
	fog_timer = 0.0
	_build_map()
	_build_units()
	cam_target = Vector3(Battle.GRID_W / 2.0, LEVEL * 0.5, Battle.GRID_H / 2.0)
	zoom = ZOOM_DEFAULT
	turn = 0
	yaw = YAW_DEG
	faded_cells.clear()
	_update_camera()


# ---------------------------------------------------------------------------
# La carte
# ---------------------------------------------------------------------------

func _palette() -> Dictionary:
	return PALETTES.get(battle.map_data.get("template", "relief"), PALETTES["relief"])


## Les décors de MapGenerator, par case : « trees », « house », « bell »... (« » si aucun).
func _structures_by_cell() -> Dictionary:
	var result := {}
	for structure in battle.map_data.get("structures", []):
		var rect: Rect2i = structure["rect"]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				result[Vector2i(x, y)] = structure
	return result


## Une petite variation de couleur propre à chaque case (toujours la même) : le sol n'est pas uni.
func _jitter(cell: Vector2i, color: Color, amount := 0.05) -> Color:
	var noise := float((cell.x * 73856093) ^ (cell.y * 19349663)) / 2147483647.0
	return color.lightened(fposmod(noise, 1.0) * amount)


func _add_part(cell: Vector2i, shape: int, center: Vector3, scale: Vector3, color: Color, solid := false,
		basis := Basis.IDENTITY) -> void:
	parts.append({"cell": cell, "shape": shape, "xf": Transform3D(basis.scaled(scale), center), "color": color, "solid": solid})


## Une colonne pleine de « bottom » à « top » (en hauteur monde) sur la case. Un mur (« solid ») garde un socle
## opaque sous le niveau du sol : quand il devient transparent devant le héros choisi, on voit le sol, pas le vide.
func _add_column(cell: Vector2i, bottom: float, top: float, color: Color, solid := false) -> void:
	if solid and bottom < 0.0 and top > 0.0:
		_add_part(cell, Shape.BOX, Vector3(cell.x + 0.5, bottom / 2.0, cell.y + 0.5), Vector3(1, -bottom, 1), color.darkened(0.2))
		bottom = 0.0
	_add_part(cell, Shape.BOX, Vector3(cell.x + 0.5, (bottom + top) / 2.0, cell.y + 0.5), Vector3(1, top - bottom, 1), color, solid)


func _build_map() -> void:
	parts.clear()
	var map: BattleMap = battle.map
	var palette := _palette()
	var structures := _structures_by_cell()
	var roads := {}
	for cell in battle.map_data.get("roads", []):
		roads[cell] = true
	var round_map: bool = battle.map_data.get("version", 1) >= 2  # (cartes, étape 2 : la lisière hors du disque)
	tops.resize(map.kinds.size())
	for i in map.kinds.size():
		var cell := map.cell_at(i)
		var kind := map.kinds[i]
		var h := map.heights[i]
		var top := h * LEVEL
		var structure: Dictionary = structures.get(cell, {})
		var ground: Color = palette["ground"] if (cell.x + cell.y) % 2 == 0 else palette["ground2"]
		ground = _jitter(cell, ground)
		if roads.has(cell):
			ground = _jitter(cell, palette.get("road", ROAD_COLOR), 0.08)
		tops[i] = top
		if round_map and not MapGenerator.inside(cell):
			_add_edge(cell, palette, i)
			continue
		if battle.alert != null and cell in battle.alert.tents:
			_add_tent(cell, top, i)
			continue
		if battle.alert != null and cell == battle.alert.fire:
			_add_column(cell, -BASE_DEPTH, top, ground)
			_add_fire(cell, top)
			continue
		match kind:
			BattleMap.Kind.GROUND:
				_add_column(cell, -BASE_DEPTH, top, ground)
			BattleMap.Kind.GRASS:
				_add_column(cell, -BASE_DEPTH, top, ground.lerp(GRASS_COLOR, 0.25))
				for k in 5:  # herbes hautes : des touffes
					var offset := Vector3(0.18 + 0.16 * k, 0.0, 0.25 + 0.5 * float(k % 2))
					_add_part(cell, Shape.BOX, Vector3(cell.x, top + 0.16, cell.y) + offset, Vector3(0.07, 0.32, 0.07),
						_jitter(cell + Vector2i(k, 0), GRASS_COLOR, 0.15))
			BattleMap.Kind.STAIRS:
				if structure.get("kind", "") == "stairs":  # escalier du rempart : des marches
					_add_column(cell, -BASE_DEPTH, top, _jitter(cell, palette["slope"]))
					for k in 3:
						_add_part(cell, Shape.BOX, Vector3(cell.x + 0.5, top + 0.05, cell.y + 0.2 + 0.3 * k),
							Vector3(0.9, 0.06, 0.08), palette["stone"].lightened(0.15))
				else:
					_add_slope(cell, top, roads.has(cell), ground, palette)
			BattleMap.Kind.LADDER:
				_add_column(cell, -BASE_DEPTH, top, ground)
				_add_ladder(cell, top)
			BattleMap.Kind.LOW_WALL:
				# Muret, clôture, barricade : un mur bas et mince (on peut l'enjamber), posé sur le terrain.
				var base: float = structure.get("base", 0) * LEVEL
				_add_column(cell, -BASE_DEPTH, base, ground)
				var fence: bool = structure.get("kind", "") == "fence"
				var wall_color: Color = TRUNK_COLOR.lightened(0.15) if fence else palette["stone"]
				if fence:  # une clôture de bois : des piquets et deux lisses
					for k in 2:
						_add_part(cell, Shape.BOX, Vector3(cell.x + 0.5, base + 0.18 + 0.22 * k, cell.y + 0.5), Vector3(1.0, 0.06, 0.06),
							_jitter(cell, wall_color), true)
					_add_part(cell, Shape.BOX, Vector3(cell.x + 0.5, base + 0.25, cell.y + 0.5), Vector3(0.09, 0.5, 0.09), wall_color.darkened(0.15), true)
				else:
					_add_part(cell, Shape.BOX, Vector3(cell.x + 0.5, (base + top) / 2.0, cell.y + 0.5), Vector3(1.0, top - base, 0.35),
						_jitter(cell, wall_color), true)
			BattleMap.Kind.ROCK:
				var base: float = maxf(0.0, top - LEVEL)
				_add_column(cell, -BASE_DEPTH, base + (top - base) * 0.8, _jitter(cell, palette["stone"], 0.08))
				_add_part(cell, Shape.SPHERE, Vector3(cell.x + 0.5, base + (top - base) * 0.8, cell.y + 0.5),
					Vector3(0.95, (top - base) * 0.45 + 0.05, 0.95), _jitter(cell, palette["stone"].lightened(0.08), 0.08), true)
			BattleMap.Kind.ROOF:
				# Toit où l'on marche (grange, toits de la ville) : murs, puis le toit plat en tuiles.
				_add_column(cell, -BASE_DEPTH, top - 0.08, _jitter(cell, palette.get("wall", palette["block"])), true)
				_add_part(cell, Shape.BOX, Vector3(cell.x + 0.5, top - 0.04, cell.y + 0.5), Vector3(1.0, 0.08, 1.0),
					_jitter(cell, palette["roof"], 0.08), true)
			BattleMap.Kind.RAMPART:
				_add_column(cell, -BASE_DEPTH, top, _jitter(cell, palette["stone"]), true)
				# Créneaux côté ennemis (le haut de la carte).
				for k in 2:
					_add_part(cell, Shape.BOX, Vector3(cell.x + 0.25 + 0.5 * k, top + 0.15, cell.y + 0.1),
						Vector3(0.3, 0.3, 0.2), palette["stone"].lightened(0.1), true)
			BattleMap.Kind.TOWER:
				# Le clocher : la tour, la cloche, un toit pointu.
				_add_column(cell, -BASE_DEPTH, top, _jitter(cell, palette["stone"]), true)
				_add_part(cell, Shape.SPHERE, Vector3(cell.x + 0.5, top + 0.25, cell.y + 0.5), Vector3(0.3, 0.3, 0.3), BELL_COLOR)
				_add_part(cell, Shape.PRISM, Vector3(cell.x + 0.5, top + 0.75, cell.y + 0.5), Vector3(1.0, 0.5, 1.0), palette["roof"], true)
				tops[i] = top + 1.0
			BattleMap.Kind.GATE:
				_add_column(cell, -BASE_DEPTH, top, _jitter(cell, palette["block"]), true)
			BattleMap.Kind.BLOCK:
				_add_block(cell, top, structure, palette, i)
			_:
				_add_column(cell, -BASE_DEPTH, top, ground)
	_build_multimeshes()


## Une pente douce (cartes, étape 2) : le terrain du niveau d'en dessous, puis une rampe qui descend vers la voisine la
## plus basse.
func _add_slope(cell: Vector2i, top: float, road: bool, ground: Color, palette: Dictionary) -> void:
	var map: BattleMap = battle.map
	var down := Vector2i.ZERO
	var lowest := map.height_at(cell)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var next: Vector2i = cell + d
		if map.in_bounds(next) and map.walkable(next) and map.height_at(next) < lowest:
			lowest = map.height_at(next)
			down = d
	var color: Color = ground if road else _jitter(cell, palette["slope"])
	if down == Vector2i.ZERO:
		_add_column(cell, -BASE_DEPTH, top, color)
		return
	var bottom := top - LEVEL
	_add_column(cell, -BASE_DEPTH, bottom, color)
	# (PrismMesh coupé en biais : le côté haut à gauche (-X) ; on tourne pour que le bas regarde la voisine basse)
	var basis := Basis(Vector3.UP, atan2(-float(down.y), float(down.x)))
	_add_part(cell, Shape.RAMP, Vector3(cell.x + 0.5, bottom + LEVEL / 2.0, cell.y + 0.5), Vector3(1.0, LEVEL, 1.0), color, false, basis)


## (Recensement « Techniques », point 8.) Le jour ou la nuit (Battle.is_night : un camp endormi) : la nuit, le ciel, la
## lumière ambiante et le soleil (la lune) s'assombrissent ; le feu de camp éclaire autour de lui.
func _apply_daylight() -> void:
	var night: bool = battle.is_night()
	environment.background_color = Color("06070d") if night else Color("12141c")
	environment.ambient_light_color = Color("4a5a90") if night else Color("8a94b0")
	environment.ambient_light_energy = 0.4 if night else 0.75
	sun.light_color = Color("9fb4ff") if night else Color("fff1d8")
	sun.light_energy = 0.3 if night else 1.0


## Une tente du camp (point 8) : une toile en prisme, un peu de travers, sur le sol.
func _add_tent(cell: Vector2i, top: float, index: int) -> void:
	_add_column(cell, -BASE_DEPTH, 0.0, _jitter(cell, _palette()["ground2"]))
	var basis := Basis(Vector3.UP, fposmod(float(cell.x * 3 + cell.y * 5), 3.0) * 0.4)
	_add_part(cell, Shape.PRISM, Vector3(cell.x + 0.5, top * 0.5, cell.y + 0.5), Vector3(0.95, top, 0.9),
		_jitter(cell, TENT_COLOR, 0.1), true, basis)
	tops[index] = top


## Le feu de camp (point 8) : des pierres en rond, des braises, une flamme qui éclaire autour d'elle.
func _add_fire(cell: Vector2i, top: float) -> void:
	var center := Vector3(cell.x + 0.5, top, cell.y + 0.5)
	for k in 6:
		var angle := TAU * k / 6.0
		_add_part(cell, Shape.SPHERE, center + Vector3(cos(angle) * 0.3, 0.05, sin(angle) * 0.3), Vector3(0.14, 0.1, 0.14), Color("6a6660"))
	_add_part(cell, Shape.SPHERE, center + Vector3(0, 0.12, 0), Vector3(0.28, 0.32, 0.28), FIRE_COLOR)
	if fire_light != null:
		fire_light.queue_free()
	fire_light = OmniLight3D.new()
	fire_light.light_color = FIRE_COLOR
	fire_light.light_energy = 2.2 if battle.is_night() else 0.8
	fire_light.omni_range = 5.0
	fire_light.position = center + Vector3(0, 0.6, 0)
	viewport.add_child(fire_light)


## La lisière d'une carte ronde (cartes, étape 2 ; MapGenerator.inside) : selon « edge_style », des arbres serrés, des
## rochers ou des pans de mur en ruine, sur un sol sombre. Infranchissable, plus basse au sud (vers la caméra) pour ne
## pas cacher les héros.
func _add_edge(cell: Vector2i, palette: Dictionary, index: int) -> void:
	var near := false
	for d in BattleMap.DIRECTIONS:
		if battle.map.in_bounds(cell + d) and MapGenerator.inside(cell + d):
			near = true
	tops[index] = 0.0
	if not near:
		return  # (loin du terrain : rien, la carte paraît ronde)
	_add_column(cell, -BASE_DEPTH, 0.0, _jitter(cell, palette["ground2"].darkened(0.35)))
	var size := 0.8 + fposmod(float(cell.x * 7 + cell.y * 13), 5.0) * 0.08
	match battle.map_data.get("edge_style", "trees"):
		"rocks":
			_add_part(cell, Shape.SPHERE, Vector3(cell.x + 0.5, 0.35 * size, cell.y + 0.5), Vector3(1.15, 0.95 * size, 1.15),
				_jitter(cell, palette["stone"].darkened(0.1), 0.12), true)
			tops[index] = 0.8 * size
		"ruins":
			_add_part(cell, Shape.BOX, Vector3(cell.x + 0.5, 0.45 * size, cell.y + 0.5), Vector3(0.9, 0.9 * size, 0.4),
				_jitter(cell, palette["stone"], 0.1), true)
			tops[index] = 0.9 * size
		_:
			_add_part(cell, Shape.CYLINDER, Vector3(cell.x + 0.5, 0.45, cell.y + 0.5), Vector3(0.2, 0.9, 0.2), TRUNK_COLOR)
			_add_part(cell, Shape.SPHERE, Vector3(cell.x + 0.5, 1.15 * size, cell.y + 0.5), Vector3(1.25, 1.1 * size, 1.25),
				_jitter(cell, FOLIAGE_COLOR.darkened(0.15), 0.12), true)
			tops[index] = 1.7 * size


## Un obstacle (case où l'on ne marche pas) selon le décor : arbres, maisons fermées, puits, porte, rocher...
func _add_block(cell: Vector2i, top: float, structure: Dictionary, palette: Dictionary, index: int) -> void:
	var base: float = structure.get("base", 0) * LEVEL
	var height := top - base
	match structure.get("kind", ""):
		"trees":
			# Un arbre : le tronc, puis un feuillage rond (une seconde boule, plus petite, sur les grands).
			_add_column(cell, -BASE_DEPTH, base, _jitter(cell, palette["ground2"]))
			var size := 0.85 + fposmod(float(cell.x * 31 + cell.y * 17), 7.0) * 0.05
			_add_part(cell, Shape.CYLINDER, Vector3(cell.x + 0.5, base + height * 0.3, cell.y + 0.5), Vector3(0.2, height * 0.6, 0.2), TRUNK_COLOR)
			_add_part(cell, Shape.SPHERE, Vector3(cell.x + 0.5, base + height * 0.72, cell.y + 0.5), Vector3(1.1, height * 0.6, 1.1) * size,
				_jitter(cell, FOLIAGE_COLOR, 0.14), true)
			if size > 1.0:
				_add_part(cell, Shape.SPHERE, Vector3(cell.x + 0.45, base + height * 1.0, cell.y + 0.55), Vector3(0.7, height * 0.35, 0.7),
					_jitter(cell, FOLIAGE_COLOR.lightened(0.08), 0.14), true)
			tops[index] = base + height * 1.1
		"bush":
			_add_column(cell, -BASE_DEPTH, base, _jitter(cell, palette["ground2"]))
			_add_part(cell, Shape.SPHERE, Vector3(cell.x + 0.5, base + 0.3, cell.y + 0.5), Vector3(0.95, 0.65, 0.95),
				_jitter(cell, FOLIAGE_COLOR.lightened(0.05), 0.12), true)
			tops[index] = base + 0.6
		"house":
			# Maison fermée : murs crépis, une porte du côté de la route, et un toit à deux pans sur toute la maison.
			_add_column(cell, -BASE_DEPTH, top, _jitter(cell, palette.get("wall", palette["block"]), 0.04), true)
			var rect: Rect2i = structure["rect"]
			var along_x := rect.size.x >= rect.size.y  # (le faîte du toit suit le grand côté)
			if (along_x and cell.y == rect.position.y) or (not along_x and cell.x == rect.position.x):
				var center := Vector3(cell.x + 0.5, top + 0.3, cell.y + 0.5)
				var scale := Vector3(1.04, 0.6, rect.size.y + 0.1)
				if along_x:
					center.z = rect.position.y + rect.size.y / 2.0
				else:
					center.x = rect.position.x + rect.size.x / 2.0
					scale = Vector3(rect.size.x + 0.1, 0.6, 1.04)
				# (PrismMesh : le faîte suit Z ; une maison en long sur X le tourne d'un quart de tour)
				var basis := Basis(Vector3.UP, PI / 2.0) if along_x else Basis.IDENTITY
				_add_part(cell, Shape.PRISM, center, scale, _jitter(cell, palette["roof"], 0.06), true, basis)
			var facing: Vector2i = structure.get("facing", Vector2i(0, 1))
			var door_cell := Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
			if cell == door_cell:
				var door := Vector3(cell.x + 0.5, base + 0.3, cell.y + 0.5) + Vector3(facing.x, 0, facing.y) * 0.51
				var door_scale := Vector3(0.05, 0.6, 0.4) if facing.x != 0 else Vector3(0.4, 0.6, 0.05)
				_add_part(cell, Shape.BOX, door, door_scale, TRUNK_COLOR.darkened(0.2), true)
			tops[index] = top + 0.6
		"well":
			_add_column(cell, -BASE_DEPTH, base, _jitter(cell, palette["ground"]))
			_add_part(cell, Shape.CYLINDER, Vector3(cell.x + 0.5, base + height / 2.0, cell.y + 0.5), Vector3(0.8, height, 0.8), palette["stone"], true)
			_add_part(cell, Shape.PRISM, Vector3(cell.x + 0.5, top + 0.35, cell.y + 0.5), Vector3(0.9, 0.3, 0.9), palette["roof"], true)
		"boulder":
			_add_column(cell, -BASE_DEPTH, base, _jitter(cell, palette["ground"]))
			_add_part(cell, Shape.SPHERE, Vector3(cell.x + 0.5, base + height * 0.5, cell.y + 0.5), Vector3(1.1, height * 1.05, 1.1),
				_jitter(cell, palette["stone"], 0.1), true)
		_:
			_add_column(cell, -BASE_DEPTH, top, _jitter(cell, palette["block"]), true)


## Une échelle : deux montants et des barreaux, contre la case voisine la plus haute.
func _add_ladder(cell: Vector2i, bottom: float) -> void:
	var map: BattleMap = battle.map
	var best := Vector2i.ZERO
	var best_height := -1
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var next: Vector2i = cell + d
		if map.in_bounds(next) and map.height_at(next) > best_height:
			best_height = map.height_at(next)
			best = d
	var top := maxf(bottom + LEVEL, best_height * LEVEL)
	var height := top - bottom
	var face := Vector3(cell.x + 0.5, 0, cell.y + 0.5) + Vector3(best.x, 0, best.y) * 0.42
	var side := Vector3(best.y, 0, best.x) * 0.22  # perpendiculaire au mur
	for s in [-1.0, 1.0]:
		_add_part(cell, Shape.BOX, face + side * s + Vector3(0, bottom + height / 2.0, 0), Vector3(0.06, height, 0.06), LADDER_COLOR)
	var rungs := maxi(2, int(height / 0.25))
	for k in rungs:
		var y := bottom + (k + 0.5) * height / rungs
		var rung_scale := Vector3(0.44, 0.04, 0.05) if best.y != 0 else Vector3(0.05, 0.04, 0.44)
		_add_part(cell, Shape.BOX, face + Vector3(0, y, 0), rung_scale, LADDER_COLOR)


func _mesh_for(shape: int) -> Mesh:
	match shape:
		Shape.SPHERE:
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 12
			sphere.rings = 6
			return sphere
		Shape.PRISM:
			return PrismMesh.new()
		Shape.RAMP:
			# (une rampe : le prisme coupé en biais, côté haut à gauche ; cartes, étape 2)
			var ramp := PrismMesh.new()
			ramp.left_to_right = 0.0
			return ramp
		Shape.CYLINDER:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			cylinder.radial_segments = 10
			return cylinder
	return BoxMesh.new()


func _build_multimeshes() -> void:
	for node in opaque_mm.values() + faded_mm.values():
		node.queue_free()
	opaque_mm.clear()
	faded_mm.clear()
	var opaque_material := StandardMaterial3D.new()
	opaque_material.vertex_color_use_as_albedo = true
	opaque_material.roughness = 0.95
	var faded_material := StandardMaterial3D.new()
	faded_material.vertex_color_use_as_albedo = true
	faded_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	faded_material.albedo_color = Color(1, 1, 1, FADED_ALPHA)
	faded_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for shape in Shape.values():
		for faded in [false, true]:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			multimesh.mesh = _mesh_for(shape)
			var node := MultiMeshInstance3D.new()
			node.multimesh = multimesh
			node.material_override = faded_material if faded else opaque_material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if faded else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			viewport.add_child(node)
			(faded_mm if faded else opaque_mm)[shape] = node
	_fill_multimeshes()


## Range chaque pièce dans la MultiMesh opaque ou transparente (devant le héros choisi) de sa forme.
func _fill_multimeshes() -> void:
	for shape in Shape.values():
		var opaque: Array = []
		var faded: Array = []
		for part in parts:
			if part["shape"] == shape:
				(faded if part["solid"] and faded_cells.has(part["cell"]) else opaque).append(part)
		_fill(opaque_mm[shape], opaque)
		_fill(faded_mm[shape], faded)


func _fill(node: MultiMeshInstance3D, list: Array) -> void:
	node.multimesh.instance_count = list.size()
	for i in list.size():
		node.multimesh.set_instance_transform(i, list[i]["xf"])
		node.multimesh.set_instance_color(i, _fogged_color(list[i]))


# ---------------------------------------------------------------------------
# Les combattants
# ---------------------------------------------------------------------------

func _build_units() -> void:
	for child in units_root.get_children():
		child.queue_free()
	unit_nodes.clear()
	display_y.clear()
	var shadow_material := StandardMaterial3D.new()
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.albedo_color = Color(0, 0, 0, 0.45)
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for unit in battle.units:
		var root := Node3D.new()
		units_root.add_child(root)
		var big := BOSS_SCALE if unit["boss"] else 1.0
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = BODY_RADIUS * big
		capsule.height = BODY_HEIGHT * big
		capsule.radial_segments = 10
		capsule.rings = 4
		body.mesh = capsule
		body.position.y = BODY_HEIGHT * big / 2.0
		var body_material := StandardMaterial3D.new()
		body_material.albedo_color = CLASS_COLORS.get(unit["class"], Color("9a9a9a"))
		body_material.emission_enabled = true
		body_material.emission = Color.BLACK
		body.material_override = body_material
		root.add_child(body)
		var head := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = HEAD_RADIUS * big
		sphere.height = HEAD_RADIUS * 2.0 * big
		sphere.radial_segments = 10
		sphere.rings = 5
		head.mesh = sphere
		head.position.y = (BODY_HEIGHT + HEAD_RADIUS * 0.9) * big
		var head_material := StandardMaterial3D.new()
		head_material.albedo_color = _camp_color(unit)
		head.material_override = head_material
		root.add_child(head)
		# L'ombre au sol (sous lui, à la hauteur de la case) : on lit la hauteur même quand il saute.
		var shadow := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = BODY_RADIUS * 1.5 * big
		disc.bottom_radius = BODY_RADIUS * 1.5 * big
		disc.height = 0.02
		disc.radial_segments = 14
		shadow.mesh = disc
		shadow.material_override = shadow_material
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		units_root.add_child(shadow)
		# Anneau au sol, couleur du camp (jaune quand il est choisi).
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = BODY_RADIUS * 1.6 * big
		torus.outer_radius = BODY_RADIUS * 1.95 * big
		torus.rings = 16
		torus.ring_segments = 4
		ring.mesh = torus
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.albedo_color = _camp_color(unit)
		ring.material_override = ring_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
		unit_nodes[unit["id"]] = {"root": root, "body": body, "head": head, "shadow": shadow, "ring": ring,
			"body_mat": body_material, "head_mat": head_material, "ring_mat": ring_material}
		display_y[unit["id"]] = battle.height_of(unit) * LEVEL


func _camp_color(unit: Dictionary) -> Color:
	if unit["boss"]:
		return BOSS_COLOR
	return HERO_COLOR if unit["is_hero"] else ENEMY_COLOR


## Position d'un combattant sur la carte (glissée entre deux pas du combat).
func unit_map_pos(unit: Dictionary) -> Vector2:
	var weight := clampf(view.accumulator / Battle.TICK, 0.0, 1.0)
	return unit["prev_pos"].lerp(unit["pos"], weight)


## Point du monde aux pieds d'un combattant.
func unit_feet(unit: Dictionary) -> Vector3:
	var pos := unit_map_pos(unit)
	return Vector3(pos.x, display_y.get(unit["id"], 0.0), pos.y)


## Hauteur du dessus de la case sous ce point (pour l'ombre).
func _surface_at(pos: Vector2) -> float:
	var cell := Vector2i(floori(pos.x), floori(pos.y))
	if not battle.map.in_bounds(cell):
		return 0.0
	return battle.map.height_at(cell) * LEVEL


func _update_units(delta: float) -> void:
	for unit in battle.units:
		var nodes: Dictionary = unit_nodes[unit["id"]]
		var root: Node3D = nodes["root"]
		# (cartes, étape 4) un monstre que personne ne voit est caché par le brouillard
		var shown: bool = unit["present"] and (unit["hp"] > 0 or unit["is_hero"]) and not fogged(unit)
		root.visible = shown
		nodes["shadow"].visible = shown
		if not shown:
			continue
		var target_y := battle.height_of(unit) * LEVEL
		display_y[unit["id"]] = move_toward(display_y[unit["id"]], target_y, CLIMB_DISPLAY_SPEED * LEVEL * delta)
		var feet := unit_feet(unit)
		root.position = feet
		var pos := unit_map_pos(unit)
		nodes["shadow"].position = Vector3(pos.x, _surface_at(pos) + 0.015, pos.y)
		# Au sol (agonie, tombé) : couché ; sinon debout.
		var down: bool = unit["hp"] <= 0
		root.rotation = Vector3(0, 0, PI / 2.0 if down else 0.0)
		if down:
			root.position.y += BODY_RADIUS
		var body_mat: StandardMaterial3D = nodes["body_mat"]
		var base_color: Color = CLASS_COLORS.get(unit["class"], Color("9a9a9a"))
		var glow := Color.BLACK  # (émission toujours active : la changer de couleur ne recompile rien)
		if down and unit.get("agony", false):
			# À l'agonie : le corps rougit et bat avec les secondes.
			var pulse := 0.5 + 0.5 * sin(battle.time * 8.0)
			body_mat.albedo_color = Color(0.6, 0.1, 0.1).lerp(Color(1, 0.3, 0.3), pulse)
			glow = Color(1, 0.15, 0.15) * (0.3 + 0.5 * pulse)
		elif down:
			body_mat.albedo_color = Color(0.35, 0.35, 0.35)
		elif unit["berserk"]:
			body_mat.albedo_color = base_color.lerp(Color("ff3030"), 0.5)
			glow = Color(1, 0.1, 0.1) * 0.6
		else:
			body_mat.albedo_color = base_color
		var hidden := view.unseen(unit)  # (C3) aucun héros ne le voit : grisé
		if hidden:
			body_mat.albedo_color = UNSEEN_COLOR
		body_mat.emission = glow
		var ring_mat: StandardMaterial3D = nodes["ring_mat"]
		ring_mat.albedo_color = ORDER_COLOR if unit["id"] == view.selected_id else (UNSEEN_COLOR if hidden else _camp_color(unit))
		nodes["ring"].visible = not down


# ---------------------------------------------------------------------------
# Caméra et gestes
# ---------------------------------------------------------------------------

func _update_camera() -> void:
	zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	cam_target.x = clampf(cam_target.x, 0.0, float(Battle.GRID_W))
	cam_target.z = clampf(cam_target.z, 0.0, float(Battle.GRID_H))
	camera.size = zoom
	var basis := Basis.from_euler(Vector3(deg_to_rad(-PITCH_DEG), deg_to_rad(yaw), 0.0), EULER_ORDER_YXZ)
	camera.basis = basis
	camera.position = cam_target + basis.z * CAMERA_DISTANCE


func _rotate_view() -> void:
	turn = (turn + 1) % 4
	faded_cells.clear()
	fade_timer = 0.0


## Pixels de l'écran 3D par pixel de cette vue (l'écran 3D peut être rendu plus petit : RENDER_SHRINK).
func _to_view(viewport_point: Vector2) -> Vector2:
	return viewport_point * float(container.stretch_shrink)


func _to_viewport(view_point: Vector2) -> Vector2:
	return view_point / float(container.stretch_shrink)


## Position à l'écran (dans cette vue) d'un point du monde.
func project(point: Vector3) -> Vector2:
	return _to_view(camera.unproject_position(point))


func _gui_input(event: InputEvent) -> void:
	if battle == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		pinch_distance = _touch_spread()
		if touches.size() >= 2:
			moved = true  # deux doigts : pas un toucher
		accept_event()
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() >= 2:
			var spread := _touch_spread()
			if pinch_distance > 0.0 and spread > 0.0:
				zoom *= pinch_distance / spread
				_update_camera()
			pinch_distance = spread
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom /= event.factor
		_update_camera()
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom *= 0.9
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom *= 1.1
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressing = true
				moved = false
				press_pos = event.position
			else:
				if pressing and not moved:
					tap(event.position)
				pressing = false
		accept_event()
	elif event is InputEventMouseMotion and pressing:
		if event.position.distance_to(press_pos) > TAP_THRESHOLD:
			moved = true
		if moved and touches.size() < 2:
			# Un doigt : la carte suit le doigt.
			var per_pixel := zoom / maxf(size.x, 1.0)
			var right := camera.basis.x
			var forward := Vector3(-camera.basis.z.x, 0.0, -camera.basis.z.z).normalized()
			cam_target -= right * event.relative.x * per_pixel
			cam_target += forward * event.relative.y * per_pixel / sin(deg_to_rad(PITCH_DEG))
			_update_camera()
		accept_event()


func _touch_spread() -> float:
	if touches.size() < 2:
		return 0.0
	var points: Array = touches.values()
	return (points[0] as Vector2).distance_to(points[1])


## Un toucher à ce point de la vue : le combattant le plus proche à l'écran, sinon la case touchée.
func tap(view_point: Vector2) -> void:
	var unit := unit_at_screen(view_point)
	if not unit.is_empty():
		tapped.emit(unit, unit_map_pos(unit), true)
		return
	var hit := pick_cell(view_point)
	tapped.emit({}, hit["pos"], hit["inside"])


## Le combattant debout dont le corps est le plus proche du point touché (à l'écran), ou {}.
func unit_at_screen(view_point: Vector2) -> Dictionary:
	var result := {}
	var best := TAP_RADIUS_PX * ZOOM_DEFAULT / zoom
	for unit in battle.units:
		if not unit["present"] or unit["hp"] <= 0 or fogged(unit):
			continue
		var center := unit_feet(unit) + Vector3(0, BODY_HEIGHT * 0.6, 0)
		var distance := project(center).distance_to(view_point)
		if distance < best:
			best = distance
			result = unit
	return result


## Lancer de rayon depuis le point touché : la première colonne de case qu'il rencontre (son dessus ou son
## flanc). Le niveau compte : sur un toit, on touche le toit, pas la rue qu'il cache. Renvoie
## {"cell": Vector2i, "pos": Vector2 (point de la carte en cases, dans la case), "inside": bool}.
func pick_cell(view_point: Vector2) -> Dictionary:
	var vp := _to_viewport(view_point)
	var origin := camera.project_ray_origin(vp)
	var direction := camera.project_ray_normal(vp)
	var map: BattleMap = battle.map
	if direction.y >= -0.001:
		return {"cell": Vector2i(-1, -1), "pos": Vector2(-1, -1), "inside": false}
	# On part du plafond (le plus haut des niveaux) et on descend le long du rayon par petits pas.
	var ceiling := BattleMap.MAX_HEIGHT * LEVEL + 0.5
	var t := (origin.y - ceiling) / -direction.y
	var t_floor := (origin.y + 0.001) / -direction.y
	var step := 0.04
	while t <= t_floor:
		var point := origin + direction * t
		var cell := Vector2i(floori(point.x), floori(point.z))
		if map.in_bounds(cell) and point.y <= map.height_at(cell) * LEVEL + 0.001:
			var pos := Vector2(clampf(point.x, cell.x + 0.05, cell.x + 0.95), clampf(point.z, cell.y + 0.05, cell.y + 0.95))
			return {"cell": cell, "pos": pos, "inside": true}
		t += step
	var ground := origin + direction * t_floor
	var flat := Vector2(ground.x, ground.z)
	return {"cell": Vector2i(floori(flat.x), floori(flat.y)), "pos": flat,
		"inside": Rect2(0, 0, Battle.GRID_W, Battle.GRID_H).has_point(flat)}


# ---------------------------------------------------------------------------
# Murs et toits transparents devant le héros choisi
# ---------------------------------------------------------------------------

func _update_fade(delta: float) -> void:
	fade_timer -= delta
	if fade_timer > 0.0:
		return
	fade_timer = FADE_REFRESH
	var wanted := {}
	var hero: Dictionary = battle.units[view.selected_id] if view.selected_id >= 0 else {}
	if not hero.is_empty() and hero["present"]:
		var feet := unit_feet(hero)
		var target := project(feet + Vector3(0, BODY_HEIGHT * 0.5, 0))
		var hero_depth := (feet - camera.position).dot(-camera.basis.z)
		var map: BattleMap = battle.map
		for i in map.kinds.size():
			var top: float = tops[i]
			if top <= feet.y + 0.05:
				continue  # pas plus haut que lui : il ne le cache pas
			var cell := map.cell_at(i)
			var center := Vector3(cell.x + 0.5, top, cell.y + 0.5)
			if (center - camera.position).dot(-camera.basis.z) >= hero_depth:
				continue  # derrière lui
			var area := Rect2(project(Vector3(cell.x, top, cell.y)), Vector2.ZERO)
			for corner in [Vector3(cell.x + 1, top, cell.y), Vector3(cell.x, top, cell.y + 1), Vector3(cell.x + 1, top, cell.y + 1),
					Vector3(cell.x, feet.y, cell.y), Vector3(cell.x + 1, feet.y, cell.y), Vector3(cell.x, feet.y, cell.y + 1),
					Vector3(cell.x + 1, feet.y, cell.y + 1)]:
				area = area.expand(project(corner))
			if area.grow(6.0).has_point(target):
				wanted[cell] = true
	if wanted.hash() != faded_cells.hash() or wanted.size() != faded_cells.size():
		faded_cells = wanted
		_fill_multimeshes()


# ---------------------------------------------------------------------------
# Brouillard de guerre (cartes, étape 4)
# ---------------------------------------------------------------------------

## La lumière de chaque case : vue en ce moment (parcourue par un bâtonnet d'un héros à la dernière mise à jour de la
## perception, voir BattleExplore.mark, ou tout près d'un héros), déjà vue, ou jamais vue. La lisière prend la lumière
## de sa voisine la plus éclairée. Rien ne change dans le combat : ce n'est que l'écran.
func _update_fog(delta: float) -> void:
	if not fog_on or battle.explore == null or battle.perception == null:
		return
	fog_timer -= delta
	if fog_timer > 0.0:
		return
	fog_timer = FOG_REFRESH
	var map: BattleMap = battle.map
	var explored: PackedFloat32Array = battle.explore.explored
	var now: float = battle.perception.updated_at - 0.05
	var heroes: Array = battle._alive(battle.heroes)
	var next := PackedFloat32Array()
	next.resize(fog.size())
	for i in fog.size():
		var cell := map.cell_at(i)
		var visible: bool = explored[i] >= now
		if not visible:
			var center := BattleMap.center(cell)
			visible = heroes.any(func(h): return h["pos"].distance_to(center) <= FOG_AROUND)
		if visible:
			seen_ever[i] = 1
		next[i] = 1.0 if visible else (FOG_REMEMBERED if seen_ever[i] == 1 else FOG_UNSEEN)
	if battle.map_data.get("version", 1) >= 2:
		for i in fog.size():
			var cell := map.cell_at(i)
			if MapGenerator.inside(cell):
				continue
			var light := FOG_UNSEEN
			for d in BattleMap.DIRECTIONS:
				var other: Vector2i = cell + d
				if map.in_bounds(other) and MapGenerator.inside(other):
					light = maxf(light, next[map.index(other)])
			next[i] = light
	if next != fog:
		fog = next
		_fill_multimeshes()


## La couleur d'une pièce du décor, assombrie par le brouillard de sa case.
func _fogged_color(part: Dictionary) -> Color:
	var color: Color = part["color"]
	if fog.is_empty():
		return color
	var light: float = fog[battle.map.index(part["cell"])]
	return Color(color.r * light, color.g * light, color.b * light, color.a)


## Un monstre caché par le brouillard : aucun héros ne le voit ni ne l'entend (le mode dev le montre, grisé).
func fogged(unit: Dictionary) -> bool:
	return fog_on and not unit["is_hero"] and not Settings.dev_mode and view.unseen(unit)


## Une case que les héros ont déjà vue (ou pas de brouillard).
func seen_cell(pos: Vector2) -> bool:
	if not fog_on or seen_ever.is_empty():
		return true
	var cell := battle.map.cell_of(pos)
	return seen_ever[battle.map.index(cell)] == 1


# ---------------------------------------------------------------------------
# Chaque image
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if battle == null or not is_visible_in_tree():
		return
	var wanted_yaw := YAW_DEG + turn * 90.0
	if not is_equal_approx(yaw, wanted_yaw):
		# Le quart de tour glisse en un quart de seconde (par le plus court chemin).
		var diff := wrapf(wanted_yaw - yaw, -180.0, 180.0)
		yaw = wanted_yaw if absf(diff) < 1.0 else yaw + diff * minf(1.0, delta * 12.0)
		_update_camera()
	_update_units(delta)
	_update_fade(delta)
	_update_fog(delta)
	# (mode dev ; l'option « Performances » des paramètres montre tout cela, et plus, sur tous les écrans)
	layer_button.visible = Settings.dev_mode
	fps_label.visible = Settings.dev_mode and not Settings.show_perf
	if fps_label.visible:
		fps_label.text = "%d images/s" % Engine.get_frames_per_second()
		if battle.director != null:  # (point 10) la tension mesurée par le directeur d'IA
			fps_label.text += " · tension %.2f (%s)" % [battle.director.tension, battle.director.phase()]
	overlay.queue_redraw()


# ---------------------------------------------------------------------------
# Par-dessus la 3D : barres, étiquettes, noms, coups, ordres
# ---------------------------------------------------------------------------

func _draw_overlay() -> void:
	if battle == null:
		return
	var k := clampf(ZOOM_DEFAULT / zoom, 0.7, 2.2)  # les pions grossissent quand on zoome
	var heads := {}   # numéro → point au-dessus de la tête, à l'écran
	var bodies := {}  # numéro → milieu du corps, à l'écran
	for unit in battle.units:
		if not unit["present"] or fogged(unit):
			continue
		var feet := unit_feet(unit)
		var big := BOSS_SCALE if unit["boss"] else 1.0
		heads[unit["id"]] = project(feet + Vector3(0, (BODY_HEIGHT + HEAD_RADIUS * 2.2) * big, 0))
		bodies[unit["id"]] = project(feet + Vector3(0, BODY_HEIGHT * 0.5 * big, 0))
	# (étape E, point 3) les pièges des héros : une croix brune sur le dessus de la case
	for trap in battle.traps:
		var c := BattleMap.center(trap["cell"])
		var top := _surface_at(c) + 0.03
		var a := project(Vector3(c.x - 0.25, top, c.y - 0.25))
		var b := project(Vector3(c.x + 0.25, top, c.y + 0.25))
		var d := project(Vector3(c.x + 0.25, top, c.y - 0.25))
		var e := project(Vector3(c.x - 0.25, top, c.y + 0.25))
		overlay.draw_line(a, b, BattleView.TRAP_COLOR, 2.5 * k)
		overlay.draw_line(d, e, BattleView.TRAP_COLOR, 2.5 * k)
	# (recensement « Techniques », point 2) les corps des monstres tombés avant l'alarme (rouges une fois découverts)
	if battle.alert != null:
		for corpse in battle.alert.corpses:
			var spot: Vector2 = corpse["pos"]
			if not seen_cell(spot):
				continue  # (dans le brouillard : jamais vu)
			overlay.draw_circle(project(Vector3(spot.x, _surface_at(spot) + 0.03, spot.y)), 5.0 * k,
				BattleView.CORPSE_FOUND_COLOR if corpse["found"] else BattleView.CORPSE_COLOR)
	_draw_layer()
	_draw_orders(bodies, k)
	_draw_rays()
	for unit in battle.units:
		if heads.has(unit["id"]):
			_draw_unit_info(unit, heads[unit["id"]], bodies[unit["id"]], k)
	_draw_effects(heads, bodies, k)


## Perception (C3, effet « lidar ») : les bâtonnets du héros choisi, à hauteur de ses yeux, en traits fins avec un
## point brillant là où chacun s'arrête.
func _draw_rays() -> void:
	if view.selected_id < 0:
		return
	var hero: Dictionary = battle.units[view.selected_id]
	if not hero["present"] or hero["hp"] <= 0:
		return
	var eye: float = display_y.get(hero["id"], 0.0) + BODY_HEIGHT * 0.9
	var from := project(unit_feet(hero) + Vector3(0, BODY_HEIGHT * 0.9, 0))
	for end in hero.get("rays", PackedVector2Array()):
		var to := project(Vector3(end.x, eye, end.y))
		overlay.draw_line(from, to, BattleView.RAY_COLOR, 1.0, true)
		overlay.draw_circle(to, 2.5, BattleView.RAY_DOT_COLOR)
	# Mode dev (IA tactique) : la case qu'il a choisie, un losange sur son dessus.
	var cell = hero.get("tactic", {}).get("cell")
	if Settings.dev_mode and cell != null:
		var top := _surface_at(cell) + 0.03
		var corners := PackedVector2Array()
		for offset in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5)]:
			var p: Vector2 = cell + offset
			corners.append(project(Vector3(p.x, top, p.y)))
		overlay.draw_polyline(corners, BattleView.TACTIC_COLOR, 2.0, true)
		overlay.draw_dashed_line(from, project(Vector3(cell.x, top, cell.y)), BattleView.TACTIC_COLOR, 1.5, 6.0)


## Les ordres en cours : un trait jaune vers l'endroit (à sa hauteur) ou l'ennemi visé.
func _draw_orders(bodies: Dictionary, k: float) -> void:
	for hero in battle.heroes:
		var order: Dictionary = hero["order"]
		if order.is_empty() or hero["hp"] <= 0 or not bodies.has(hero["id"]):
			continue
		var from: Vector2 = bodies[hero["id"]]
		if order["kind"] == "move":
			var spot: Vector2 = order["pos"]
			var to := project(Vector3(spot.x, _surface_at(spot) + 0.02, spot.y))
			overlay.draw_dashed_line(from, to, Color(ORDER_COLOR, 0.7), 2.0, 8.0)
			overlay.draw_arc(to, 9.0 * k, 0, TAU, 16, ORDER_COLOR, 2.0)
		elif bodies.has(order["target"]):
			var to: Vector2 = bodies[order["target"]]
			overlay.draw_dashed_line(from, to, Color(ORDER_COLOR, 0.7), 2.0, 8.0)
			overlay.draw_arc(to, 16.0 * k, 0, TAU, 20, ORDER_COLOR, 2.0)


## Au-dessus d'un combattant : sa vie et son endurance, son état (PEUR, REPOS, AGONIE...), son nom.
func _draw_unit_info(unit: Dictionary, head: Vector2, body: Vector2, k: float) -> void:
	var font := ThemeDB.fallback_font
	if unit["hp"] <= 0:
		if unit.get("agony", false):
			# À l'agonie : les secondes qui restent, en gros, et « arme plantée » s'il le faut.
			var pulse := 0.5 + 0.5 * sin(battle.time * 8.0)
			overlay.draw_circle(body, 13.0 * k, Color(0.6, 0.1, 0.1, 0.35 + 0.35 * pulse))
			overlay.draw_string(font, body + Vector2(-30, 6), str(ceili(unit["agony_until"] - battle.time)),
				HORIZONTAL_ALIGNMENT_CENTER, 60, int(18 * k), Color.WHITE)
			_draw_tag(font, head, "AGONIE", Color("ff4040"), k)
			if unit.get("embedded", false):
				_draw_tag(font, head + Vector2(0, -15 * k), "arme plantée", Color("ffb060"), k)
		elif unit["is_hero"]:
			_draw_tag(font, head, "à terre" if unit["immortal"] else "tombé", Color(1, 0.5, 0.5, 0.8), k)
		return
	var camp := HERO_COLOR if unit["is_hero"] else (UNSEEN_COLOR if view.unseen(unit) else ENEMY_COLOR)
	var width := 30.0 * k * (1.4 if unit["boss"] else 1.0)
	var bar := Rect2(head - Vector2(width / 2.0, 0), Vector2(width, 4.0 * k))
	overlay.draw_rect(bar, Color("12131c"))
	overlay.draw_rect(Rect2(bar.position, Vector2(width * clampf(float(unit["hp"]) / unit["max_hp"], 0, 1), bar.size.y)), camp)
	if unit["person"]:
		var stamina := Rect2(bar.position + Vector2(0, bar.size.y), Vector2(width, 2.5 * k))
		overlay.draw_rect(stamina, Color("12131c"))
		overlay.draw_rect(Rect2(stamina.position, Vector2(width * clampf(unit["stamina"] / unit["max_stamina"], 0, 1), stamina.size.y)),
			STAMINA_TIRED_COLOR if unit["exhausted"] else STAMINA_COLOR)
	if unit.get("max_mana", 0) > 0:
		var mana := Rect2(bar.position + Vector2(0, bar.size.y + 3.0 * k), Vector2(width, 2.5 * k))
		overlay.draw_rect(mana, Color("12131c"))
		overlay.draw_rect(Rect2(mana.position, Vector2(width * clampf(unit["mana"] / unit["max_mana"], 0, 1), mana.size.y)), Color("4a8fe8"))
	if unit["bleed"]["ticks"] > 0:  # saigne : une goutte rouge
		overlay.draw_circle(bar.position + Vector2(width + 5.0 * k, 2.0), 3.5 * k, Color("ff3030"))
	# La jauge de détection d'un monstre qui ne chasse pas encore (du jaune au rouge), juste au-dessus de sa vie.
	if not unit["is_hero"] and battle.alert != null and not view.unseen(unit):
		var level: float = battle.alert.detect_level(unit)
		if level > 0.01:
			var gauge := Rect2(bar.position - Vector2(0, 3.5 * k), Vector2(width, 2.5 * k))
			overlay.draw_rect(gauge, Color("12131c"))
			overlay.draw_rect(Rect2(gauge.position, Vector2(width * level, gauge.size.y)), BattleView.detect_color(level))
	# L'état, au-dessus de la barre (le plus important seulement).
	var tag := ""
	var tag_color := Color.WHITE
	if unit["is_hero"] and battle.afraid(unit):
		tag = "PEUR"
		tag_color = Color("ffb060")
	elif battle.panicking(unit):
		tag = "PANIQUE"
		tag_color = Color("e0e0ff")
	elif unit["berserk"]:
		tag = "REFUS DE MOURIR" if battle.time < unit.get("refuse_death_until", 0.0) else "BERSERK"
		tag_color = Color("ff4040")
	elif unit.get("resting", false):
		tag = "REPOS"
		tag_color = STAMINA_COLOR
	elif unit["person"] and battle.has_migraine(unit):
		tag = "MIGRAINE"
		tag_color = Color("c9a2ff")
	elif not unit["is_hero"] and battle.alert != null and not view.unseen(unit):
		var state: Array = battle.alert.state_tag(unit)  # (étape E) Zzz, guetteur, au repos, ?, !
		tag = state[0]
		tag_color = state[1]
	if tag != "":
		_draw_tag(font, head + Vector2(0, -6 * k), tag, tag_color, k)
	# Nom des héros sous leur pion (le héros choisi : toujours), sans chevaucher un autre héros.
	if unit["is_hero"] or battle.quest.get("duel", false):
		var crowded := false
		for other in battle.heroes:
			if other["id"] != unit["id"] and other["present"] and other["pos"].distance_to(unit["pos"]) < 1.6:
				crowded = true
				break
		if not crowded or unit["id"] == view.selected_id:
			overlay.draw_string(font, body + Vector2(-60, 22 * k), unit["name"], HORIZONTAL_ALIGNMENT_CENTER, 120,
				int(11 * k), Color(1, 1, 1, 0.85))


func _draw_tag(font: Font, at: Vector2, text: String, color: Color, k: float) -> void:
	var font_size := int(12 * k)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8
	overlay.draw_rect(Rect2(at + Vector2(-width / 2.0, -font_size - 2), Vector2(width, font_size + 4)), Color(0, 0, 0, 0.55))
	overlay.draw_string(font, at + Vector2(-width / 2.0, -2), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


## Coups (traits), tirs, sorts, soins, chiffres qui s'envolent et bulles « Non ! ».
func _draw_effects(heads: Dictionary, bodies: Dictionary, k: float) -> void:
	var font := ThemeDB.fallback_font
	var now := battle.time
	var first := view.first_effect
	var ranks := BattleView.float_ranks(battle, first)  # (étape C) chiffres empilés, pas superposés
	for i in range(first, battle.effects.size()):
		var effect: Dictionary = battle.effects[i]
		var age: float = now - effect["t"]
		if not bodies.has(effect["to"]):
			continue
		var to: Vector2 = bodies[effect["to"]]
		var from: Vector2 = bodies[effect["from"]] if bodies.has(effect["from"]) else to
		if age < STRIKE_TIME:
			var fade := 1.0 - age / STRIKE_TIME
			match effect["kind"]:
				"hit":
					overlay.draw_line(from.lerp(to, 0.4), to, Color(1, 1, 1, fade), 3.0)
				"arrow":
					overlay.draw_line(from, to, Color(1, 0.85, 0.3, fade), 2.0)
				"spell":
					overlay.draw_line(from, to, Color(0.7, 0.45, 1, fade), 2.0)
					overlay.draw_circle(to, Battle.SPELL_RADIUS * 14.0 * k, Color(0.6, 0.3, 1, 0.25 * fade))
				"heal":
					overlay.draw_line(from, to, Color(0.4, 1, 0.5, fade), 2.0)
				"bolt":
					overlay.draw_line(from, to, Color(0.55, 0.75, 1, fade), 1.5)
		var head: Vector2 = heads.get(effect["to"], to)
		if effect["kind"] == "refuse":
			view.draw_bubble_on(overlay, font, head + Vector2(0, -16 * k), effect["text"],
				clampf(2.0 * (1.0 - age / BUBBLE_TIME), 0.0, 1.0))
			continue
		if age > FLOAT_TIME:
			continue
		var color := Color.WHITE
		var font_size := 16
		if effect["crit"]:
			color = Color("ffa030")
			font_size = 22
		elif effect["kind"] == "heal":
			color = Color("6fe08a")
		elif effect["kind"] == "bleed":
			color = Color("ff5050")
		elif effect["text"] == "esquive !":
			color = Color("9fd3ff")
		color.a = clampf(1.0 - age / FLOAT_TIME, 0.0, 1.0)
		overlay.draw_string(font, head + Vector2(-80, -18 * k - age * 30.0 - ranks.get(i, 0) * BattleView.FLOAT_LINE),
			effect["text"], HORIZONTAL_ALIGNMENT_CENTER, 160,
			font_size, color)


# ---------------------------------------------------------------------------
# Calques de débogage (recensement « Techniques », point 9 ; mode dev)
# ---------------------------------------------------------------------------

const LAYERS := ["", "regards", "recherche", "terrain"]
const LAYER_NAMES := {"": "Calques", "regards": "Regards", "recherche": "Recherche", "terrain": "Terrain"}


## Le calque suivant : aucun → les cases que regardent les monstres connus (BattleAlert.exposure) → la carte de
## probabilité des monstres (BattleSearch.heat) → le terrain annoté (BattleTerrain : goulets, points hauts, cachettes).
func _next_layer() -> void:
	debug_layer = LAYERS[(LAYERS.find(debug_layer) + 1) % LAYERS.size()]
	layer_button.text = LAYER_NAMES[debug_layer]
	_layer_timer = 0.0


## Les valeurs du calque (recalculées toutes les 0,3 s), dessinées en losanges colorés sur le dessus des cases.
func _draw_layer() -> void:
	if debug_layer == "" or not Settings.dev_mode:
		return
	_layer_timer -= get_process_delta_time()
	var map: BattleMap = battle.map
	if _layer_timer <= 0.0:
		_layer_timer = 0.3
		match debug_layer:
			"regards":
				_layer_values = battle.alert.exposure() if battle.alert != null else PackedFloat32Array()
			"recherche":
				_layer_values = battle.search.heat.duplicate() if battle.search != null else PackedFloat32Array()
				var top := 0.0
				for value in _layer_values:
					top = maxf(top, value)
				for i in _layer_values.size():
					_layer_values[i] = _layer_values[i] / top if top > 0.0 else 0.0
			"terrain":
				_layer_values = PackedFloat32Array()
				_layer_values.resize(map.kinds.size())
				if battle.terrain != null:
					for i in map.kinds.size():
						_layer_values[i] = 3.0 if battle.terrain.choke[i] == 1 else (2.0 if battle.terrain.high[i] == 1 \
							else (1.0 if battle.terrain.hide[i] == 1 else 0.0))
	if _layer_values.size() != map.kinds.size():
		return
	for i in map.kinds.size():
		var value: float = _layer_values[i]
		if value <= 0.0:
			continue
		var color: Color
		match debug_layer:
			"regards":
				color = Color(1.0, 0.25, 0.2, clampf(0.25 * value, 0.2, 0.6))
			"recherche":
				color = Color(1.0, 0.6, 0.1, 0.15 + 0.5 * value)
			_:
				color = [Color(0.3, 0.9, 0.4, 0.45), Color(0.4, 0.6, 1.0, 0.5), Color(1.0, 0.85, 0.2, 0.55)][int(value) - 1]
		var cell := map.cell_at(i)
		var y := tops[i] + 0.04
		var points := PackedVector2Array([project(Vector3(cell.x + 0.15, y, cell.y + 0.15)), project(Vector3(cell.x + 0.85, y, cell.y + 0.15)),
			project(Vector3(cell.x + 0.85, y, cell.y + 0.85)), project(Vector3(cell.x + 0.15, y, cell.y + 0.85))])
		overlay.draw_colored_polygon(points, color)
