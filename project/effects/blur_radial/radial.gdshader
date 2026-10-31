shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int mode = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float amount : hint_range(0.0, 1.0) = 0.15;
uniform bool one_sided = false;
uniform bool edge = true;
uniform float spiral_spin : hint_range(0.0, 1.0) = 0.5;

vec4 fetch(sampler2D tex, vec2 uv) {
	if (!edge && (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)) {
		return vec4(0.0);
	}
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec2 d = UV - centre;
	vec4 sum = vec4(0.0);
	float wsum = 0.0;
	if (mode == 0) {
		vec2 span = d * amount;
		float disp = length(span * tex_size);
		int n = int(clamp(ceil(disp * (one_sided ? 1.0 : 2.0)), 8.0, 96.0));
		for (int i = 0; i < 96; i++) {
			if (i >= n) {
				break;
			}
			float u = (float(i) + 0.5) / float(n);
			float s = one_sided ? -u : (u - 0.5);
			sum += fetch(TEXTURE, UV + span * s);
			wsum += 1.0;
		}
	} else if (mode == 2) {
		float aspect = tex_size.x / max(tex_size.y, 1.0);
		vec2 dd = vec2(d.x * aspect, d.y);
		float r = length(dd);
		float spin = clamp(spiral_spin, 0.0, 1.0) * 2.0;
		float zoom = (1.0 - clamp(spiral_spin, 0.0, 1.0)) * 2.0;
		float ang = amount * 0.8 * spin;
		float grow = amount * zoom;
		float reach = length(vec2(r * ang, r * grow)) * tex_size.y;
		int n = int(clamp(ceil(reach * (one_sided ? 1.0 : 2.0)), 8.0, 96.0));
		for (int i = 0; i < 96; i++) {
			if (i >= n) {
				break;
			}
			float u = (float(i) + 0.5) / float(n);
			float s = one_sided ? -u : (u - 0.5);
			float a = ang * s;
			float k = max(1.0 + grow * s, 0.0);
			vec2 q = vec2(dd.x * cos(a) - dd.y * sin(a), dd.x * sin(a) + dd.y * cos(a)) * k;
			sum += fetch(TEXTURE, vec2(q.x / aspect, q.y) + centre);
			wsum += 1.0;
		}
	} else {
		float aspect = tex_size.x / max(tex_size.y, 1.0);
		vec2 dd = vec2(d.x * aspect, d.y);
		float r = length(dd);
		float ang = amount * 0.8;
		float arc = r * ang * tex_size.y;
		int n = int(clamp(ceil(arc * 2.0), 8.0, 96.0));
		float base = atan(dd.y, dd.x);
		for (int i = 0; i < 96; i++) {
			if (i >= n) {
				break;
			}
			float u = (float(i) + 0.5) / float(n);
			float s = one_sided ? -u : (u - 0.5);
			float a = base + ang * s;
			vec2 p = vec2(cos(a) * r / aspect, sin(a) * r) + centre;
			sum += fetch(TEXTURE, p);
			wsum += 1.0;
		}
	}
	COLOR = sum / max(wsum, 0.0001);
}
