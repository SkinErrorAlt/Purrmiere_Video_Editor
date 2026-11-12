shader_type canvas_item;
render_mode blend_disabled;

uniform float size : hint_range(0.5, 24.0) = 9.0;
uniform float level : hint_range(0.0, 1.0) = 0.45;
uniform float join : hint_range(0.01, 0.6) = 0.16;
uniform float bend : hint_range(0.0, 1.0) = 0.7;
uniform float wet : hint_range(0.0, 2.0) = 0.9;
uniform float rim : hint_range(0.0, 1.0) = 0.55;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float px_scale = 1.0;

float bb_lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float bb_field(sampler2D tex, vec2 uv, vec2 step_uv) {
	float acc = 0.0;
	float total = 0.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 o = vec2(float(i), float(j));
			float w = exp(-dot(o, o) * 0.35);
			vec2 at = clamp(uv + o * step_uv, vec2(0.0), vec2(1.0));
			acc += bb_lum(texture(tex, at).rgb) * w;
			total += w;
		}
	}
	return acc / max(total, 0.0001);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (strength <= 0.0) {
		COLOR = base;
	} else {
		vec2 px = max(tex_size, vec2(1.0));
		vec2 step_uv = vec2(max(size, 0.5) * max(px_scale, 0.0001)) / px;
		float f = bb_field(TEXTURE, UV, step_uv);
		float e = max(join, 0.01);
		float blob = smoothstep(level - e, level + e, f);
		float fx = bb_field(TEXTURE, UV + vec2(step_uv.x, 0.0), step_uv) - bb_field(TEXTURE, UV - vec2(step_uv.x, 0.0), step_uv);
		float fy = bb_field(TEXTURE, UV + vec2(0.0, step_uv.y), step_uv) - bb_field(TEXTURE, UV - vec2(0.0, step_uv.y), step_uv);
		vec2 slope = vec2(fx, fy);
		float dome = sqrt(max(blob * (1.0 - blob) * 4.0, 0.0));
		vec2 push = slope * bend * 26.0 * step_uv * (0.3 + dome);
		vec2 at = clamp(UV - push, vec2(0.0), vec2(1.0));
		vec4 through = texture(TEXTURE, at);
		vec3 n = normalize(vec3(-slope * 18.0, 1.0));
		vec3 light = normalize(vec3(0.5, -0.65, 0.6));
		float spec = pow(clamp(dot(n, light), 0.0, 1.0), 26.0);
		vec3 shown = mix(base.rgb, through.rgb, blob);
		shown *= 1.0 - dome * rim * 0.65;
		shown += vec3(spec * wet * blob);
		COLOR = mix(base, vec4(shown, base.a), strength);
	}
}
