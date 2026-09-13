shader_type canvas_item;
render_mode blend_add;

// The water itself: a world-anchored field so that the camera moving over it is
// the thing that reads as motion. Nothing here is anchored to the screen, which
// is the whole point -- a camera locked to the cell makes the cell look
// stationary unless the water behind it is nailed to world coordinates.
//
// Additive on purpose. This draws over the membrane, whose ColorRect is opaque
// and is not ours to modify; the membrane's base is a near-black (5,13,12) and
// every signal it draws is already additive over that base, so adding the water
// on top composes to the same picture as sliding it underneath would.
//
// Cheap by construction: no textures, no derivatives, no branches, no loops.
// It has to stay affordable under GL Compatibility on a low-end Android GPU.

uniform vec2 rect_px = vec2(1280.0, 720.0);
// World coordinate under the top-left pixel, and world units per canvas pixel.
uniform vec2 world_origin = vec2(0.0, 0.0);
uniform float world_per_px = 1.0;
// Master fade, so switching views is a dissolve rather than a cut.
uniform float amount = 1.0;

// The aperture: vision owns the interior, the membrane owns the rim. The water
// fades out before it reaches the band where chemistry is allowed to glow.
uniform float aperture_inset_px = 16.0;
uniform float aperture_fade_px = 170.0;
uniform float aperture_corner_px = 190.0;

uniform vec3 water_tint = vec3(0.10, 0.62, 0.52);
// World units between graticule lines. Every fourth one is brighter.
uniform float grid_world = 240.0;
uniform float grid_level = 0.085;
uniform float grain_level = 1.0;
uniform float cloud_level = 0.115;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// One scale of suspended matter: a speck somewhere inside every cell of a
// world-space lattice, sized and dimmed by its own hash so the field never
// reads as a grid of dots.
float speck(vec2 w, float scale, float weight) {
	vec2 cell = floor(w / scale);
	vec2 f = fract(w / scale);
	vec2 at = vec2(hash21(cell), hash21(cell + vec2(17.3, 5.1)));
	float d = length((f - at) * scale);
	float size = mix(1.1, 3.2, hash21(cell + vec2(4.1, 9.7)));
	// Never let a speck fall under a pixel: it would shimmer instead of drift.
	size = max(size, 1.15 * world_per_px);
	return smoothstep(size, 0.0, d) * weight * (0.35 + 0.65 * hash21(cell + vec2(2.7, 31.3)));
}

void fragment() {
	vec2 px = UV * rect_px;
	vec2 w = world_origin + px * world_per_px;

	// --- graticule -------------------------------------------------------
	// A counting-chamber reticule, not a debug grid: faint, and anchored to the
	// water rather than to the eye, so it slides when the cell travels.
	vec2 g = abs(fract(w / grid_world + 0.5) - 0.5) * grid_world / max(world_per_px, 0.0001);
	vec2 line_id = floor(w / grid_world + 0.5);
	vec2 major = vec2(
		1.0 - min(abs(mod(line_id.x, 4.0)), 1.0),
		1.0 - min(abs(mod(line_id.y, 4.0)), 1.0));
	float grid = max(
		smoothstep(1.9, 0.0, g.x) * (0.55 + 0.45 * major.x),
		smoothstep(1.9, 0.0, g.y) * (0.55 + 0.45 * major.y));

	// --- suspended matter ------------------------------------------------
	float grain = speck(w, 29.0, 0.15) + speck(w, 67.0, 0.22)
		+ speck(w, 143.0, 0.31) + speck(w, 337.0, 0.42);
	grain = min(grain, 0.54);

	// --- illumination ----------------------------------------------------
	// The only thing in here that moves on its own, and it moves far too slowly
	// to be mistaken for the cell's own travel.
	float cloud = 0.5 + 0.18 * (
		  sin(w.x * 0.0041 + TIME * 0.06)
		+ sin(w.y * 0.0037 - TIME * 0.045)
		+ 0.8 * sin((w.x + w.y) * 0.0023 + TIME * 0.031));

	// --- aperture --------------------------------------------------------
	vec2 c = rect_px * 0.5;
	vec2 half_ext = c - vec2(aperture_inset_px);
	float r = min(aperture_corner_px, min(half_ext.x, half_ext.y));
	vec2 q = abs(px - c) - (half_ext - vec2(r));
	float sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	float aperture = 1.0 - smoothstep(-aperture_fade_px, 0.0, sdf);

	float lit = aperture * amount;
	vec3 col = water_tint * (
		  grid * grid_level
		+ grain * grain_level
		+ (cloud - 0.35) * cloud_level) * lit;

	// 8-bit dither, for the same reason the membrane needs one: wide dim
	// gradients on a near-black field band into hard edges without it.
	col += vec3(fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
