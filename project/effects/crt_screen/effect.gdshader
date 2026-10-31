shader_type canvas_item;
render_mode blend_disabled;

uniform float curve : hint_range(0.0, 1.0) = 0.25;
uniform float corner : hint_range(0.0, 0.5) = 0.06;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float grille : hint_range(0.0, 1.0) = 0.2;
uniform float grille_gap : hint_range(1.0, 16.0) = 3.0;
uniform float brightness : hint_range(0.5, 3.0) = 1.15;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 p = UV * 2.0 - 1.0;
	vec2 bent = p + p.yx * p.yx * p * curve * 0.5;
	vec2 uv = bent * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 c = texture(TEXTURE, uv);
		float a = c.a;
		vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
		vec2 edge = abs(bent);
		float box = length(max(edge - (1.0 - corner), vec2(0.0))) / max(corner, 0.0001);
		float inside = 1.0 - smoothstep(0.8, 1.0, box);
		float r = length(bent) * 0.7071;
		rgb *= mix(1.0, 1.0 - r * r, vignette);
		float gap = max(grille_gap * max(px_scale, 0.0001), 1.0);
		float g = abs(fract(UV.x * size.x / gap) - 0.5) * 2.0;
		rgb *= mix(1.0, 0.55 + 0.45 * g, grille);
		rgb *= brightness;
		float oa = a * inside;
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
	}
}
