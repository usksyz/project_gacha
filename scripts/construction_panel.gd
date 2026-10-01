class_name ConstructionPanel
extends Control
## Fenêtre de construction (bouton « Construction » du hub) : la forge et les bâtiments de magie
## (ceux-là seulement avec un mage parmi ses héros ; règles dans GameData, section
## « Construction »). S'affiche par-dessus l'écran ; on l'ouvre avec open().

var list: VBoxContainer
var result: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Fond sombre qui bloque les appuis sur ce qu'il y a en dessous.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	layout.add_child(UI.make_system_window("Mode de construction",
		["Les bâtiments se paient en gemmes. Ceux de magie demandent un mage parmi tes héros."]))
	var scroll := UI.make_scroll()  # la liste défile s'il y a trop de bâtiments
	layout.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	result = UI.make_label("", 22)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_color_override("font_color", Color("5fd4c4"))
	layout.add_child(result)
	var close := UI.make_button("Fermer", func(): visible = false, 24)
	close.custom_minimum_size.y = 80
	layout.add_child(close)


func open() -> void:
	result.text = ""
	_refresh()
	visible = true


## Une carte par bâtiment : nom, rôle, et bouton « Construire » (ou la raison du refus).
func _refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var hall_done := GameData.has_magic_hall()
	if hall_done:
		var hall := UI.make_label("%s : construit (atelier de magie, laboratoire d'alchimie et bibliothèque réunis)." \
			% GameData.MAGIC_HALL_NAME, 22)
		hall.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(hall)
	for building_id in GameData.BUILDINGS:
		if hall_done and building_id in GameData.MAGIC_BUILDINGS:
			continue  # déjà réunis dans le Hall de magie
		var info: Dictionary = GameData.BUILDINGS[building_id]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.make_panel_style(Color("262a3b"), Color("9b6be0"), 2))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		panel.add_child(box)
		box.add_child(UI.make_label(info["name"], 24))
		var role := UI.make_label(info["info"] + ("" if building_id == "forge" else " (fonction à venir)"), 18)
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role.modulate = Color(1, 1, 1, 0.7)
		box.add_child(role)
		var problem := GameData.build_problem(building_id)
		var text := "Construire (%d gemmes)" % info["cost"]
		if building_id in GameData.buildings:
			text = "Construit"
		elif problem != "":
			text = problem
		var button := UI.make_button(text, func(): _build(building_id), 22)
		button.custom_minimum_size.y = 64
		button.disabled = problem != ""
		if problem == "" and Settings.new_visuals:
			# Nouveaux visuels : « Construire : 500 » suivi du cristal des gemmes, posé sur le bouton.
			button.text = ""
			var price := CenterContainer.new()
			price.set_anchors_preset(Control.PRESET_FULL_RECT)
			price.mouse_filter = Control.MOUSE_FILTER_IGNORE
			price.add_child(UI.make_gem_amount("Construire : %d" % info["cost"], 22))
			button.add_child(price)
		box.add_child(button)
		list.add_child(panel)


func _build(building_id: String) -> void:
	var messages := GameData.build(building_id)
	result.text = "\n".join(messages)
	_refresh()
