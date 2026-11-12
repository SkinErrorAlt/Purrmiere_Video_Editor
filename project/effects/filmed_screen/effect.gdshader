shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;
uniform float pixel_size : hint_range(0.5, 12.0) = 1.93;
uniform float angle : hint_range(-45.0, 45.0) = 1.5;
uniform float tilt : hint_range(-35.0, 35.0) = 7.0;
uniform float bend : hint_range(0.0, 1.0) = 0.25;
uniform float focus : hint_range(0.0, 1.0) = 0.85;
uniform float glow : hint_range(0.0, 0.3) = 0.05;
uniform float cast : hint_range(0.0, 1.0) = 0.4;
uniform float falloff : hint_range(0.0, 1.0) = 0.25;
uniform float band : hint_range(0.0, 1.0) = 0.3;
uniform float band_speed : hint_range(-3.0, 3.0) = 0.4;
uniform int seed = 0;

vec3 to_lin(vec3 v) {
	vec3 lo = v / 12.92;
	vec3 hi = pow((v + 0.055) / 1.055, vec3(2.4));
	return mix(hi, lo, step(v, vec3(0.04045)));
}

vec3 to_srgb(vec3 v) {
	vec3 lo = v * 12.92;
	vec3 hi = 1.055 * pow(max(v, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(hi, lo, step(v, vec3(0.0031308)));
}

float sinc(float x) {
	return abs(x) < 0.0001 ? 1.0 : sin(x) / x;
}

vec2 to_screen(vec2 uv, float aspect, float fill) {
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
	float r2 = dot(p, p);
	p *= 1.0 + bend * 0.12 * r2;
	float tt = tan(radians(tilt)) * 0.55;
	float wdiv = 1.0 + tt * p.y;
	p /= max(wdiv, 0.2);
	float ca = cos(radians(angle));
	float sa = sin(radians(angle));
	p = vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);
	return p * fill;
}

float stripe(float x, float att1, float att2) {
	return 1.0 + 1.654 * att1 * cos(TAU * x) + 0.827 * att2 * cos(2.0 * TAU * x);
}

float mask_at(vec2 s, float phase, vec2 wx, vec2 wy, float blur_s) {
	float a1 = sinc(PI * wx.x) * exp(-2.0 * pow(PI * blur_s, 2.0));
	float a2 = sinc(2.0 * PI * wx.x) * exp(-2.0 * pow(2.0 * PI * blur_s, 2.0));
	float r1 = sinc(PI * wy.y) * exp(-2.0 * pow(PI * blur_s, 2.0));
	float col = max(stripe(s.x - phase, a1, a2), 0.0);
	float row = max(1.0 + 0.34 * r1 * cos(TAU * s.y), 0.0);
	return col * row;
}

void fragment() {
	float aspect = tex_size.x / max(tex_size.y, 1.0);
	float tt = abs(tan(radians(tilt))) * 0.55;
	float fill = 1.0 / (1.0 + bend * 0.12 * 0.25 * (aspect * aspect + 1.0)) / (1.0 + tt * 0.5) / (abs(cos(radians(angle))) + abs(sin(radians(angle))) * max(aspect, 1.0 / aspect));
	fill = min(fill, 1.0);
	vec2 p = to_screen(UV, aspect, fill);
	vec2 suv = p / vec2(aspect, 1.0) + 0.5;
	vec4 src = texture(TEXTURE, clamp(suv, vec2(0.0), vec2(1.0)));
	float a = src.a;
	vec3 rgb = a > 0.0001 ? src.rgb / a : vec3(0.0);
	vec3 lin = to_lin(clamp(rgb, 0.0, 1.0));
	float pitch = max(pixel_size * px_scale, 0.05) / max(tex_size.y, 1.0);
	vec2 s = p / pitch;
	vec2 dsx = vec2(dFdx(s.x), dFdy(s.x));
	vec2 dsy = vec2(dFdx(s.y), dFdy(s.y));
	float wxx = length(dsx);
	float wyy = length(dsy);
	vec2 wx = vec2(wxx, 0.0);
	vec2 wy = vec2(0.0, wyy);
	float blur_s = ((1.0 - clamp(focus, 0.0, 1.0)) * 1.4 + 0.4) * wxx;
	vec2 q = UV * tex_size - 0.5;
	vec2 rb = floor(q * 0.5) * 2.0;
	vec2 rf = (q - rb) * 0.5;
	vec2 bb = floor((q - 1.0) * 0.5) * 2.0 + 1.0;
	vec2 bf = (q - bb) * 0.5;
	float mr = 0.0;
	float mb = 0.0;
	for (int j = 0; j <= 1; j++) {
		for (int i = 0; i <= 1; i++) {
			vec2 cr = rb + vec2(float(i), float(j)) * 2.0 - q;
			vec2 cb = bb + vec2(float(i), float(j)) * 2.0 - q;
			float wr = (i == 0 ? 1.0 - rf.x : rf.x) * (j == 0 ? 1.0 - rf.y : rf.y);
			float wb = (i == 0 ? 1.0 - bf.x : bf.x) * (j == 0 ? 1.0 - bf.y : bf.y);
			mr += wr * mask_at(s + vec2(dot(dsx, cr), dot(dsy, cr)), 1.0 / 6.0, wx, wy, blur_s);
			mb += wb * mask_at(s + vec2(dot(dsx, cb), dot(dsy, cb)), 5.0 / 6.0, wx, wy, blur_s);
		}
	}
	ivec2 iq = ivec2(floor(q + 0.5));
	float mg = 0.0;
	if (((iq.x + iq.y) & 1) == 0) {
		mg = mask_at(s, 0.5, wx, wy, blur_s);
	} else {
		mg = 0.25 * (mask_at(s + vec2(dsx.x, dsy.x), 0.5, wx, wy, blur_s) + mask_at(s - vec2(dsx.x, dsy.x), 0.5, wx, wy, blur_s) + mask_at(s + vec2(dsx.y, dsy.y), 0.5, wx, wy, blur_s) + mask_at(s - vec2(dsx.y, dsy.y), 0.5, wx, wy, blur_s));
	}
	vec3 m = vec3(mr, mg, mb);
	lin = lin * (1.0 - glow) + glow * vec3(0.7, 0.82, 1.0);
	lin *= mix(vec3(1.0), vec3(0.86, 0.98, 1.16), cast);
	float side = clamp(UV.y + (UV.x - 0.5) * 0.3, 0.0, 1.0);
	float fade = falloff * smoothstep(0.1, 1.0, tilt >= 0.0 ? side : 1.0 - side);
	lin = mix(lin, pow(lin, vec3(0.8)) * 0.6 + vec3(0.02, 0.025, 0.035), fade * 0.6);
	lin *= m;
	if (band > 0.0) {
		float ph = fract(time * band_speed + fract(float(seed) * 0.6180339));
		float d = UV.y - ph;
		d -= floor(d + 0.5);
		float dip = exp(-d * d / 0.012);
		float lead = exp(-pow(d + 0.11, 2.0) / 0.002);
		lin *= 1.0 - band * 0.4 * dip + band * 0.12 * lead;
	}
	lin *= 1.06;
	vec3 outc = clamp(to_srgb(lin), 0.0, 1.0);
	COLOR = vec4(outc * a, a);
}
