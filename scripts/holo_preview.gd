class_name HoloPreview
extends SubViewportContainer
## Un bâtiment de la cité en hologramme cyan qui tourne lentement, avec un socle lumineux :
## l'aperçu des bâtiments à construire dans le menu Construction (modèles de CityModels).

const SIZE := Vector2(170, 170)

var pivot: Node3D


## « model » : le nom du modèle dans CityModels.build ("forge", "lab"...).
func _init(model: String) -> void:
	custom_minimum_size = SIZE
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)

	pivot = Node3D.new()
	viewport.add_child(pivot)
	var models := CityModels.new()
	models.holo = true
	models.build(model, pivot)
	# Le socle : deux anneaux qui brillent sous le bâtiment.
	for radius in [3.6, 4.2]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius - 0.06
		ring.outer_radius = radius + 0.06
		models.add(ring, null, Vector3(0, 0.02, 0), pivot)

	# La caméra cadre tout le bâtiment, quelle que soit sa taille, un peu en plongée.
	var bounds := AABB()
	for node in pivot.get_children():
		if node is MeshInstance3D:
			var box: AABB = node.transform * node.get_aabb()
			bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	var center := bounds.get_center()
	var reach := maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z) * 0.8)
	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.position = center + Vector3(0, 0.45, 1.0).normalized() * reach * 1.95
	camera.basis = Basis.looking_at(center - camera.position)
	viewport.add_child(camera)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		pivot.rotation.y += delta * 0.6
