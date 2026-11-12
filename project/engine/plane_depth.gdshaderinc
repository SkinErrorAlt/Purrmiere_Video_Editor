vec3 plane_depth_rotate(vec3 v, float tilt_deg, float swivel_deg, float roll_deg) {
	float t = radians(tilt_deg);
	float s = radians(swivel_deg);
	float r = radians(roll_deg);
	vec3 a = vec3(v.x, cos(t) * v.y + sin(t) * v.z, -sin(t) * v.y + cos(t) * v.z);
	vec3 b = vec3(cos(s) * a.x - sin(s) * a.z, a.y, sin(s) * a.x + cos(s) * a.z);
	return vec3(cos(r) * b.x - sin(r) * b.y, sin(r) * b.x + cos(r) * b.y, b.z);
}

float plane_depth_at(vec2 uv, float aspect, float tilt_deg, float swivel_deg, float roll_deg, float dist, float focal, vec2 offset) {
	vec2 s = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
	vec3 dir = vec3(s / focal, 1.0);
	vec3 n = plane_depth_rotate(vec3(0.0, 0.0, 1.0), tilt_deg, swivel_deg, roll_deg);
	vec3 o = vec3(offset.x * aspect, offset.y, 0.0);
	vec3 cam = vec3(0.0, 0.0, -dist);
	float denom = dot(dir, n);
	if (abs(denom) < 0.000001) {
		return -1.0;
	}
	float lam = dot(o - cam, n) / denom;
	return lam > 0.0 ? lam : -1.0;
}

float plane_depth_weight(float depth, float near, float far, float softness, bool reverse) {
	float w = 0.0;
	if (depth >= 0.0) {
		float soft = max(softness, 0.0);
		float lo = near - soft;
		float hi = far + soft;
		float t = clamp((depth - lo) / max(hi - lo, 0.00001), 0.0, 1.0);
		w = 1.0 - t * t * (3.0 - 2.0 * t);
	}
	return reverse ? 1.0 - w : w;
}
