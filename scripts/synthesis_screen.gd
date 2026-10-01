class_name SynthesisScreen
extends Control
## Chambre de synthèse (ouverte depuis le hub, une fois construite).
## 1. On choisit le héros à renforcer ; 2. on choisit un ou plusieurs héros à sacrifier
## (jusqu'à GameData.SYNTHESIS_MAX_SACRIFICES) ; 3. une fenêtre rouge prévient que les sacrifiés
## disparaîtront pour toujours (Oui / Non) ; 4. le résultat : expérience (au moins un niveau),
## et parfois une compétence héritée, Œil de faucon ou Analyse froide.
## Une recherche et des filtres (HeroFilter) aident à trouver les héros parmi des centaines.
## Les règles sont dans GameData (section « Synthèse de héros »).

## Demande à l'écran principal d'afficher un autre écran (retour au hub).
signal navigate(screen_name: String)

## Au-delà de ce nombre de héros trouvés, on demande d'affiner la recherche.
const MAX_CARDS := 40

var title_label: Label
var info_label: Label
var filter: HeroFilter
var grid: GridContainer
var hint_label: Label
var action_button: Button
## Calque par-dessus l'écran : confirmation et résultat.
var overlay: Control

## Héros à renforcer (vide tant qu'il n'est pas choisi), et héros à sacrifier.
var target: Dictionary = {}
var sacrifices: Array = []


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var back := UI.make_button("← Retour à la cité", func(): navigate.emit("hub"), 22)
	back.custom_minimum_size.y = 64
	layout.add_child(back)
	title_label = UI.make_label("", 28)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(title_label)
	info_label = UI.make_label("", 20)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.modulate = Color(1, 1, 1, 0.8)
	layout.add_child(info_label)
	filter = HeroFilter.new()
	filter.changed.connect(_refresh)
	layout.add_child(filter)

	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var scroll_content := VBoxContainer.new()
	scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_content)
	var centered := CenterContainer.new()
	centered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_content.add_child(centered)
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	centered.add_child(grid)
	hint_label = UI.make_label("", 20)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate = Color(1, 1, 1, 0.7)
	scroll_content.add_child(hint_label)

	action_button = UI.make_button("", _on_action, 26)
	action_button.custom_minimum_size.y = 90
	action_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(action_button)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)


func on_shown() -> void:
	target = {}
	sacrifices = []
	overlay.visible = false
	_refresh()


func _refresh() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	hint_label.text = ""

	if not "synthese" in GameData.buildings:
		title_label.text = "La chambre de synthèse n'est pas construite."
		info_label.text = "Construis-la depuis le hub (bouton « Construction », %d gemmes)." \
			% GameData.BUILDINGS["synthese"]["cost"]
		filter.visible = false
		action_button.visible = false
		return
	filter.visible = true
	action_button.visible = true

	if target.is_empty():
		title_label.text = "1. Choisis le héros à renforcer"
		info_label.text = "Il gagnera de l'expérience (au moins un niveau), et parfois une compétence."
		action_button.text = "Choisis un héros"
		action_button.disabled = true
		_fill_grid(_candidates({}), _choose_target)
		return

	title_label.text = "2. Choisis les héros à sacrifier pour renforcer %s (%s, niv. %d)" % [
		target["name"], "★".repeat(target["rarity"]), target["level"]]
	if sacrifices.is_empty():
		info_label.text = "Jusqu'à %d héros, de n'importe quel rang. Les sacrifiés disparaîtront pour toujours. Les héros légendaires et les favoris (♥) ne peuvent pas être sacrifiés." \
			% GameData.SYNTHESIS_MAX_SACRIFICES
		action_button.text = "Changer de héros à renforcer"
	else:
		info_label.text = _gains_text()
		var names := ", ".join(PackedStringArray(sacrifices.map(func(hero): return hero["name"])))
		action_button.text = "Synthèse : sacrifier %s" % names
	action_button.disabled = false
	# Toucher un héros choisi le relâche ; toucher un autre héros l'ajoute (s'il reste de la place).
	_fill_grid(_candidates(target), _toggle_sacrifice)


## Ce que la synthèse va donner, pour aider à décider.
func _gains_text() -> String:
	var parts := []
	var xp := GameData.synthesis_total_xp(target, sacrifices)
	if xp == 0:
		parts.append("%s est au niveau maximum : l'expérience sera perdue (pense à la promotion)." % target["name"])
	else:
		parts.append("%s gagnera %d d'expérience (au moins un niveau)." % [target["name"], xp])
	parts.append("%d %% de chances de récupérer une compétence de chaque sacrifié." % roundi(GameData.INHERIT_CHANCE * 100))
	if GameData.can_get_hawk_eye(target):
		parts.append("%d %% de chances d'Œil de faucon." % roundi(GameData.HAWK_EYE_CHANCE * 100))
	parts.append("%s %% d'Analyse froide." % String.num(GameData.COLD_ANALYSIS_CHANCE * 100).replace(".", ","))
	return " ".join(PackedStringArray(parts))


## Étape 1 → 2 : le héros à renforcer est choisi ; la recherche repart de zéro pour les sacrifiés.
func _choose_target(hero: Dictionary) -> void:
	target = hero
	filter.search.text = ""


func _toggle_sacrifice(hero: Dictionary) -> void:
	var index := sacrifices.find(hero)
	if index >= 0:
		sacrifices.remove_at(index)
	elif sacrifices.size() < GameData.SYNTHESIS_MAX_SACRIFICES:
		sacrifices.append(hero)


## Les héros qu'on peut choisir : à renforcer (tous les héros vivants à la cité),
## ou à sacrifier pour « for_target » (ceux que GameData accepte), filtrés par la recherche.
func _candidates(for_target: Dictionary) -> Array:
	var result := []
	for hero in GameData.alive_heroes():
		if GameData.is_away(hero):
			continue
		if not for_target.is_empty() and GameData.synthesis_problem(for_target, hero) != "":
			continue
		result.append(hero)
	return filter.apply(result)


## Une carte par héros (MAX_CARDS au plus) ; les sacrifiés choisis passent en premier, en rouge.
func _fill_grid(heroes: Array, on_press: Callable) -> void:
	var shown := sacrifices.duplicate()
	for hero in heroes:
		if shown.size() >= MAX_CARDS:
			break
		if not hero in shown:
			shown.append(hero)
	for hero in shown:
		_add_card(hero, on_press, hero in sacrifices)
	if heroes.is_empty():
		hint_label.text = "Aucun héros ne correspond à la recherche."
	elif heroes.size() > MAX_CARDS:
		hint_label.text = "… et %d autres héros : affine la recherche pour les trouver." % (heroes.size() - MAX_CARDS)


func _add_card(hero: Dictionary, on_press: Callable, chosen := false) -> void:
	var card := UI.make_hero_card(hero)
	if chosen:
		var style := UI.make_panel_style(Color("5a1f1f"), Color("e05252"), 8)
		UI.set_button_style(card, style, style)
	card.pressed.connect(func():
		on_press.call(hero)
		_refresh.call_deferred())
	grid.add_child(card)


func _on_action() -> void:
	if sacrifices.is_empty():
		target = {}  # revenir au choix du héros à renforcer
		_refresh()
		return
	_confirm()


## Fenêtre rouge : le sacrifice est définitif.
func _confirm() -> void:
	var box := _overlay_box()
	var lines := []
	for hero in sacrifices:
		lines.append("%s (%s, niv. %d)" % [hero["name"], "★".repeat(hero["rarity"]), hero["level"]])
	lines.append("%s sacrifié%s pour renforcer %s." % ["sera" if sacrifices.size() == 1 else "seront",
		"" if sacrifices.size() == 1 else "s", target["name"]])
	lines.append("Ils disparaîtront pour toujours, avec leurs armes. Cette action est définitive." \
		if sacrifices.size() > 1 else "Il disparaîtra pour toujours, avec ses armes. Cette action est définitive.")
	lines.append("Confirmer la synthèse ?")
	box.add_child(UI.make_system_window("Attention !", lines, true))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	for entry in [["Non", func(): overlay.visible = false], ["Oui, sacrifier", _do_synthesis]]:
		var button := UI.make_button(entry[0], entry[1], 26)
		button.custom_minimum_size.y = 90
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	overlay.visible = true


func _do_synthesis() -> void:
	var lines := GameData.synthesize(target, sacrifices)
	Settings.vibrate(300)
	var box := _overlay_box()
	box.add_child(UI.make_system_window("Synthèse terminée", lines if not lines.is_empty() else ["La synthèse a échoué."]))
	var ok := UI.make_button("Compris", func():
		overlay.visible = false
		sacrifices = []
		_refresh(), 26)
	ok.custom_minimum_size.y = 90
	box.add_child(ok)


## Vide le calque, puis y met un fond sombre et une boîte centrée.
func _overlay_box() -> VBoxContainer:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
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
	return box
