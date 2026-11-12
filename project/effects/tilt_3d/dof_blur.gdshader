shader_type canvas_item;
render_mode blend_disabled;

uniform float tilt = 0.0;
uniform float swivel = 0.0;
uniform float roll = 0.0;
uniform float distance = 1.3737387;
uniform float fov = 40.0;
uniform vec2 offset = vec2(0.0, 0.0);
uniform float scale = 1.0;
uniform int focus_by = 0;
uniform vec2 focus_point = vec2(0.5, 0.5);
uniform float focus_distance = 1.3737387;
uniform float aperture = 24.0;
uniform float highlight = 1.0;
uniform int quality = 1;
uniform float px_scale = 1.0;

float focal() {
	return 0.5 / tan(radians(clamp(fov, 1.0, 175.0)) * 0.5);
}

vec3 plane_depth_rotate(vec3 v, float tilt_deg, float swivel_deg, float roll_deg) {
	float t = radians(tilt_deg);
	float s = radians(swivel_deg);
	float r = radians(roll_deg);
	vec3 a = vec3(v.x, cos(t) * v.y + sin(t) * v.z, -sin(t) * v.y + cos(t) * v.z);
	vec3 b = vec3(cos(s) * a.x - sin(s) * a.z, a.y, sin(s) * a.x + cos(s) * a.z);
	return vec3(cos(r) * b.x - sin(r) * b.y, sin(r) * b.x + cos(r) * b.y, b.z);
}

mat3 plane_turn() {
	return mat3(plane_depth_rotate(vec3(1.0, 0.0, 0.0), tilt, swivel, roll), plane_depth_rotate(vec3(0.0, 1.0, 0.0), tilt, swivel, roll), plane_depth_rotate(vec3(0.0, 0.0, 1.0), tilt, swivel, roll));
}

vec4 plane_at(vec2 uv, float a, mat3 rot, float f) {
	float dist = max(distance, 0.001);
	vec3 dir = vec3(vec2((uv.x - 0.5) * a, uv.y - 0.5) / f, 1.0);
	vec3 n = rot[2];
	vec3 o = vec3(offset.x * a, offset.y, 0.0);
	vec3 cam = vec3(0.0, 0.0, -dist);
	float num = dot(o - cam, n);
	float dn = dot(dir, n);
	float lam = abs(dn) >= 0.000001 ? num / dn : -1.0;
	vec3 l = cam + dir * lam - o;
	vec2 q = vec2(dot(l, rot[0]), dot(l, rot[1])) / max(scale, 0.0001);
	return vec4(q.x / a + 0.5, q.y + 0.5, lam, dn * sign(num));
}

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float MAX_COC = 96.0;

float inv_depth(vec2 uv, float a, mat3 rot, float f) {
	vec4 c = plane_at(uv, a, rot, f);
	return (c.w > 0.0 && c.z > 0.0) ? 1.0 / c.z : 0.0;
}

float focus_inv(float a, mat3 rot, float f) {
	if (focus_by == 0) {
		return inv_depth(focus_point, a, rot, f);
	}
	return 1.0 / max(focus_distance, 0.001);
}

float coc_px(float iz, float izf, float k) {
	return min(aperture * k * abs(izf - iz), MAX_COC * k);
}

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	float a = size.x / max(size.y, 1.0);
	mat3 rot = plane_turn();
	float f = focal();
	float izf = focus_inv(a, rot, f);
	float r0 = coc_px(inv_depth(UV, a, rot, f), izf, px_scale);
	vec4 centre = texture(TEXTURE, UV);
	if (r0 < 0.9) {
		COLOR = centre;
	} else {
		int n = quality <= 0 ? 32 : (quality == 1 ? 72 : 144);
		float search = r0 * 1.15 + 1.0;
		float spin = ign(FRAGCOORD.xy) * 6.2831853;
		float l0 = dot(centre.rgb, LUMA);
		float w0 = (1.0 + pow(clamp(l0, 0.0, 1.0), 4.0) * highlight * 8.0) / max(r0 * r0, 1.0);
		vec4 sum = centre * w0;
		float wsum = w0;
		vec2 px = 1.0 / size;
		for (int i = 0; i < 144; i++) {
			if (i >= n) {
				break;
			}
			float rr = sqrt((float(i) + 0.5) / float(n)) * search;
			float th = float(i) * 2.39996323 + spin;
			vec2 at = UV + vec2(cos(th), sin(th)) * rr * px;
			float cs = coc_px(inv_depth(at, a, rot, f), izf, px_scale);
			float reach = clamp(cs - rr + 1.0, 0.0, 1.0);
			if (reach <= 0.0) {
				continue;
			}
			vec4 s = texture(TEXTURE, at);
			float l = dot(s.rgb, LUMA);
			float w = reach * (1.0 + pow(clamp(l, 0.0, 1.0), 4.0) * highlight * 8.0) / max(cs * cs, 1.0);
			sum += s * w;
			wsum += w;
		}
		COLOR = sum / max(wsum, 1e-6);
	}
}
