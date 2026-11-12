shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0,1.0);
uniform float clip_time = 0.0;
uniform int look : hint_range(0,5) = 0;
uniform float strength : hint_range(0.0,1.0) = 0.85;
uniform float contrast : hint_range(-0.5,0.5) = 0.0;
uniform float saturation : hint_range(0.0,2.0) = 1.0;
uniform float vignette : hint_range(0.0,1.0) = 0.25;
uniform float grain : hint_range(0.0,1.0) = 0.08;

const vec3 LUMA = vec3(0.2126,0.7152,0.0722);

vec3 unpm(vec4 c){ return c.a>0.0001? clamp(c.rgb/c.a,0.0,1.0) : vec3(0.0); }

float hash(vec2 p){ vec3 p3=fract(vec3(p.xyx)*0.1031); p3+=dot(p3,p3.yzx+33.33); return fract((p3.x+p3.y)*p3.z); }

void fragment(){
	vec4 src4 = texture(TEXTURE, UV);
	vec3 c = unpm(src4);
	float l = dot(c, LUMA);

	vec3 sh = vec3(0.0); vec3 hi = vec3(0.0);
	float con = 0.0; float sat = 1.0; float lift = 0.0;
	if (look == 0){ sh=vec3(-0.06,0.02,0.10); hi=vec3(0.10,0.04,-0.06); con=0.14; sat=1.12; }
	else if (look == 1){ sh=vec3(0.0); hi=vec3(0.02,0.02,0.0); con=0.26; sat=0.45; }
	else if (look == 2){ sh=vec3(0.04,0.0,-0.05); hi=vec3(0.10,0.06,-0.02); con=0.10; sat=1.08; }
	else if (look == 3){ sh=vec3(-0.08,0.0,0.06); hi=vec3(-0.04,0.02,0.08); con=0.16; sat=0.9; lift=-0.02; }
	else if (look == 4){ sh=vec3(0.06,0.03,-0.04); hi=vec3(0.08,0.05,-0.08); con=-0.06; sat=0.8; lift=0.05; }

	float sw = smoothstep(0.5,0.0,l);
	float hw = smoothstep(0.5,1.0,l);
	vec3 g = c + sh*sw + hi*hw + vec3(lift);
	float cc = con + contrast;
	g = (g - 0.5) * (1.0 + cc) + 0.5;
	g = mix(g, g*g*(3.0-2.0*g), clamp(cc,0.0,1.0)*0.5);
	float gl = dot(clamp(g,0.0,1.0), LUMA);
	g = mix(vec3(gl), g, sat * saturation);
	g = clamp(g,0.0,1.0);

	vec3 outc = mix(c, g, strength);

	vec2 d = (UV - 0.5) * vec2(tex_size.x/max(tex_size.y,1.0), 1.0);
	float vig = smoothstep(0.9, 0.35, length(d));
	outc *= mix(1.0, vig, vignette);
	float n = hash(UV*tex_size + fract(clip_time)*vec2(53.0,97.0)) - 0.5;
	outc += n * grain * 0.12;

	outc = clamp(outc, 0.0, 1.0);
	COLOR = vec4(outc * src4.a, src4.a);
}
