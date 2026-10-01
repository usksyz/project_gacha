shader_type canvas_item;
// Bouton d'invocation, dessiné avec l'image assets/ui/ref-bouton-tirage-x10.jpg (286 x 512 px).
// Toutes les positions ci-dessous sont en pixels de cette image.
// - le fond gris autour de la carte devient transparent (détourage) ;
// - les textes anglais (« PULL x10 », « 2000 GEMS ») sont cachés sous des plaques sombres,
//   sur lesquelles le jeu pose ses propres textes en français ;
// - la couleur du vortex change (rotation de teinte) : rouge, doré, violet...
// - « glow » (halo plus fort) et « glitch » (image qui saute) servent à l'effet au toucher.

uniform vec2 image_size = vec2(286.0, 512.0);
// Couleur du fond à effacer, et zone de la carte (dedans, on n'efface rien).
uniform vec3 key_color = vec3(0.161, 0.165, 0.173);
uniform vec4 card_rect = vec4(62.0, 92.0, 242.0, 424.0);
// Plaques qui cachent les textes de l'image : (gauche, haut, droite, bas).
uniform vec4 title_rect = vec4(78.0, 144.0, 214.0, 197.0);
uniform vec4 cost_rect = vec4(70.0, 300.0, 210.0, 338.0);
uniform vec3 plate_color = vec3(0.055, 0.06, 0.075);
// Le vortex : son centre, son rayon, et la rotation de sa teinte (en degrés, 0 = rouge d'origine).
uniform vec2 vortex_center = vec2(138.0, 243.0);
uniform float vortex_radius = 47.0;
uniform float vortex_hue = 0.0;
uniform float vortex_saturation = 1.0;
uniform float glow = 0.0;
uniform float glitch = 0.0;

// 1 dans le rectangle, 0 dehors, avec un bord adouci de « soft » pixels.
float rect_mask(vec2 p, vec4 r, float soft) {
	vec2 a = smoothstep(r.xy - soft, r.xy + soft, p);
	vec2 b = 1.0 - smoothstep(r.zw - soft, r.zw + soft, p);
	return a.x * a.y * b.x * b.y;
}

// Tourne la teinte d'une couleur sans changer sa luminosité (espace YIQ).
vec3 hue_rotate(vec3 c, float degrees, float saturation) {
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	float i = dot(c, vec3(0.596, -0.274, -0.322));
	float q = dot(c, vec3(0.211, -0.523, 0.312));
	float angle = radians(degrees);
	float i2 = (i * cos(angle) - q * sin(angle)) * saturation;
	float q2 = (i * sin(angle) + q * cos(angle)) * saturation;
	return vec3(y + 0.956 * i2 + 0.621 * q2, y - 0.272 * i2 - 0.647 * q2, y - 1.106 * i2 + 1.703 * q2);
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

// Couleur du nœud (modulate), gardée à part : en Godot 4, COLOR dans fragment() contient déjà l'image.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV;
	// Glitch : quelques bandes horizontales décalées au hasard, qui changent très vite.
	if (glitch > 0.0) {
		float band = floor(uv.y * 48.0);
		float h = hash(band + floor(TIME * 24.0) * 7.31);
		uv.x += step(0.72, h) * (h - 0.86) * 0.12 * glitch;
	}
	vec4 col = texture(TEXTURE, uv);
	if (glitch > 0.0) {
		// Les couleurs se séparent un peu (rouge à droite, bleu à gauche).
		float split = 0.012 * glitch;
		col.r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
		col.b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
	}
	vec2 p = uv * image_size;
	// Détourage : hors de la carte, le gris du fond devient transparent (appliqué tout à la fin).
	float in_card = rect_mask(p, card_rect, 6.0);
	float keep = max(in_card, smoothstep(0.035, 0.15, distance(col.rgb, key_color)));

	// Vortex : nouvelle teinte dans le disque.
	float vortex = 1.0 - smoothstep(vortex_radius - 4.0, vortex_radius + 2.0, distance(p, vortex_center));
	col.rgb = mix(col.rgb, clamp(hue_rotate(col.rgb, vortex_hue, vortex_saturation), 0.0, 1.0), vortex);

	// Plaques sombres sur les textes anglais (un peu plus claires au milieu, comme du métal).
	for (int k = 0; k < 2; k++) {
		vec4 r = k == 0 ? title_rect : cost_rect;
		float m = rect_mask(p, r, 3.0);
		float middle = 1.0 - abs((p.y - r.y) / (r.w - r.y) - 0.5) * 2.0;
		col.rgb = mix(col.rgb, plate_color * (0.75 + 0.5 * middle), m * 0.96);
	}

	// Halo : les néons bleus s'allument plus fort.
	float neon = clamp(col.b - col.r, 0.0, 1.0);
	col.rgb += glow * (neon * vec3(0.35, 1.0, 1.2) + 0.12);

	col.a *= keep;
	COLOR = col * tint;
}
