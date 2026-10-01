class_name FramedHeroCard
extends Button
## Carte de héros avec le cadre illustré (nouveaux visuels) : image ref-cadre-carte-portrait.jpg,
## détourée et teintée par le shader hero_frame.gdshader.
## Le portrait est posé au centre, le cadre par-dessus (sa fenêtre est percée).
## En haut : les étoiles. Sur le portrait : le nom et la classe. En bas : le niveau, et les stats
## (Force, Intelligence, Santé, Dextérité) sur une grande carte (« detailed »).

const IMAGE := preload("res://assets/ui/ref-cadre-carte-portrait.jpg")
const SHADER := preload("res://shaders/hero_frame.gdshader")
## Partie de l'image gardée : le cadre (en pixels de l'image, qui fait 286 x 512).
const CROP := Rect2(18, 40, 250, 436)
## Mêmes rectangles que dans le shader, en pixels de l'image.
const WINDOW_RECT := Rect2(66, 102, 154, 258)
const BANNER_RECT := Rect2(100, 67, 86, 24)
const PLATE_RECT := Rect2(86, 371, 114, 59)
## Zone du nom et de la classe, en bas de la fenêtre du portrait.
const NAME_RECT := Rect2(66, 296, 154, 62)
## Teinte du cadre selon les étoiles : [couleur, force de la teinte]. Chiffres à valider.
const RARITY_METALS := {
	1: [Color("b8743e"), 0.9],   # bronze
	2: [Color("8e9ba8"), 0.9],   # fer
	3: [Color("c2ccd8"), 0.85],  # argent
	4: [Color("f0c050"), 0.55],  # or
	5: [Color("ff9a5a"), 0.6],   # or rouge (légendaire)
}
const OUTLINE_COLOR := Color(0, 0, 0, 0.9)

var hero: Dictionary
## Taille relative de la carte (1 = l'image à sa taille d'origine) : sert aux tailles de texte.
var scale_factor: float


## « width » : largeur de la carte en pixels (la hauteur suit l'image). « detailed » : avec les stats.
func _init(hero_data: Dictionary, width: float, detailed := false) -> void:
	hero = hero_data
	scale_factor = width / CROP.size.x
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = size_for(width)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

	# Le portrait d'abord (dessous), puis le cadre par-dessus.
	var portrait := HeroPortrait.new()
	portrait.hero = hero
	_place(portrait, WINDOW_RECT)
	add_child(portrait)

	var texture := AtlasTexture.new()
	texture.atlas = IMAGE
	texture.region = CROP
	var frame := TextureRect.new()
	frame.texture = texture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_material := ShaderMaterial.new()
	frame_material.shader = SHADER
	var metal: Array = RARITY_METALS[hero["rarity"]]
	frame_material.set_shader_parameter("metal_tint", metal[0])
	frame_material.set_shader_parameter("tint_strength", metal[1])
	frame.material = frame_material
	add_child(frame)

	# Étoiles sur le bandeau du haut (« 3★ » sur une petite carte, faute de place).
	var star_color: Color = GameData.RARITY_COLORS[hero["rarity"]].lightened(0.25)
	var stars_text := "★".repeat(hero["rarity"]) if scale_factor > 0.7 else "%d★" % hero["rarity"]
	var stars := _make_label(stars_text, 16 if detailed else 26, star_color)
	stars.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(stars, BANNER_RECT)
	add_child(stars)

	# Nom et classe, en bas du portrait.
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_END
	names.add_theme_constant_override("separation", 0)
	_place(names, NAME_RECT)
	names.add_child(_make_label(hero["name"], 26, Color.WHITE))
	names.add_child(_make_label(hero["class"], 17, Color(1, 1, 1, 0.75)))
	add_child(names)

	# Encart du bas : le niveau, et les stats sur une grande carte.
	var plate := VBoxContainer.new()
	plate.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_theme_constant_override("separation", -2)
	_place(plate, PLATE_RECT)
	var level_text := "Niv. %d" % hero["level"]
	if detailed:
		level_text = "Niv. %d / %d" % [hero["level"], GameData.MAX_LEVEL[hero["rarity"]]]
	plate.add_child(_make_label(level_text, 15 if detailed else 27, Color("f5c45a")))
	if detailed:
		var s: Dictionary = hero["stats"]
		plate.add_child(_make_label("For %d · Int %d" % [s["str"], s["int"]], 14, Color("9ef3ff")))
		plate.add_child(_make_label("San %d · Dex %d" % [s["vit"], s["dex"]], 14, Color("9ef3ff")))
	add_child(plate)

	if not hero["alive"]:
		modulate = Color(0.45, 0.45, 0.45)


## Taille d'une carte de cette largeur (la hauteur suit les proportions de l'image).
static func size_for(width: float) -> Vector2:
	return Vector2(width, roundf(width * CROP.size.y / CROP.size.x))


## Place un nœud sur un rectangle de l'image (ses ancres suivent la taille de la carte).
func _place(node: Control, rect: Rect2) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.anchor_left = (rect.position.x - CROP.position.x) / CROP.size.x
	node.anchor_right = (rect.end.x - CROP.position.x) / CROP.size.x
	node.anchor_top = (rect.position.y - CROP.position.y) / CROP.size.y
	node.anchor_bottom = (rect.end.y - CROP.position.y) / CROP.size.y


## Texte centré avec un contour noir. « size » : taille sur une carte à l'échelle 1 (réduite sinon).
func _make_label(text: String, size: int, color: Color) -> Label:
	var label := UI.make_label(text, maxi(9, roundi(size * scale_factor)))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", maxi(2, roundi(4 * scale_factor)))
	label.clip_text = true
	return label


## Portrait provisoire, en attendant de vraies illustrations : un fond à la couleur de la rareté
## et l'initiale du héros.
class HeroPortrait extends Control:
	var hero: Dictionary

	func _draw() -> void:
		var color: Color = GameData.RARITY_COLORS[hero["rarity"]]
		draw_rect(Rect2(Vector2.ZERO, size), color.darkened(0.82))
		var center := Vector2(size.x / 2, size.y * 0.4)
		for i in 6:  # halo : des disques de plus en plus petits et opaques
			draw_circle(center, size.x * (0.55 - i * 0.07), Color(color, 0.08 + i * 0.03))
		var font := get_theme_default_font()
		var font_size := int(size.x * 0.55)
		var letter: String = hero["name"].left(1).to_upper()
		var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(center.x - width / 2, center.y + font_size * 0.35), letter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.85))
