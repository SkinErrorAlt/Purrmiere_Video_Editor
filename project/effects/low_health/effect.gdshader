shader_type canvas_item;
render_mode blend_disabled;

uniform float bpm : hint_range(30.0, 200.0) = 72.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.7;
uniform vec4 colour : source_color = vec4(0.7, 0.0, 0.0, 1.0);
uniform float reach : hint_range(0.0, 1.0) = 0.45;
uniform float redness : hint_range(0.0, 1.0) = 0.7;
uniform float desaturate : hint_range(0.0, 1.0) = 0.65;
uniform float blur : hint_range(0.0, 30.0) = 6.0;
uniform float darken : hint_range(0.0, 1.0) = 0.3;
uniform float thump : hint_range(0.0, 5.0) = 0.8;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float heartbeat(float t) {
	float p = fract(max(t, 0.0) * clamp(bpm, 1.0, 400.0) / 60.0);
	float lub = smoothstep(0.0, 0.03, p) * exp(-max(p - 0.03, 0.0) * 16.0);
	float dub = 0.7 * smoothstep(0.17, 0.2, p) * exp(-max(p - 0.2, 0.0) * 16.0);
	return clamp(lub + dub, 0.0, 1.0);
}

vec4 fetch(sampler2D tex, vec2 uv) {
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float beat = heartbeat(clip_time) * clamp(pulse, 0.0, 1.0);
	vec2 uv = 0.5 + (UV - 0.5) / (1.0 + max(thump, 0.0) * 0.01 * beat);
	vec2 q = (uv - 0.5) * 2.0;
	float e = length(q) * 0.70710678;
	float r = clamp(reach, 0.0, 1.0) * (0.85 + 0.35 * beat);
	float m = smoothstep(1.0 - r * 1.2, 1.0 - r * 1.2 + 0.45, e + 0.15);
	float br = max(blur, 0.0) * ps * m * (0.7 + 0.3 * beat);
	vec4 c = fetch(TEXTURE, uv);
	if (br > 0.3) {
		vec2 st = br / size;
		vec4 acc = c * 2.0;
		acc += fetch(TEXTURE, uv + vec2(st.x, 0.0));
		acc += fetch(TEXTURE, uv - vec2(st.x, 0.0));
		acc += fetch(TEXTURE, uv + vec2(0.0, st.y));
		acc += fetch(TEXTURE, uv - vec2(0.0, st.y));
		acc += fetch(TEXTURE, uv + st * 0.7071);
		acc += fetch(TEXTURE, uv - st * 0.7071);
		acc += fetch(TEXTURE, uv + vec2(st.x, -st.y) * 0.7071);
		acc += fetch(TEXTURE, uv + vec2(-st.x, st.y) * 0.7071);
		c = acc / 10.0;
	}
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float grey = dot(rgb, LUMA);
	rgb = mix(rgb, vec3(grey), clamp(desaturate, 0.0, 1.0) * (0.65 + 0.35 * m));
	rgb *= 1.0 - clamp(darken, 0.0, 1.0) * m * (0.75 + 0.25 * beat);
	float red_amt = clamp(m * clamp(redness, 0.0, 1.0) * (0.55 + 0.6 * beat), 0.0, 1.0) * colour.a;
	vec3 red = rgb * colour.rgb * 1.4 + colour.rgb * 0.35;
	rgb = mix(rgb, red, red_amt);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
