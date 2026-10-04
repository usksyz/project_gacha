class_name TeamSlots
extends HBoxContainer
## Les places d'un groupe de héros (cahier : onglet « Formation de groupe », le Maître glisse-dépose
## les héros) : TEAM_SIZE cases, une carte par héros, une place libre « + » sinon.
## - maintenir une carte de héros (dans la liste) puis la glisser sur une case : il rejoint le groupe
##   (sur une case occupée, il prend la place de l'autre) ;
## - glisser une carte du groupe sur une autre case : les deux échangent leur place ;
## - glisser une carte du groupe vers la liste (make_removal_zone) : il quitte le groupe ;
## - toucher une carte du groupe la retire aussi (comme avant).
## On maintient d'abord le doigt (HOLD_SECONDS) : un glissement direct fait défiler la liste.

## Le groupe a changé : les numéros des héros, dans l'ordre des cases.
signal changed(hero_ids: Array)

## Temps à garder le doigt sur une carte avant de pouvoir la glisser (secondes).
const HOLD_SECONDS := 0.3
## Au-delà de ce déplacement (pixels) avant la fin de l'appui, c'est un défilement, pas une prise.
const HOLD_TOLERANCE := 14.0

var hero_ids: Array = []
var slot_width := 108.0


func _init() -> void:
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_CENTER


## Affiche le groupe « ids » (numéros des héros).
func set_heroes(ids: Array) -> void:
	hero_ids = ids.duplicate()
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var slot_size := FramedHeroCard.size_for(slot_width) if Settings.new_visuals else Vector2(slot_width, 150)
	for index in GameData.TEAM_SIZE:
		var slot: Control
		if index < hero_ids.size():
			var hero := GameData.hero_by_id(hero_ids[index])
			var card := UI.make_card(hero, slot_width)
			card.custom_minimum_size = slot_size
			UI.add_mental_bar(card, hero)
			# Un ami ou un frère d'armes dans le même groupe : le symbole de lien.
			var bond := UI.best_team_bond(hero, hero_ids)
			if bond > 0:
				UI.add_bond_badge(card, bond)
			make_draggable(card, hero, "slot", index)
			card.pressed.connect(func():
				if not card.get_meta("dragged", false):
					_remove(hero["id"]))  # toucher une carte la retire
			slot = card
		else:
			var empty := PanelContainer.new()
			empty.custom_minimum_size = slot_size
			empty.add_theme_stylebox_override("panel", UI.make_panel_style(Color("1b1d2a"), Color("3a3f55"), 2))
			var plus := UI.make_label("+", 40)
			plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			plus.modulate = Color(1, 1, 1, 0.3)
			empty.add_child(plus)
			slot = empty
		slot.set_drag_forwarding(Callable(), _can_drop.bind(index), _drop.bind(index))
		add_child(slot)


func _remove(hero_id: int) -> void:
	var ids := hero_ids.duplicate()
	ids.erase(hero_id)
	changed.emit(ids)


func _can_drop(_at: Vector2, data: Variant, _index: int) -> bool:
	return data is Dictionary and data.has("hero_id")


## Une carte lâchée sur la case « index ».
func _drop(_at: Vector2, data: Variant, index: int) -> void:
	var ids := hero_ids.duplicate()
	var hero_id: int = data["hero_id"]
	if data["from"] == "slot":
		# Échange de places entre deux cases du groupe.
		var from: int = data["index"]
		if index >= ids.size():
			ids.erase(hero_id)
			ids.append(hero_id)
		else:
			var other = ids[index]
			ids[index] = hero_id
			ids[from] = other
	elif hero_id in ids:
		return  # déjà dans le groupe
	elif index < ids.size():
		ids[index] = hero_id  # il prend la place de l'autre, qui quitte le groupe
	elif ids.size() < GameData.TEAM_SIZE:
		ids.append(hero_id)
	changed.emit(ids)


## Rend une carte de héros « prenable » : maintenir le doigt dessus puis la glisser.
## « source » : "grid" (la liste des héros) ou "slot" (une case du groupe, numéro « index »).
## Après une prise, la carte porte la marque « dragged » : son appui ne compte pas comme un toucher.
static func make_draggable(card: BaseButton, hero: Dictionary, source: String, index := -1) -> void:
	var state := {"down": false, "position": Vector2.ZERO, "token": 0}
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			state["down"] = event.pressed
			if not event.pressed:
				return
			card.set_meta("dragged", false)
			state["position"] = event.global_position
			state["token"] += 1
			var token: int = state["token"]
			card.get_tree().create_timer(HOLD_SECONDS).timeout.connect(func():
				if state["down"] and state["token"] == token and is_instance_valid(card) and card.is_visible_in_tree():
					_start_drag(card, hero, source, index))
		elif event is InputEventMouseMotion and state["down"]:
			if event.global_position.distance_to(state["position"]) > HOLD_TOLERANCE and not card.get_meta("dragged", false):
				state["down"] = false  # le doigt a bougé tout de suite : c'est un défilement
	)


static func _start_drag(card: BaseButton, hero: Dictionary, source: String, index: int) -> void:
	card.set_meta("dragged", true)
	Settings.vibrate(30)
	# Le bouton ne doit pas se déclencher quand on lâchera : on annule son appui.
	card.disabled = true
	card.disabled = false
	var preview := UI.make_card(hero, 96)
	preview.modulate = Color(1, 1, 1, 0.85)
	preview.position = -preview.custom_minimum_size / 2.0
	var holder := Control.new()  # la carte suit le doigt, centrée dessous
	holder.add_child(preview)
	card.force_drag({"hero_id": hero["id"], "from": source, "index": index}, holder)


## Une zone (la liste des héros) où lâcher une carte du groupe la retire du groupe.
static func make_removal_zone(zone: Control, on_remove: Callable) -> void:
	zone.set_drag_forwarding(Callable(),
		func(_at: Vector2, data: Variant) -> bool:
			return data is Dictionary and data.get("from", "") == "slot",
		func(_at: Vector2, data: Variant) -> void:
			on_remove.call(data["hero_id"]))
