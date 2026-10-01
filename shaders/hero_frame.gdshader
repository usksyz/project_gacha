shader_type canvas_item;
// Cadre de carte de héros, dessiné avec l'image assets/ui/ref-cadre-carte-portrait.jpg (286 x 512 px).
// Toutes les positions ci-dessous sont en pixels de cette image.
// - le fond blanc autour du cadre devient transparent (détourage) ;
// - la fenêtre du milieu est percée : on voit le portrait du héros, posé sous le cadre ;
// - le bandeau du haut (« UNITÉ SSR ») et l'encart du bas (« LV / ATK / Rarity ») sont cachés sous des
//   plaques sombres, sur lesquelles le jeu pose nos étoiles, le niveau et les stats ;
// - le métal et les ornements prennent la teinte de la rareté (bronze, argent, or...) ; les runes
//   bleues gardent leur couleur.

uniform vec2 image_size = vec2(286.0, 512.0);
// Zone où l'on n'efface pas le blanc (l'intérieur du cadre peut avoir des reflets très clairs).
uniform vec4 inner_rect = vec4(44.0, 62.0, 242.0, 452.0);
// Fenêtre du portrait : (gauche, haut, droite, bas) et rayon des coins arrondis.
uniform vec4 window_rect = vec4(66.0, 102.0, 220.0, 360.0);
uniform float window_radius = 34.0;
uniform vec4 banner_rect = vec4(100.0, 67.0, 186.0, 91.0);
uniform vec4 plate_rect = vec4(86.0, 371.0, 200.0, 430.0);
uniform vec3 plate_color = vec3(0.05, 0.055, 0.07);
// Teinte de la rareté, et sa force (0 = couleurs d'origine).
uniform vec3 metal_tint = vec3(1.0);
uniform float tint_strength = 0.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float rect_mask(vec2 p, vec4 r, float soft) {
	vec2 a = smoothstep(r.xy - soft, r.xy + soft, p);
	vec2 b = 1.0 - smoothstep(r.zw - soft, r.zw + soft, p);
	return a.x * a.y * b.x * b.y;
}

// 1 dans le rectangle aux coins arrondis, 0 dehors (bord adouci).
float rounded_mask(vec2 p, vec4 r, float radius, float soft) {
	vec2 center = (r.xy + r.zw) * 0.5;
	vec2 half_size = (r.zw - r.xy) * 0.5 - radius;
	vec2 d = abs(p - center) - half_size;
	float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
	return 1.0 - smoothstep(-soft, soft, dist);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 p = UV * image_size;

	// Détourage du fond blanc (seulement autour du cadre).
	float inner = rect_mask(p, inner_rect, 4.0);
	float keep = max(inner, smoothstep(0.06, 0.22, distance(col.rgb, vec3(1.0))));

	// Fenêtre du portrait : on perce le fond sombre et bleuté, on garde les ornements clairs.
	float window = rounded_mask(p, window_rect, window_radius, 3.0);
	float luminance = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float ornament = smoothstep(0.28, 0.42, max(col.r, luminance));
	keep *= 1.0 - window * (1.0 - ornament);

	// Teinte de la rareté sur le métal et les ornements (pas sur les runes bleues).
	float rune = smoothstep(0.04, 0.18, col.b - col.r);
	vec3 tinted = luminance * metal_tint * 1.7;
	col.rgb = mix(col.rgb, tinted, tint_strength * (1.0 - rune));

	// Plaques sombres sur les textes de l'image.
	for (int k = 0; k < 2; k++) {
		vec4 r = k == 0 ? banner_rect : plate_rect;
		float m = rect_mask(p, r, 2.5);
		float middle = 1.0 - abs((p.y - r.y) / (r.w - r.y) - 0.5) * 2.0;
		col.rgb = mix(col.rgb, plate_color * (0.8 + 0.4 * middle), m * 0.97);
	}

	col.a *= keep;
	COLOR = col * tint;
}
