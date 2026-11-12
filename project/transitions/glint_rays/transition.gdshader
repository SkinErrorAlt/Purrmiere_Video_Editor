shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int rays = 4;
uniform float reach : hint_range(0.02,0.3) = 0.13;
uniform vec4 glint_color : source_color = vec4(1.0,0.95,0.85,1.0);
vec4 transition(vec2 uv){
	float e = clamp(progress,0.0,1.0);
	float peak = sin(e*TR_PI);
	float m = smoothstep(0.35,0.65,e);
	vec4 base = mix(from_at(uv), to_at(uv), m);
	vec3 glint = vec3(0.0);
	for(int r=0;r<8;r++){
		if(r>=rays){ break; }
		float ang = radians(float(r)/float(rays)*180.0 + e*25.0);
		vec2 d = vec2(cos(ang), sin(ang));
		for(int k=1;k<=6;k++){
			float t = float(k)/6.0;
			vec4 s = mix(from_clamped(uv + d*t*reach*peak), to_clamped(uv + d*t*reach*peak), m);
			float lu = dot(s.rgb, vec3(0.299,0.587,0.114));
			glint += smoothstep(0.78,1.0,lu) * (1.0 - t);
		}
	}
	glint *= peak / float(max(rays,1)) * 0.55;
	base.rgb += glint_color.rgb * glint_color.a * glint;
	return vec4(clamp(base.rgb,0.0,1.0), base.a);
}
void fragment(){ COLOR = transition(UV); }
