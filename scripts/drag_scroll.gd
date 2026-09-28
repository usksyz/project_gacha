extends Node
## Défilement « comme sur un téléphone » : on appuie n'importe où dans une zone qui défile
## (Collection, journal de combat, paramètres...), même sur un bouton ou une carte,
## et on glisse le doigt pour faire défiler. Marche aussi à la souris (clic maintenu).
## Après avoir lâché, la liste continue un peu sur son élan.
##
## Chargé automatiquement (« autoload ») : toutes les ScrollContainer et RichTextLabel
## du jeu en profitent, sans rien ajouter dans les écrans.
##
## Astuce : pour que le bouton sous le doigt ne s'active pas après un glissement,
## on déplace les événements de la souris très loin de l'écran ; le bouton croit
## alors que le doigt est parti ailleurs.

## Distance (en pixels) à parcourir avant qu'un appui devienne un glissement.
const DRAG_THRESHOLD := 12.0

## Freinage de l'élan (plus c'est grand, plus la liste s'arrête vite).
const FRICTION := 4.0

## En dessous de cette vitesse (pixels par seconde), l'élan s'arrête.
const MIN_SPEED := 30.0

const FAR_AWAY := Vector2(-100000, -100000)

var pressing := false
var dragging := false
var press_position := Vector2.ZERO
## La zone qui défile (trouvée au moment de l'appui).
var target: Control = null
## Vitesse de l'élan, en pixels par seconde.
var velocity := 0.0
var last_motion_time := 0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressing = true
			dragging = false
			press_position = event.position
			velocity = 0.0
			target = _scrollable_at(event.position)
		else:
			pressing = false
			if dragging:
				dragging = false
				# Doigt resté immobile avant de lâcher : pas d'élan.
				if Time.get_ticks_msec() - last_motion_time > 100:
					velocity = 0.0
				_hide_from_buttons(event)

	elif event is InputEventMouseMotion and pressing and target != null:
		if not dragging:
			if event.position.distance_to(press_position) < DRAG_THRESHOLD:
				return  # petit tremblement du doigt : c'est encore un simple appui
			dragging = true
			last_motion_time = Time.get_ticks_msec()
		_scroll_by(-event.relative.y)
		# Vitesse du doigt, lissée pour éviter les à-coups.
		var now := Time.get_ticks_msec()
		var seconds := maxf((now - last_motion_time) / 1000.0, 0.001)
		velocity = lerpf(velocity, -event.relative.y / seconds, 0.4)
		last_motion_time = now
		_hide_from_buttons(event)


## Élan après avoir lâché : la liste continue de défiler en ralentissant.
func _process(delta: float) -> void:
	if pressing or velocity == 0.0:
		return
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		velocity = 0.0
		return
	_scroll_by(velocity * delta)
	velocity *= exp(-FRICTION * delta)
	if absf(velocity) < MIN_SPEED:
		velocity = 0.0


func _scroll_by(amount: float) -> void:
	if is_instance_valid(target):
		target.get_v_scroll_bar().value += amount


## Envoie l'événement « très loin » : les boutons ne se déclenchent pas,
## et la ScrollContainer ne fait pas défiler une deuxième fois de son côté.
func _hide_from_buttons(event: InputEventMouse) -> void:
	event.position = FAR_AWAY
	event.global_position = FAR_AWAY
	if event is InputEventMouseMotion:
		event.relative = Vector2.ZERO


## Trouve la zone qui défile sous le doigt : on cherche l'élément d'interface touché
## (celui du dessus), puis on remonte ses parents jusqu'à une zone qui peut défiler.
func _scrollable_at(point: Vector2) -> Control:
	var node: Node = null
	var children := get_tree().root.get_children()
	for i in range(children.size() - 1, -1, -1):
		if children[i] is Control:
			node = _control_at(children[i], point)
			if node != null:
				break
	while node is Control:
		if (node is ScrollContainer or node is RichTextLabel) and _can_scroll(node):
			return node
		node = node.get_parent()
	return null


## L'élément d'interface le plus « au-dessus » qui contient ce point (ou null).
## Les enfants dessinés en dernier sont devant : on les regarde en premier.
func _control_at(control: Control, point: Vector2) -> Control:
	if not control.visible:
		return null
	var inside := control.get_global_rect().has_point(point)
	# Une zone qui coupe ce qui dépasse (comme une liste) : ses enfants cachés ne comptent pas.
	if control.clip_contents and not inside:
		return null
	for i in range(control.get_child_count() - 1, -1, -1):
		var child := control.get_child(i)
		if child is Control:
			var found := _control_at(child, point)
			if found != null:
				return found
	if inside and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return control
	return null


func _can_scroll(control: Control) -> bool:
	var bar: ScrollBar = control.get_v_scroll_bar()
	return bar.max_value > bar.page
