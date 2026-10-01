class_name SummonScreen
extends Control
## Écran d'invocation : deux sortes d'invocation (voir GameData.SUMMON_TYPES),
## chacune avec ses boutons x1 et x10, et l'affichage des héros obtenus.
## - normale : payée en or, héros de base ;
## - spéciale : payée en gemmes, meilleures chances de hauts rangs, seule à donner des mages.
## Avec les nouveaux visuels (réglage Settings.new_visuals) : fond de portail, voile sombre, et
## boutons illustrés (SummonButton) ; sinon, les anciens boutons simples, pour comparer.

const PORTAL_IMAGE := preload("res://assets/ui/piste-fond-portail.jpg")
## Voile sombre posé sur le portail, pour que les boutons et les textes restent lisibles.
const VEIL_ALPHA := 0.4
## Couleur du vortex de chaque bouton illustré : [rotation de teinte en degrés, saturation].
## Normale (or) : vortex doré (x10) et cuivré (x1). Spéciale (gemmes) : rouge (x10) et violet (x1).
const VORTEX_COLORS := {
	"normal": {10: [-62.0, 1.0], 1: [-38.0, 0.8]},
	"special": {10: [0.0, 1.0], 1: [58.0, 1.0]},
}

var pity_label: Label
var roster_label: Label
var results_grid: GridContainer
## Boutons d'invocation : [sorte, nombre, bouton], pour les griser quand on ne peut pas payer.
var summon_buttons: Array = []
var reveal_tween: Tween


func _ready() -> void:
	_build_ui()
	GameData.gems_changed.connect(func(_amount): _refresh_labels())
	GameData.gold_changed.connect(func(_amount): _refresh_labels())
	Settings.visuals_changed.connect(_rebuild)
	_refresh_labels()


## Changement de visuels (paramètres) : on reconstruit tout l'écran.
func _rebuild() -> void:
	if reveal_tween:
		reveal_tween.kill()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	summon_buttons.clear()
	_build_ui()
	_refresh_labels()


func on_shown() -> void:
	_refresh_labels()


func _on_summon(summon_type: String, count: int) -> void:
	var heroes := GameData.summon(summon_type, count)
	if heroes.is_empty():
		return
	_show_results(heroes)
	_refresh_labels()


## Affiche les cartes des héros obtenus, l'une après l'autre.
func _show_results(heroes: Array[Dictionary]) -> void:
	if reveal_tween:
		reveal_tween.kill()
	for child in results_grid.get_children():
		results_grid.remove_child(child)
		child.queue_free()

	reveal_tween = create_tween()
	for hero in heroes:
		var card := UI.make_hero_card(hero)
		card.modulate.a = 0.0
		results_grid.add_child(card)
		reveal_tween.tween_property(card, "modulate:a", 1.0, 0.15)


func _refresh_labels() -> void:
	pity_label.text = "Invocation spéciale : 5 étoiles garanti dans %d invocations" % GameData.summons_before_pity()
	roster_label.text = "Héros possédés : %d" % GameData.roster.size()
	for entry in summon_buttons:
		var affordable := GameData.can_afford(entry[0], entry[1])
		if entry[2] is SummonButton:
			entry[2].set_affordable(affordable)
		else:
			entry[2].disabled = not affordable


func _build_ui() -> void:
	if Settings.new_visuals:
		# Le portail en plein écran (rogné sur les côtés s'il le faut, jamais déformé), puis le voile.
		var portal := TextureRect.new()
		portal.texture = PORTAL_IMAGE
		portal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portal.set_anchors_preset(Control.PRESET_FULL_RECT)
		portal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(portal)
		var veil := ColorRect.new()
		veil.color = Color(0, 0, 0, VEIL_ALPHA)
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(veil)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var title := UI.make_label("Salle d'invocation", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	pity_label = UI.make_label("", 22)
	pity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(pity_label)

	var results_area := CenterContainer.new()
	results_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(results_area)
	results_grid = GridContainer.new()
	results_grid.columns = 5
	results_grid.add_theme_constant_override("h_separation", 8)
	results_grid.add_theme_constant_override("v_separation", 8)
	results_area.add_child(results_grid)

	roster_label = UI.make_label("", 24)
	roster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(roster_label)

	if Settings.new_visuals:
		_add_illustrated_summons(layout)
	else:
		_add_plain_summons(layout)
	# (Les anciens boutons de test « +1000 gemmes »... sont remplacés par le mode dev.)


## Nouveaux visuels : une colonne par sorte d'invocation (nom, chances, « Détail des taux »),
## avec ses deux boutons illustrés x1 et x10 côte à côte.
func _add_illustrated_summons(layout: VBoxContainer) -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	layout.add_child(columns)
	for summon_type in GameData.SUMMON_TYPES:
		var info: Dictionary = GameData.SUMMON_TYPES[summon_type]
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 6)
		columns.add_child(column)
		var name_label := UI.make_label(info["name"], 24)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 4)
		column.add_child(name_label)
		var rates := UI.make_label(_rates_text(info), 15)
		rates.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rates.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rates.modulate = Color(1, 1, 1, 0.75)
		rates.custom_minimum_size.y = 48  # deux lignes, pour que les boutons des deux colonnes soient alignés
		column.add_child(rates)
		var details := UI.make_button("Détail des taux", func(): _show_rates(summon_type), 18)
		column.add_child(details)
		var buttons := HBoxContainer.new()
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons.add_theme_constant_override("separation", 8)
		column.add_child(buttons)
		for count in [1, 10]:
			var color: Array = VORTEX_COLORS[summon_type][count]
			var button := SummonButton.new(count, info["cost"] * count, info["currency"] == "gems",
				color[0], color[1], 150)
			button.pressed.connect(func(): _on_summon(summon_type, count))
			buttons.add_child(button)
			summon_buttons.append([summon_type, count, button])


## Anciens visuels : une ligne par sorte d'invocation, son nom, ses chances, puis les boutons x1 et x10.
func _add_plain_summons(layout: VBoxContainer) -> void:
	for summon_type in GameData.SUMMON_TYPES:
		var info: Dictionary = GameData.SUMMON_TYPES[summon_type]
		var header := HBoxContainer.new()
		layout.add_child(header)
		var name_label := UI.make_label(info["name"], 26)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name_label)
		var details := UI.make_button("Détail des taux", func(): _show_rates(summon_type), 20)
		header.add_child(details)
		var rates := UI.make_label(_rates_text(info), 18)
		rates.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rates.modulate = Color(1, 1, 1, 0.65)
		layout.add_child(rates)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 16)
		layout.add_child(buttons)
		for count in [1, 10]:
			var button := _make_summon_button(summon_type, count)
			buttons.add_child(button)
			summon_buttons.append([summon_type, count, button])


## Fenêtre du détail des taux : pour chaque rareté d'étoiles, la répartition des classes.
func _show_rates(summon_type: String) -> void:
	var info: Dictionary = GameData.SUMMON_TYPES[summon_type]
	var lines := []
	for rarity in info["rates"]:
		if info["rates"][rarity] <= 0.0:
			continue
		var classes := []
		var rates := GameData.class_rates(rarity, info["mages"])
		for hero_class in rates:
			classes.append("%s %s %%" % [hero_class, _percent(rates[hero_class])])
		lines.append("%d★ (%s %%) : %s" % [rarity, _percent(info["rates"][rarity]), ", ".join(classes)])

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	overlay.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	box.add_child(UI.make_system_window(info["name"], lines))
	var close := UI.make_button("Fermer", func(): overlay.queue_free(), 24)
	close.custom_minimum_size.y = 80
	box.add_child(close)


## Un pourcentage lisible : 0.012 -> « 1,2 », 0.3 -> « 30 ».
func _percent(rate: float) -> String:
	var value := rate * 100.0
	var text := str(roundi(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 1)
	return text.replace(".", ",")


## « 5★ 0,2 %  4★ 1,8 %  ... » (+ « mages possibles » pour la spéciale).
func _rates_text(info: Dictionary) -> String:
	var parts := []
	for rarity in info["rates"]:
		if info["rates"][rarity] <= 0.0:
			continue  # rareté impossible avec cette invocation : on ne l'affiche pas
		parts.append("%d★ %s %%" % [rarity, _percent(info["rates"][rarity])])
	var text := "  ".join(parts)
	if info["mages"]:
		text += "  — mages : très très rares"
	return text


func _make_summon_button(summon_type: String, count: int) -> Button:
	var info: Dictionary = GameData.SUMMON_TYPES[summon_type]
	var currency := "or" if info["currency"] == "gold" else "gemmes"
	var text := "x%d\n%d %s" % [count, info["cost"] * count, currency]
	var button := UI.make_button(text, func(): _on_summon(summon_type, count), 24)
	button.custom_minimum_size.y = 90
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button
