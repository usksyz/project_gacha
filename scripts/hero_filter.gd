class_name HeroFilter
extends VBoxContainer
## Barre de recherche et de filtres pour les longues listes de héros
## (collection, armurerie, terrain d'entraînement) : utile quand on a 200 héros et plus.
## - une recherche par nom (clavier du téléphone ou du PC) ;
## - un filtre par classe et un ordre de tri (listes déroulantes) ;
## - un filtre par nombre d'étoiles (boutons).
## Utilisation : var filter := HeroFilter.new() ; filter.changed.connect(_refresh) ;
## puis filter.apply(liste_de_héros) renvoie les héros à afficher, déjà triés.

## Émis à chaque changement (lettre tapée, filtre ou tri choisi) : l'écran redessine sa liste.
signal changed

const SORTS := ["Rareté", "Niveau", "Nom"]

var search: LineEdit
var class_menu: OptionButton
var sort_menu: OptionButton
## Nombre d'étoiles demandé (0 = toutes).
var stars := 0
var star_buttons: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", 8)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	add_child(top)

	search = LineEdit.new()
	search.placeholder_text = "Rechercher un nom..."
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 60
	search.add_theme_font_size_override("font_size", 22)
	search.text_changed.connect(func(_text): changed.emit())
	top.add_child(search)

	class_menu = _make_menu(["Classes"] + GameData.CLASS_MAIN_STAT.keys())
	top.add_child(class_menu)
	sort_menu = _make_menu(SORTS.map(func(name): return "Tri : " + name))
	top.add_child(sort_menu)

	# Étoiles : « Toutes », puis 1 à 5. Le bouton choisi reste enfoncé.
	var star_row := HBoxContainer.new()
	star_row.add_theme_constant_override("separation", 6)
	add_child(star_row)
	var group := ButtonGroup.new()
	for count in range(0, 6):
		var button := UI.make_button("Toutes" if count == 0 else "%d★" % count, func():
			stars = count
			changed.emit(), 20)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = count == 0
		button.custom_minimum_size.y = 52
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if count > 0:
			button.add_theme_color_override("font_color", GameData.RARITY_COLORS[count])
		star_row.add_child(button)
		star_buttons.append(button)


func _make_menu(items: Array) -> OptionButton:
	var menu := OptionButton.new()
	menu.add_theme_font_size_override("font_size", 20)
	menu.get_popup().add_theme_font_size_override("font_size", 26)
	menu.custom_minimum_size.y = 60
	for item in items:
		menu.add_item(item)
	menu.item_selected.connect(func(_index): changed.emit())
	return menu


## Garde les héros qui correspondent à la recherche et aux filtres, triés selon le choix.
func apply(heroes: Array) -> Array:
	var text := search.text.strip_edges().to_lower()
	var hero_class := "" if class_menu.selected <= 0 else class_menu.get_item_text(class_menu.selected)
	var result := heroes.filter(func(hero):
		return (text == "" or hero["name"].to_lower().contains(text)) \
			and (hero_class == "" or hero["class"] == hero_class) \
			and (stars == 0 or hero["rarity"] == stars))
	var sort_name: String = SORTS[maxi(0, sort_menu.selected)]
	result.sort_custom(func(a, b):
		match sort_name:
			"Niveau":
				if a["level"] != b["level"]:
					return a["level"] > b["level"]
			"Nom":
				if a["name"] != b["name"]:
					return a["name"].naturalnocasecmp_to(b["name"]) < 0
		# Rareté (et, à égalité, les plus rares puis l'ordre d'invocation).
		if a["rarity"] != b["rarity"]:
			return a["rarity"] > b["rarity"]
		return a["id"] < b["id"])
	return result
