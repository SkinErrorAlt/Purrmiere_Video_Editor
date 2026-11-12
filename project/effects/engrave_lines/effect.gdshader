shader_type canvas_item;
render_mode blend_disabled;

uniform float pitch : hint_range(1.0, 40.0) = 8.0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float follow : hint_range(0.0, 1.0) = 0.25;
uniform float bite : hint_range(0.2, 3.0) = 1.0;
uniform float cross : hint_range(0.0, 1.0) = 0.4;
uniform vec4 ink : source_color = vec4(0.07, 0.09, 0.14, 1.0);
uniform vec4 paper : source_color = vec4(0.95, 0.93, 0.86, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float px_scale = 1.0;

float en_lum(sampler2D tex, vec2 uv) {
	return dot(texture(tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb, vec3(0.2126, 0.7152, 0.0722));
}

float rule(float coord, float tone, float gain) {
	float band = fract(coord);
	float ink_width = clamp(pow(1.0 - tone, max(gain, 0.2)), 0.0, 1.0) * 0.92;
	float d = abs(band - 0.5) * 2.0;
	float aa = fwidth(coord) * 2.2 + 0.03;
	return 1.0 - smoothstep(ink_width - aa, ink_width + aa, d);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (strength <= 0.0) {
		COLOR = base;
	} else {
		vec2 px = max(tex_size, vec2(1.0));
		vec2 step_uv = vec2(4.0) / px;
		float l = en_lum(TEXTURE, UV);
		float lx = en_lum(TEXTURE, UV + vec2(step_uv.x, 0.0)) - en_lum(TEXTURE, UV - vec2(step_uv.x, 0.0));
		float ly = en_lum(TEXTURE, UV + vec2(0.0, step_uv.y)) - en_lum(TEXTURE, UV - vec2(0.0, step_uv.y));
		float a0 = radians(angle);
		vec2 dir = vec2(cos(a0), sin(a0));
		vec2 along = normalize(vec2(-ly, lx) + vec2(0.00001, 0.00002));
		vec2 use = normalize(mix(dir, along, clamp(follow, 0.0, 1.0) * smoothstep(0.02, 0.22, length(vec2(lx, ly)))));
		vec2 perp = vec2(-use.y, use.x);
		float scale = px.y / max(pitch * max(px_scale, 0.0001), 0.5);
		vec2 world = vec2(UV.x * px.x / px.y, UV.y);
		float coord = dot(world, perp) * scale;
		float wob = sin(dot(world, use) * scale * 0.7) * 0.18 * follow;
		float line = rule(coord + wob, l, bite);
		float coord2 = dot(world, use) * scale * 1.3;
		float line2 = rule(coord2, clamp(l * 1.45, 0.0, 1.0), bite) * clamp(cross, 0.0, 1.0);
		float covered = clamp(max(line, line2), 0.0, 1.0);
		vec3 shown = mix(paper.rgb, ink.rgb, covered);
		COLOR = mix(base, vec4(shown, base.a), strength);
	}
}
