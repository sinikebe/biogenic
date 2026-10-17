shader_type canvas_item;
// Added over the membrane, as the returns' marks are (returns.tscn).
render_mode blend_add;
// **What the eyespot sees, in point of view** (docs/design/sight.md; returns.gd's
// `_draw_sight`): the water lit in the eye's field, as bright as the light lets it
// and fading with the haze, and dark wherever a body stopped the eye's rays --
// so a body is the notch it cuts, and what is behind it stays dark.
//
// **The blur is per pixel**: a point is as bright as the share of the rays within
// the eye's blur either side of it that reach past it. A level-1 eye makes a body
// a dark smudge as wide as its blur; a sharp one makes it a silhouette.
//
// Space: pixels of this rect, the cell at `centre`, its front up. A bearing is
// clockwise from up, as the membrane's and the field's are.

// How many looks across the blur a point takes, each nudged by a little noise of
// its own so the looks do not show as steps.
const int LOOKS = 12;

// food.gd's SIGHT_FAN_RAYS rays, which returns.gd checks it is.
uniform float runs[92];
uniform int count = 0;
uniform float mid = 0.0;
uniform float half_field = 1.0;
uniform float blur = 0.0;
uniform float reach = 0.0;
uniform float core = 0.0;
uniform float skin = 0.0;
// Pixels per world unit, and where the cell is in this rect.
uniform float scale = 1.7;
uniform vec2 centre = vec2(0.0);
uniform vec2 frame = vec2(1.0);
uniform vec3 tone = vec3(1.0);
uniform float lit = 0.0;
// returns.gd's edge fade, in pixels from the nearest edge.
uniform float edge_hide = 56.0;
uniform float edge_show = 132.0;


// How far the ray along `bearing` ran, interpolated between the two nearest rays,
// or -1 outside the field.
float run_at(float bearing) {
	float rel = mod(bearing - mid + PI, 2.0 * PI) - PI;
	if (abs(rel) > half_field || count < 2) {
		return -1.0;
	}
	float f = (rel + half_field) / (2.0 * half_field) * float(count - 1);
	int i = clamp(int(floor(f)), 0, count - 2);
	float t = clamp(f - float(i), 0.0, 1.0);
	return mix(runs[i], runs[i + 1], t);
}

void fragment() {
	vec2 px = UV * frame;
	vec2 d = (px - centre) / scale;
	float r = length(d);
	float bearing = atan(d.x, -d.y);
	float rel = mod(bearing - mid + PI, 2.0 * PI) - PI;
	// Nothing past the eye's reach, or outside its field and the blur round it:
	// most of the screen, left at once.
	if (r > reach || abs(rel) > half_field + 0.5 * blur) {
		COLOR = vec4(tone, 0.0);
	} else {
		// A pixel's worth of world, for a soft edge where a ray stops.
		float aa = 1.5 / scale;
		// Interleaved gradient noise: a different nudge at every pixel.
		float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy,
			vec2(0.06711056, 0.00583715))));
		float open = 0.0;
		for (int s = 0; s < LOOKS; s++) {
			float off = blur * ((float(s) + jitter) / float(LOOKS) - 0.5);
			float run = run_at(bearing + off);
			if (run >= 0.0) {
				open += 1.0 - smoothstep(run - aa, run + aa, r);
			}
		}
		float seen = open / float(LOOKS);
		float haze = reach > core ? clamp((reach - r) / (reach - core), 0.0, 1.0) : 0.0;
		float edge = min(min(px.x, frame.x - px.x), min(px.y, frame.y - px.y));
		float fade = smoothstep(edge_hide, edge_show, edge);
		float off_skin = smoothstep(skin * 0.95, skin * 1.15, r);
		COLOR = vec4(tone, lit * seen * haze * fade * off_skin);
	}
}
