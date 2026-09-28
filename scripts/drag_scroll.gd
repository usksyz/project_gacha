extends Node
## Défilement « comme sur un téléphone » : on appuie n'importe où dans une zone qui défile
## (Collection, journal de combat, paramètres...), même sur un bouton ou une carte,
## et on glisse le doigt pour faire défiler. Marche aussi à la souris (clic maintenu).
## Après avoir lâché, la liste continue un peu sur son élan.
##
## Chargé automatiquement (« autoload ») : toutes les ScrollContainer et RichTextLabel
## du jeu en profitent, sans rien ajouter dans les écrans.
##
## Pour que le bouton sous le doigt (une carte de héros...) ne s'active pas après un
## glissement, on annule son appui dès que le glissement commence.

## Distance (en pixels) à parcourir avant qu'un appui devienne un glissement.
const DRAG_THRESHOLD := 12.0

## Freinage de l'élan (plus c'est grand, plus la liste s'arrête vite).
const FRICTION := 4.0

## En dessous de cette vitesse (pixels par seconde), l'élan s'arrête.
const MIN_SPEED := 30.0

## Vitesse maximale de l'élan (pixels par seconde).
const MAX_SPEED := 2500.0

## La vitesse de l'élan est mesurée sur la fin du geste (en millisecondes).
const VELOCITY_WINDOW := 100

const FAR_AWAY := Vector2(-100000, -100000)

var pressing := false
var dragging := false
var press_position := Vector2.ZERO
## La zone qui défile (trouvée au moment de l'appui).
var target: Control = null
## Le bouton sous le doigt au moment de l'appui (ou null).
var pressed_button: BaseButton = null
## Vitesse de l'élan, en pixels par seconde.
var velocity := 0.0
## Derniers déplacements du doigt : [instant en millisecondes, distance en pixels].
var recent_moves: Array = []


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressing = true
			dragging = false
			press_position = event.position
			velocity = 0.0
			recent_moves.clear()
			var touched := _control_at_point(event.position)
			target = _scrollable_parent(touched)
			pressed_button = _button_parent(touched)
		else:
			pressing = false
			if dragging:
				dragging = false
				velocity = _release_velocity()
				_hide_from_buttons(event)

	elif event is InputEventMouseMotion and pressing and target != null:
		if not dragging:
			if event.position.distance_to(press_position) < DRAG_THRESHOLD:
				return  # petit tremblement du doigt : c'est encore un simple appui
			dragging = true
			_cancel_button_press()
		_scroll_by(-event.relative.y)
		recent_moves.append([Time.get_ticks_msec(), -event.relative.y])
		_hide_from_buttons(event)


## Annule l'appui du bouton sous le doigt : le désactiver remet à zéro son état
## « enfoncé », et on le réactive aussitôt. Il ne se déclenchera donc pas quand on lâche.
func _cancel_button_press() -> void:
	if is_instance_valid(pressed_button) and not pressed_button.disabled:
		pressed_button.disabled = true
		pressed_button.disabled = false
	pressed_button = null


## Vitesse du doigt au moment où il lâche : la distance parcourue pendant les
## 100 dernières millisecondes, divisée par ce temps. Si le doigt s'était arrêté
## avant de lâcher, il n'y a pas d'élan.
func _release_velocity() -> float:
	var now := Time.get_ticks_msec()
	var distance := 0.0
	var oldest := now
	for move in recent_moves:
		if now - move[0] <= VELOCITY_WINDOW:
			distance += move[1]
			oldest = mini(oldest, move[0])
	# Au moins 1/60 de seconde, pour ne pas diviser par (presque) zéro.
	var seconds := maxf((now - oldest) / 1000.0, 1.0 / 60.0)
	return clampf(distance / seconds, -MAX_SPEED, MAX_SPEED)


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


## Envoie l'événement « très loin », pour que rien d'autre ne réagisse au glissement
## (la ScrollContainer ne fait pas défiler une deuxième fois de son côté).
func _hide_from_buttons(event: InputEventMouse) -> void:
	event.position = FAR_AWAY
	event.global_position = FAR_AWAY
	if event is InputEventMouseMotion:
		event.relative = Vector2.ZERO


## L'élément d'interface touché à cet endroit (celui du dessus), ou null.
func _control_at_point(point: Vector2) -> Control:
	var children := get_tree().root.get_children()
	for i in range(children.size() - 1, -1, -1):
		if children[i] is Control:
			var found := _control_at(children[i], point)
			if found != null:
				return found
	return null


## Remonte les parents de « node » jusqu'à une zone qui peut défiler (ou null).
func _scrollable_parent(node: Node) -> Control:
	while node is Control:
		if (node is ScrollContainer or node is RichTextLabel) and _can_scroll(node):
			return node
		node = node.get_parent()
	return null


## Remonte les parents de « node » jusqu'à un bouton (ou null).
func _button_parent(node: Node) -> BaseButton:
	while node is Control:
		if node is BaseButton:
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
