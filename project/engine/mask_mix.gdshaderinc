uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;
uniform bool use_mask = true;
uniform bool have_effect_tex = true;
uniform int mode = 0;
uniform bool mask_invert = false;
uniform float mask_opacity = 1.0;
uniform vec4 mask_box = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 before_box = vec4(0.0, 0.0, 1.0, 1.0);

#ifdef DEPTH_FADE
#include "res://engine/plane_depth.gdshaderinc"
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float plane_tilt = 0.0;
uniform float plane_swivel = 0.0;
uniform float plane_roll = 0.0;
uniform float plane_distance = 2.0;
uniform float plane_focal = 1.0;
uniform vec2 plane_offset = vec2(0.0, 0.0);
uniform float fade_near = 1.0;
uniform float fade_far = 3.0;
uniform float fade_softness = 0.0;
uniform bool fade_reverse = false;
uniform vec4 depth_room = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool depth_room_outer = true;
uniform int depth_regions = 0;
uniform vec4 depth_box[8];
uniform vec4 depth_src[8];
uniform vec4 depth_ta[8];
uniform vec4 depth_tb[8];
uniform vec2 depth_size = vec2(0.0, 0.0);

vec2 depth_from_room(vec2 uv) {
	return (uv - depth_room.xy) / max(depth_room.zw, vec2(0.000001));
}

vec2 depth_from_regions(vec2 uv) {
	if (depth_regions <= 0) {
		return uv;
	}
	for (int i = 0; i < 8; i++) {
		if (i >= depth_regions) {
			break;
		}
		vec3 h = vec3(uv, 1.0);
		vec2 at = vec2(dot(depth_ta[i].xyz, h), dot(depth_tb[i].xyz, h));
		vec2 l = (at - depth_box[i].xy) / max(depth_box[i].zw, vec2(0.000001));
		if (l.x >= 0.0 && l.y >= 0.0 && l.x <= 1.0 && l.y <= 1.0) {
			return depth_src[i].xy + l * depth_src[i].zw;
		}
	}
	return vec2(-1000.0);
}

vec2 depth_uv(vec2 uv) {
	if (depth_room_outer) {
		return depth_from_regions(depth_from_room(uv));
	}
	vec2 q = depth_from_regions(uv);
	return q.x < -999.0 ? q : depth_from_room(q);
}
#endif

vec2 in_box(vec2 uv, vec4 box) {
	return (uv - box.xy) / max(box.zw, vec2(0.000001));
}

bool inside(vec2 uv) {
	return uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
}

void fragment() {
	vec4 after = texture(TEXTURE, UV);
	vec2 buv = in_box(UV, before_box);
	vec4 before = have_effect_tex ? (inside(buv) ? texture(effect_tex, buv) : vec4(0.0)) : after;
	vec2 muv = in_box(UV, mask_box);
	float m = 1.0;
	if (use_mask) {
		float raw = inside(muv) ? texture(mask_tex, muv).a : 0.0;
		m = (mask_invert && inside(muv) ? 1.0 - raw : raw) * clamp(mask_opacity, 0.0, 1.0);
	}
	float amount = clamp(mix_amount, 0.0, 1.0);
#ifdef DEPTH_FADE
	vec2 dsize = depth_size.x > 0.5 ? depth_size : tex_size;
	float aspect = dsize.x / max(dsize.y, 1.0);
	vec2 duv = depth_uv(UV);
	float depth = duv.x < -999.0 ? -1.0 : plane_depth_at(duv, aspect, plane_tilt, plane_swivel, plane_roll, plane_distance, plane_focal, plane_offset);
	amount *= plane_depth_weight(depth, fade_near, fade_far, fade_softness, fade_reverse);
#endif
	if (mode == 1) {
		COLOR = after * m;
	} else if (mode == 2) {
		vec4 over = after + before * (1.0 - clamp(after.a, 0.0, 1.0));
		COLOR = mix(before, over, amount);
	} else {
		m *= amount;
		COLOR = mix(before, after, m);
	}
}
