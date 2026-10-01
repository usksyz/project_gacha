class_name SummonButton
extends Button
## Bouton d'invocation illustré (nouveaux visuels) : l'image ref-bouton-tirage-x10.jpg, détourée par le
## shader summon_button.gdshader, avec nos textes en français posés sur les plaques qui cachent l'anglais.
## La couleur du vortex change selon le bouton (rotation de teinte). Au toucher : halo plus fort et glitch.

const IMAGE := preload("res://assets/ui/ref-bouton-tirage-x10.jpg")
const SHADER := preload("res://shaders/summon_button.gdshader")
## Partie de l'image gardée : la carte et son halo (en pixels de l'image, qui fait 286 x 512).
const CROP := Rect2(40, 82, 220, 346)
## Plaques du shader (title_rect, cost_rect) où l'on pose nos textes, en pixels de l'image.
const TITLE_RECT := Rect2(78, 144, 136, 53)
const COST_RECT := Rect2(70, 300, 140, 38)
const OUTLINE_COLOR := Color(0, 0, 0, 0.9)

var art_material: ShaderMaterial
var effect: Tween


## « count » : 1 ou 10 ; « cost » : « 50 000 or » ; « hue » : rotation de teinte du vortex
## en degrés (0 = rouge d'origine) ; « width » : largeur du bouton (la hauteur suit l'image).
func _init(count: int, cost: String, hue: float, saturation: float, width: float) -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(width, width * CROP.size.y / CROP.size.x)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var texture := AtlasTexture.new()
	texture.atlas = IMAGE
	texture.region = CROP
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_material = ShaderMaterial.new()
	art_material.shader = SHADER
	art_material.set_shader_parameter("vortex_hue", hue)
	art_material.set_shader_parameter("vortex_saturation", saturation)
	art.material = art_material
	add_child(art)

	# Titre sur la plaque du haut : « INVOCATION » en petit, « x10 » en gros et doré.
	var title := VBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", -4)
	_place(title, TITLE_RECT)
	title.add_child(_make_label("INVOCATION", 12, Color("d8dce8")))
	title.add_child(_make_label("x%d" % count, 22, Color("f5c45a")))
	add_child(title)

	var cost_label := _make_label(cost, 13 if cost.length() > 9 else 15, Color("9ef3ff"))
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(cost_label, COST_RECT)
	add_child(cost_label)

	button_down.connect(_play_touch_effect)
	resized.connect(func(): pivot_offset = size / 2)


## Place un nœud sur un rectangle de l'image (ses ancres suivent la taille du bouton).
func _place(node: Control, rect: Rect2) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.anchor_left = (rect.position.x - CROP.position.x) / CROP.size.x
	node.anchor_right = (rect.end.x - CROP.position.x) / CROP.size.x
	node.anchor_top = (rect.position.y - CROP.position.y) / CROP.size.y
	node.anchor_bottom = (rect.end.y - CROP.position.y) / CROP.size.y


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := UI.make_label(text, font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Grisé quand on ne peut pas payer.
func set_affordable(affordable: bool) -> void:
	disabled = not affordable
	modulate = Color.WHITE if affordable else Color(0.5, 0.5, 0.55)


## Au toucher : le halo s'allume, l'image « saute » (glitch) et le bouton grossit un instant.
func _play_touch_effect() -> void:
	if disabled:
		return
	if effect:
		effect.kill()
	effect = create_tween().set_parallel()
	effect.tween_method(_set_param.bind("glow"), 0.0, 1.0, 0.08)
	effect.tween_method(_set_param.bind("glitch"), 0.0, 1.0, 0.06)
	effect.tween_property(self, "scale", Vector2(1.06, 1.06), 0.08)
	effect.chain().tween_method(_set_param.bind("glitch"), 1.0, 0.0, 0.25)
	effect.tween_method(_set_param.bind("glow"), 1.0, 0.0, 0.45)
	effect.tween_property(self, "scale", Vector2.ONE, 0.2)


func _set_param(value: float, param: String) -> void:
	art_material.set_shader_parameter(param, value)
