shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec4 source_box = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float clip_time = 0.0;

uniform int faces_show : hint_range(0, 2) = 0;
uniform sampler2D picture : filter_linear, repeat_disable, hint_default_transparent;
uniform vec4 faces_colour : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform int fit : hint_range(0, 2) = 0;
uniform vec4 fit_fill : source_color = vec4(0.0, 0.0, 0.0, 0.0);

uniform float x_rotation : hint_range(-360.0, 360.0) = 0.0;
uniform float y_rotation : hint_range(-360.0, 360.0) = 0.0;
uniform float z_rotation : hint_range(-360.0, 360.0) = 0.0;
uniform float x_speed : hint_range(-1440.0, 1440.0) = 0.0;
uniform float y_speed : hint_range(-1440.0, 1440.0) = 0.0;
uniform float z_speed : hint_range(-1440.0, 1440.0) = 0.0;

uniform float pos_x : hint_range(-20.0, 20.0) = 0.0;
uniform float pos_y : hint_range(-20.0, 20.0) = 0.0;
uniform float pos_z : hint_range(-20.0, 20.0) = 0.0;
uniform float scale : hint_range(0.01, 10.0) = 1.0;
uniform float size_x : hint_range(0.01, 10.0) = 1.0;
uniform float size_y : hint_range(0.01, 10.0) = 1.0;
uniform float size_z : hint_range(0.01, 10.0) = 1.0;

uniform bool perspective = true;
uniform float fov : hint_range(5.0, 120.0) = 40.0;
uniform float camera_distance : hint_range(0.5, 50.0) = 3.5;
uniform float camera_tilt : hint_range(-89.0, 89.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);

uniform bool shading = true;
uniform float light_angle : hint_range(-180.0, 180.0) = -30.0;
uniform float light_height : hint_range(-90.0, 90.0) = 30.0;
uniform vec4 light_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float ambient : hint_range(0.0, 2.0) = 0.4;
uniform float diffuse : hint_range(0.0, 2.0) = 0.7;
uniform float specular : hint_range(0.0, 2.0) = 0.15;
uniform float shininess : hint_range(1.0, 256.0) = 24.0;

uniform float edge_width : hint_range(0.0, 0.5) = 0.0;
uniform vec4 edge_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float roundness : hint_range(0.0, 1.0) = 0.0;
uniform bool inside = true;

uniform float shadow : hint_range(0.0, 1.0) = 0.0;
uniform float shadow_softness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 shadow_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float floor_gap : hint_range(0.0, 10.0) = 0.9;
uniform float reflection : hint_range(0.0, 1.0) = 0.0;
uniform float reflection_fade : hint_range(0.0, 10.0) = 1.0;

uniform int background : hint_range(0, 2) = 0;
uniform vec4 bg_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int smoothing : hint_range(0, 2) = 1;

uniform int front_source : hint_range(0, 4) = 0;
uniform sampler2D front_picture : filter_linear, repeat_disable, hint_default_transparent;
uniform vec4 front_colour : source_color = vec4(0.95, 0.35, 0.45, 1.0);
uniform vec4 front_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float front_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float front_angle : hint_range(-180.0, 180.0) = 0.0;
uniform int front_mirror : hint_range(0, 3) = 0;

uniform int back_source : hint_range(0, 4) = 0;
uniform sampler2D back_picture : filter_linear, repeat_disable, hint_default_transparent;
uniform vec4 back_colour : source_color = vec4(0.35, 0.6, 0.95, 1.0);
uniform vec4 back_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float back_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float back_angle : hint_range(-180.0, 180.0) = 0.0;
uniform int back_mirror : hint_range(0, 3) = 0;

uniform int left_source : hint_range(0, 4) = 0;
uniform sampler2D left_picture : filter_linear, repeat_disable, hint_default_transparent;
uniform vec4 left_colour : source_color = vec4(0.4, 0.85, 0.5, 1.0);
uniform vec4 left_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float left_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float left_angle : hint_range(-180.0, 180.0) = 0.0;
uniform int left_mirror : hint_range(0, 3) = 0;

uniform int right_source : hint_range(0, 4) = 0;
uniform sampler2D right_picture : filter_linear, repeat_disable, hint_default_transparent;
uniform vec4 right_colour : source_color = vec4(0.98, 0.8, 0.3, 1.0);
uniform vec4 right_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float right_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float right_angle : hint_range(-180.0, 180.0) = 0.0;
uniform int right_mirror : hint_range(0, 3) = 0;

uniform int top_source : hint_range(0, 4) = 0;
uniform sampler2D top_picture : filter_linear, repeat_disable, hint_default_transparent;
uniform vec4 top_colour : source_color = vec4(0.75, 0.5, 0.95, 1.0);
uniform vec4 top_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float top_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float top_angle : hint_range(-180.0, 180.0) = 0.0;
uniform int top_mirror : hint_range(0, 3) = 0;

uniform int bottom_source : hint_range(0, 4) = 0;
uniform sampler2D bottom_picture : filter_linear, repeat_disable, hint_default_transparent;
uniform vec4 bottom_colour : source_color = vec4(0.3, 0.85, 0.85, 1.0);
uniform vec4 bottom_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float bottom_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float bottom_angle : hint_range(-180.0, 180.0) = 0.0;
uniform int bottom_mirror : hint_range(0, 3) = 0;

int face_source(int f) {
	if (f == 0) {
		return front_source;
	}
	if (f == 1) {
		return back_source;
	}
	if (f == 2) {
		return left_source;
	}
	if (f == 3) {
		return right_source;
	}
	if (f == 4) {
		return top_source;
	}
	return bottom_source;
}

vec4 face_colour(int f) {
	if (f == 0) {
		return front_colour;
	}
	if (f == 1) {
		return back_colour;
	}
	if (f == 2) {
		return left_colour;
	}
	if (f == 3) {
		return right_colour;
	}
	if (f == 4) {
		return top_colour;
	}
	return bottom_colour;
}

vec4 face_tint(int f) {
	if (f == 0) {
		return front_tint;
	}
	if (f == 1) {
		return back_tint;
	}
	if (f == 2) {
		return left_tint;
	}
	if (f == 3) {
		return right_tint;
	}
	if (f == 4) {
		return top_tint;
	}
	return bottom_tint;
}

float face_opacity(int f) {
	if (f == 0) {
		return front_opacity;
	}
	if (f == 1) {
		return back_opacity;
	}
	if (f == 2) {
		return left_opacity;
	}
	if (f == 3) {
		return right_opacity;
	}
	if (f == 4) {
		return top_opacity;
	}
	return bottom_opacity;
}

float face_angle(int f) {
	if (f == 0) {
		return front_angle;
	}
	if (f == 1) {
		return back_angle;
	}
	if (f == 2) {
		return left_angle;
	}
	if (f == 3) {
		return right_angle;
	}
	if (f == 4) {
		return top_angle;
	}
	return bottom_angle;
}

int face_mirror(int f) {
	if (f == 0) {
		return front_mirror;
	}
	if (f == 1) {
		return back_mirror;
	}
	if (f == 2) {
		return left_mirror;
	}
	if (f == 3) {
		return right_mirror;
	}
	if (f == 4) {
		return top_mirror;
	}
	return bottom_mirror;
}

vec2 own_size(int f) {
	if (f == 0) {
		return vec2(textureSize(front_picture, 0));
	}
	if (f == 1) {
		return vec2(textureSize(back_picture, 0));
	}
	if (f == 2) {
		return vec2(textureSize(left_picture, 0));
	}
	if (f == 3) {
		return vec2(textureSize(right_picture, 0));
	}
	if (f == 4) {
		return vec2(textureSize(top_picture, 0));
	}
	return vec2(textureSize(bottom_picture, 0));
}

vec4 own_sample(int f, vec2 uv) {
	if (f == 0) {
		return textureLod(front_picture, uv, 0.0);
	}
	if (f == 1) {
		return textureLod(back_picture, uv, 0.0);
	}
	if (f == 2) {
		return textureLod(left_picture, uv, 0.0);
	}
	if (f == 3) {
		return textureLod(right_picture, uv, 0.0);
	}
	if (f == 4) {
		return textureLod(top_picture, uv, 0.0);
	}
	return textureLod(bottom_picture, uv, 0.0);
}

bool has_picture(vec2 sz) {
	return sz.x > 4.5 || sz.y > 4.5;
}

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

vec3 safe_dir(vec3 d) {
	vec3 s = vec3(d.x < 0.0 ? -1.0 : 1.0, d.y < 0.0 ? -1.0 : 1.0, d.z < 0.0 ? -1.0 : 1.0);
	return s * max(abs(d), vec3(0.000001));
}

bool box_hit(vec3 ro, vec3 rd, vec3 b, out float tn, out float tf) {
	vec3 inv = 1.0 / safe_dir(rd);
	vec3 t0 = (-b - ro) * inv;
	vec3 t1 = (b - ro) * inv;
	vec3 lo = min(t0, t1);
	vec3 hi = max(t0, t1);
	tn = max(max(lo.x, lo.y), lo.z);
	tf = min(min(hi.x, hi.y), hi.z);
	return tf > max(tn, 0.0);
}

float sd_box(vec3 p, vec3 b, float r) {
	vec3 q = abs(p) - (b - vec3(r));
	return length(max(q, vec3(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

vec3 sd_normal(vec3 p, vec3 b, float r) {
	float h = 0.0005 * max(b.x, max(b.y, b.z));
	vec2 k = vec2(1.0, -1.0);
	vec3 g = k.xyy * sd_box(p + k.xyy * h, b, r) + k.yyx * sd_box(p + k.yyx * h, b, r) + k.yxy * sd_box(p + k.yxy * h, b, r) + k.xxx * sd_box(p + k.xxx * h, b, r);
	float gl = length(g);
	return gl > 0.0000001 ? g / gl : vec3(0.0, 0.0, -1.0);
}

int face_of(vec3 q, vec3 b) {
	vec3 k = abs(q) / b;
	if (k.z >= k.x && k.z >= k.y) {
		return q.z < 0.0 ? 0 : 1;
	}
	if (k.x >= k.y) {
		return q.x < 0.0 ? 2 : 3;
	}
	return q.y > 0.0 ? 4 : 5;
}

vec3 face_normal(int f) {
	if (f == 0) {
		return vec3(0.0, 0.0, -1.0);
	}
	if (f == 1) {
		return vec3(0.0, 0.0, 1.0);
	}
	if (f == 2) {
		return vec3(-1.0, 0.0, 0.0);
	}
	if (f == 3) {
		return vec3(1.0, 0.0, 0.0);
	}
	if (f == 4) {
		return vec3(0.0, 1.0, 0.0);
	}
	return vec3(0.0, -1.0, 0.0);
}

vec2 face_uv(int f, vec3 q, vec3 b, out vec2 dims, out float edge) {
	vec3 n = q / b;
	vec3 a = b - abs(q);
	vec2 uv;
	if (f == 0) {
		uv = vec2(n.x, -n.y);
		dims = b.xy;
		edge = min(a.x, a.y);
	} else if (f == 1) {
		uv = vec2(-n.x, -n.y);
		dims = b.xy;
		edge = min(a.x, a.y);
	} else if (f == 2) {
		uv = vec2(-n.z, -n.y);
		dims = b.zy;
		edge = min(a.z, a.y);
	} else if (f == 3) {
		uv = vec2(n.z, -n.y);
		dims = b.zy;
		edge = min(a.z, a.y);
	} else if (f == 4) {
		uv = vec2(n.x, -n.z);
		dims = b.xz;
		edge = min(a.x, a.z);
	} else {
		uv = vec2(n.x, n.z);
		dims = b.xz;
		edge = min(a.x, a.z);
	}
	dims *= 2.0;
	return uv * 0.5 + 0.5;
}

vec2 fit_uv(vec2 s, vec2 dims, float pa) {
	vec2 rect = dims;
	if (fit != 2) {
		float fa = dims.x / max(dims.y, 0.00001);
		if ((fit == 0) == (pa > fa)) {
			rect = vec2(dims.y * pa, dims.y);
		} else {
			rect = vec2(dims.x, dims.x / max(pa, 0.00001));
		}
	}
	return s / rect + 0.5;
}

vec4 clip_sample(vec2 puv) {
	vec2 px = max(source_box.zw * tex_size, vec2(1.0));
	vec2 h = 0.5 / px;
	return textureLod(effect_tex, source_box.xy + clamp(puv, h, vec2(1.0) - h) * source_box.zw, 0.0);
}

vec4 face_paint(int f, vec2 uv, vec2 dims) {
	int src = face_source(f);
	int master = faces_show == 0 ? 0 : (faces_show == 1 ? 1 : 3);
	if (master == 1 && !has_picture(vec2(textureSize(picture, 0)))) {
		master = 0;
	}
	int kind = master;
	if (src == 1) {
		kind = 0;
	} else if (src == 2) {
		kind = has_picture(own_size(f)) ? 2 : master;
	} else if (src == 3) {
		kind = 5;
	} else if (src == 4) {
		kind = 4;
	}
	if (kind == 5) {
		return vec4(0.0);
	}
	vec4 straight = vec4(0.0);
	if (kind == 3) {
		straight = faces_colour;
	} else if (kind == 4) {
		straight = face_colour(f);
	} else {
		vec2 m = uv;
		int mir = face_mirror(f);
		if (mir == 1 || mir == 3) {
			m.x = 1.0 - m.x;
		}
		if (mir == 2 || mir == 3) {
			m.y = 1.0 - m.y;
		}
		vec2 s = (m - 0.5) * dims;
		float ang = radians(face_angle(f));
		float ca = cos(ang);
		float sa = sin(ang);
		s = vec2(ca * s.x + sa * s.y, -sa * s.x + ca * s.y);
		vec2 psz = kind == 0 ? source_box.zw * tex_size : (kind == 1 ? vec2(textureSize(picture, 0)) : own_size(f));
		float pa = psz.x / max(psz.y, 1.0);
		vec2 puv = fit_uv(s, dims, pa);
		vec4 fill = vec4(fit_fill.rgb * fit_fill.a, fit_fill.a);
		vec4 pm = fill;
		if (puv.x >= -0.001 && puv.y >= -0.001 && puv.x <= 1.001 && puv.y <= 1.001) {
			vec2 cu = clamp(puv, vec2(0.0), vec2(1.0));
			if (kind == 0) {
				pm = clip_sample(cu);
			} else {
				vec4 p = kind == 1 ? textureLod(picture, cu, 0.0) : own_sample(f, cu);
				pm = vec4(p.rgb * p.a, p.a);
			}
			pm = pm + fill * (1.0 - pm.a);
		}
		straight = pm.a > 0.0001 ? vec4(pm.rgb / pm.a, pm.a) : vec4(0.0);
	}
	vec4 tint = face_tint(f);
	straight.rgb *= tint.rgb;
	straight.a *= tint.a * clamp(face_opacity(f), 0.0, 1.0);
	return straight;
}

vec3 light_dir() {
	float a = radians(light_angle);
	float h = radians(light_height);
	return normalize(vec3(cos(h) * sin(a), sin(h), -cos(h) * cos(a)));
}

vec3 lit(vec3 s, vec3 n, vec3 rd, vec3 l) {
	if (!shading) {
		return s;
	}
	float d = max(dot(n, l), 0.0);
	vec3 hh = l - rd;
	vec3 hv = dot(hh, hh) > 0.0000001 ? normalize(hh) : n;
	float sp = d > 0.0 ? pow(max(dot(n, hv), 0.0), max(shininess, 1.0)) * specular : 0.0;
	return s * (vec3(ambient) + light_colour.rgb * diffuse * d) + light_colour.rgb * sp;
}

vec4 surface(vec3 q, vec3 nrm, vec3 b, mat3 rot, vec3 rdw, vec3 l, bool back, float aaw) {
	int f = face_of(q, b);
	vec2 dims;
	float edge;
	vec2 uv = face_uv(f, q, b, dims, edge);
	vec4 paint = face_paint(f, uv, dims);
	vec4 pm = vec4(paint.rgb * paint.a, paint.a);
	if (edge_width > 0.0) {
		float w = edge_width * scale;
		float e = (1.0 - smoothstep(w - aaw, w + aaw, edge)) * edge_colour.a;
		pm = vec4(edge_colour.rgb, 1.0) * e + pm * (1.0 - e);
	}
	if (pm.a <= 0.0001) {
		return vec4(0.0);
	}
	vec3 nw = rot * nrm;
	if (back) {
		nw = -nw;
	}
	vec3 col = lit(pm.rgb / pm.a, nw, rdw, l);
	return vec4(clamp(col, vec3(0.0), vec3(1.0)) * pm.a, pm.a);
}

vec4 cube_at(vec3 row, vec3 rdw, mat3 rot, vec3 c, vec3 b, float r, vec3 l, float aaw, bool want_back, out float t_hit) {
	t_hit = -1.0;
	mat3 rt = transpose(rot);
	vec3 ro = rt * (row - c);
	vec3 rd = rt * rdw;
	float tn;
	float tf;
	if (!box_hit(ro, rd, b, tn, tf)) {
		return vec4(0.0);
	}
	float eps = 0.0002 * max(b.x, max(b.y, b.z));
	vec4 front = vec4(0.0);
	if (tn > 0.0) {
		if (r <= 0.0) {
			vec3 q = ro + rd * tn;
			front = surface(q, face_normal(face_of(q, b)), b, rot, rdw, l, false, aaw);
			t_hit = tn;
		} else {
			float t = tn;
			bool hit = false;
			for (int i = 0; i < 64; i++) {
				float d = sd_box(ro + rd * t, b, r);
				if (d < eps) {
					hit = true;
					break;
				}
				t += d;
				if (t > tf) {
					break;
				}
			}
			if (!hit) {
				return vec4(0.0);
			}
			vec3 q = ro + rd * t;
			front = surface(q, sd_normal(q, b, r), b, rot, rdw, l, false, aaw);
			t_hit = t;
		}
	}
	if (!want_back || !inside || front.a >= 0.999) {
		return front;
	}
	vec4 behind = vec4(0.0);
	if (r <= 0.0) {
		vec3 q = ro + rd * tf;
		behind = surface(q, face_normal(face_of(q, b)), b, rot, rdw, l, true, aaw);
	} else {
		float t = tf;
		bool hit = false;
		for (int i = 0; i < 64; i++) {
			float d = sd_box(ro + rd * t, b, r);
			if (d < eps) {
				hit = true;
				break;
			}
			t -= d;
			if (t < max(tn, 0.0)) {
				break;
			}
		}
		if (hit) {
			vec3 q = ro + rd * t;
			behind = surface(q, sd_normal(q, b, r), b, rot, rdw, l, true, aaw);
		}
	}
	if (t_hit < 0.0) {
		t_hit = tf;
	}
	return front + behind * (1.0 - front.a);
}

float shadow_at(vec3 g, vec3 l, mat3 rot, vec3 c, vec3 b, float r) {
	mat3 rt = transpose(rot);
	vec3 ro = rt * (g - c);
	vec3 rd = rt * l;
	float sz = max(b.x, max(b.y, b.z));
	float k = mix(48.0, 3.0, clamp(shadow_softness, 0.0, 1.0));
	float res = 1.0;
	float t = 0.01 * sz;
	for (int i = 0; i < 48; i++) {
		float d = sd_box(ro + rd * t, b, r);
		res = min(res, k * d / t);
		if (res < 0.001) {
			break;
		}
		t += clamp(d, 0.01 * sz, 0.5 * sz);
		if (t > 40.0 * sz) {
			break;
		}
	}
	res = clamp(res, 0.0, 1.0);
	return 1.0 - res * res * (3.0 - 2.0 * res);
}

vec4 scene(vec2 uvs, float aspect, float fl, float aaw, mat3 rot, vec3 c, vec3 b, float r, vec3 l, mat3 cam) {
	vec2 p = vec2((uvs.x - centre.x) * 2.0 * aspect, (centre.y - uvs.y) * 2.0);
	float dist = max(camera_distance, 0.01);
	vec3 ro;
	vec3 rd;
	if (perspective) {
		ro = vec3(0.0, 0.0, -dist);
		rd = normalize(vec3(p, fl));
	} else {
		ro = vec3(p * dist / fl, -dist);
		rd = vec3(0.0, 0.0, 1.0);
	}
	ro = cam * ro;
	rd = cam * rd;
	float th;
	vec4 cube = cube_at(ro, rd, rot, c, b, r, l, aaw, true, th);
	if (cube.a >= 0.999 || (shadow <= 0.0 && reflection <= 0.0) || rd.y > -0.00001) {
		return cube;
	}
	float fy = c.y - floor_gap * scale;
	float tg = (fy - ro.y) / rd.y;
	if (tg <= 0.0) {
		return cube;
	}
	vec3 g = ro + rd * tg;
	vec4 under = vec4(0.0);
	if (shadow > 0.0 && l.y > 0.0) {
		float s = clamp(shadow, 0.0, 1.0) * shadow_colour.a * shadow_at(g, l, rot, c, b, r);
		under = vec4(shadow_colour.rgb * s, s);
	}
	if (reflection > 0.0) {
		vec3 rr = vec3(rd.x, -rd.y, rd.z);
		float tr;
		vec4 m = cube_at(g + rr * 0.0001, rr, rot, c, b, r, l, aaw, false, tr);
		float sz = max(b.x, max(b.y, b.z));
		float w = clamp(reflection, 0.0, 1.0) * exp(-reflection_fade * max(tr, 0.0) / (2.0 * sz));
		under = m * w + under * (1.0 - m.a * w);
	}
	if (th > tg) {
		return under + cube * (1.0 - under.a);
	}
	return cube + under * (1.0 - cube.a);
}

void fragment() {
	float aspect = tex_size.x / max(tex_size.y, 1.0);
	vec2 fw = fwidth(UV);
	float fl = 1.0 / tan(radians(clamp(fov, 1.0, 170.0)) * 0.5);
	float aaw = 2.0 * fw.y * max(camera_distance, 0.01) / fl;
	float t = clip_time;
	mat3 rot = rot_z(radians(-(z_rotation + z_speed * t))) * rot_y(radians(y_rotation + y_speed * t)) * rot_x(radians(x_rotation + x_speed * t));
	vec3 c = vec3(pos_x, -pos_y, pos_z);
	vec3 b = max(0.5 * scale * vec3(size_x, size_y, size_z), vec3(0.0001));
	float r = clamp(roundness, 0.0, 1.0) * min(b.x, min(b.y, b.z)) * 0.999;
	vec3 l = light_dir();
	mat3 cam = rot_x(radians(camera_tilt));
	int n = smoothing == 0 ? 1 : (smoothing == 1 ? 2 : 4);
	vec4 acc = vec4(0.0);
	for (int j = 0; j < n; j++) {
		for (int i = 0; i < n; i++) {
			vec2 o = (vec2(float(i), float(j)) + 0.5) / float(n) - 0.5;
			acc += scene(UV + o * fw, aspect, fl, aaw, rot, c, b, r, l, cam);
		}
	}
	acc /= float(n * n);
	vec4 bg = vec4(0.0);
	if (background == 1) {
		bg = textureLod(effect_tex, UV, 0.0);
	} else if (background == 2) {
		bg = vec4(bg_colour.rgb * bg_colour.a, bg_colour.a);
	}
	vec4 o = acc + bg * (1.0 - acc.a);
	float a = clamp(o.a, 0.0, 1.0);
	COLOR = vec4(min(max(o.rgb, vec3(0.0)), vec3(a)), a);
}
