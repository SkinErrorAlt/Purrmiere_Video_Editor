uniform vec2 outline_corners[4];
uniform float outline_perimeter = 1.0;

float outline_distance(vec2 p) {
	float d = 100000.0;
	bool all_left = true;
	bool all_right = true;
	for (int i = 0; i < 4; i++) {
		vec2 a = outline_corners[i];
		vec2 b = outline_corners[(i + 1) % 4];
		vec2 ab = b - a;
		float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.000001), 0.0, 1.0);
		d = min(d, length(p - (a + ab * t)));
		float side = ab.x * (p.y - a.y) - ab.y * (p.x - a.x);
		all_left = all_left && side <= 0.0;
		all_right = all_right && side >= 0.0;
	}
	return (all_left || all_right) ? -d : d;
}

float outline_along(vec2 p) {
	float best = 100000.0;
	float along = 0.0;
	float run = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 a = outline_corners[i];
		vec2 b = outline_corners[(i + 1) % 4];
		vec2 ab = b - a;
		float len = length(ab);
		float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.000001), 0.0, 1.0);
		float d = length(p - (a + ab * t));
		if (d < best) {
			best = d;
			along = run + t * len;
		}
		run += len;
	}
	return along;
}

float outline_corner(vec2 p) {
	float best = 100000.0;
	float reach = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 a = outline_corners[i];
		vec2 b = outline_corners[(i + 1) % 4];
		vec2 ab = b - a;
		float len = length(ab);
		float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.000001), 0.0, 1.0);
		float d = length(p - (a + ab * t));
		if (d < best) {
			best = d;
			reach = min(t, 1.0 - t) * len;
		}
	}
	return reach;
}
