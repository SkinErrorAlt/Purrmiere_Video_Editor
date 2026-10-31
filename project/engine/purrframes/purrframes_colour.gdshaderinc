vec3 purrframes_from_601(vec3 c, int colorspace) {
	if (colorspace == 0) {
		return c;
	}
	float y = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
	float cb = (c.b - y) / 1.772;
	float cr = (c.r - y) / 1.402;
	vec3 o;
	if (colorspace == 2) {
		o = vec3(y + 1.4746 * cr, y - 0.16455 * cb - 0.57135 * cr, y + 1.8814 * cb);
	} else {
		o = vec3(y + 1.5748 * cr, y - 0.187324 * cb - 0.468124 * cr, y + 1.8556 * cb);
	}
	return clamp(o, 0.0, 1.0);
}
