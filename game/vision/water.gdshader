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
// Cheap by construction: no textures, no derivatives, no loops, and one branch,
// on a uniform -- the drop's edge -- which every fragment of a draw takes the
// same way. It has to stay affordable under GL Compatibility on a low-end
// Android GPU.

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

// The drop (docs/design/ocean.md §3.3): a drop of water on a slide, and past
// its edge only the slide -- dry glass, the counting grid still etched on it.
// At the edge the meniscus gathers light into a bright line, with a lit film of
// thinning water inside it. Off (0) in today's water, which has no edge.
uniform float drop_on = 0.0;
uniform vec2 drop_center = vec2(0.0, 0.0);
uniform float drop_radius = 6000.0;
uniform float drop_band = 240.0;
// How bright the film gets at the rim, the line at its peak, and what is left
// of the grid on dry glass.
uniform float rim_level = 0.22;
uniform float line_level = 0.55;
uniform float glass_grid = 0.45;
// The line's half-width in canvas pixels, so it is a few pixels wide at any
// zoom, and its tint: a pale teal, the water's own light.
uniform float line_px = 2.2;
uniform vec3 line_tint = vec3(0.62, 0.95, 0.88);

// The light (docs/design/daylight.md §3.1), in the drop only. `day_light` is the
// light at the surface now, 0 at night and 1 by day; `light_at_middle` what of it
// reaches the drop's deepest point, its middle -- the same two numbers the
// plastid is paid by (food.gd's `light_at`). Both 1 is today's picture, which is
// what the light off and today's water send.
uniform float day_light = 1.0;
uniform float light_at_middle = 1.0;
// Where the light is low the water's own glow -- grain, cloud, grid and the rim's
// film -- falls toward `night_glow` of itself, never below. At night its tint
// moves `night_shift` of the way toward `night_tint`, by the surface light alone:
// depth only dims, night dims and cools. **Both are small on purpose** (the owner,
// 2026-10-16: "just a small change of light, nothing that can mask anything"), so
// the water at night is the water by day, a shade dimmer and cooler. The UX/UI
// designer's levers (§11).
uniform float night_glow = 0.85;
uniform vec3 night_tint = vec3(0.10, 0.40, 0.66);
uniform float night_shift = 0.3;

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
	// The water's own glow, before its tint: what the light dims in the drop.
	float glow = (
		  grid * grid_level
		+ grain * grain_level
		+ (cloud - 0.35) * cloud_level) * lit;
	vec3 col = water_tint * glow;

	// --- the drop's edge -------------------------------------------------
	if (drop_on > 0.5) {
		float px_w = max(world_per_px, 0.0001);
		float dist = length(w - drop_center);
		// 0 in the water, 1 on dry glass, across three pixels.
		float dry = smoothstep(drop_radius - 1.5 * px_w, drop_radius + 1.5 * px_w, dist);
		// The thinning film: brighter toward the rim, and only inside it.
		float film = smoothstep(drop_radius - drop_band, drop_radius, dist) * (1.0 - dry);
		// --- the light (docs/design/daylight.md §3.1) ----------------------
		// The water over this point as a share of the deepest, a shallow cap's
		// `s (2 - s)` (basin.gd's `column`), and what of the light gets through
		// it (daylight.gd's `through`): all of it on the rim, `light_at_middle`
		// at the middle. One exp2 a fragment.
		float s = clamp(1.0 - dist / max(drop_radius, 1.0), 0.0, 1.0);
		float through = exp2(s * (2.0 - s) * log2(max(light_at_middle, 0.0001)));
		float here = day_light * through;
		vec3 tint = mix(water_tint, night_tint, night_shift * (1.0 - day_light));
		// The water's own glow and the rim's film, dimmed where the light is low
		// and retinted by the hour; dry glass dims with the surface light alone.
		// The meniscus line below is neither: nothing that says where something
		// is gets dimmer.
		vec3 wet = tint * mix(night_glow, 1.0, here) * (glow + film * film * rim_level * lit);
		vec3 glass = tint * mix(night_glow, 1.0, day_light) * grid * grid_level * glass_grid * lit;
		// The meniscus line. **The square is k * k, never pow(k, 2.0)**: k is
		// negative inside the rim, and pow of a negative base is undefined in
		// GLSL ES 3.00 -- one driver draws it, another need not (§3.3).
		float k = (dist - drop_radius) / (line_px * px_w);
		float line = exp(-k * k);
		col = mix(wet, glass, dry) + line_tint * line * line_level * lit;
	}

	// 8-bit dither, for the same reason the membrane needs one: wide dim
	// gradients on a near-black field band into hard edges without it.
	col += vec3(fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
