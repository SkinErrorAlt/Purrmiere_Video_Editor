shader_type canvas_item;
render_mode blend_disabled;

uniform float across : hint_range(8.0, 160.0) = 44.0;
uniform float thread : hint_range(0.08, 0.4) = 0.12;
uniform int shades : hint_range(0, 64) = 0;
uniform float relief : hint_range(0.0, 1.0) = 0.7;
uniform vec4 cloth : source_color = vec4(0.9, 0.87, 0.79, 1.0);
uniform float weave : hint_range(0.0, 1.0) = 0.5;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1920.0, 1080.0);

float stitch_leg(vec2 q, vec2 a, vec2 b) {
	vec2 pa = q - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (strength <= 0.0) {
		COLOR = base;
	} else {
		float ar = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
		float nx = max(across, 8.0);
		float ny = max(floor(nx / max(ar, 0.0001)), 1.0);
		vec2 grid = vec2(nx, ny);
		vec2 cell = floor(UV * grid);
		vec2 q = fract(UV * grid) - 0.5;
		vec3 c = texture(TEXTURE, clamp((cell + 0.5) / grid, vec2(0.0), vec2(1.0))).rgb;
		if (shades > 0) {
			float steps = float(shades);
			c = floor(c * steps + 0.5) / steps;
		}
		float t = max(thread, 0.08);
		float d1 = stitch_leg(q, vec2(-0.38, -0.38), vec2(0.38, 0.38));
		float d2 = stitch_leg(q, vec2(0.38, -0.38), vec2(-0.38, 0.38));
		float over = 1.0 - smoothstep(t - 0.035, t + 0.035, d2);
		float under = 1.0 - smoothstep(t - 0.035, t + 0.035, d1);
		float round_over = clamp(1.0 - d2 / max(t, 0.0001), 0.0, 1.0);
		float round_under = clamp(1.0 - d1 / max(t, 0.0001), 0.0, 1.0);
		vec2 wq = fract(UV * grid * 2.0);
		float warp = (0.5 + 0.5 * cos(wq.x * 6.2831853)) * (0.5 + 0.5 * cos(wq.y * 6.2831853));
		vec3 cloth_col = cloth.rgb * mix(1.0, 0.82 + 0.3 * warp, clamp(weave, 0.0, 1.0));
		vec3 shown = cloth_col;
		vec3 thread_under = c * mix(1.0, 0.65 + 0.7 * pow(round_under, 0.55), relief);
		thread_under *= mix(1.0, 0.72, over * relief);
		shown = mix(shown, thread_under, under);
		vec3 thread_over = c * mix(1.0, 0.7 + 0.75 * pow(round_over, 0.55), relief);
		shown = mix(shown, thread_over, over);
		COLOR = mix(base, vec4(shown, base.a), strength);
	}
}
