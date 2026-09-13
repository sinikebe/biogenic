shader_type canvas_item;

uniform vec2  rect_px = vec2(1280.0, 720.0);
uniform float inset_px = 28.0;      // keep the contour off notches/rounded corners
uniform float corner_px = 150.0;
uniform float band_px = 104.0;
uniform float line_px = 9.0;
uniform float wobble_px = 22.0;

uniform vec3  base_color  = vec3(0.023, 0.055, 0.05);
uniform vec3  dread_color = vec3(0.013, 0.030, 0.043);
uniform float dread = 0.0;

uniform float pulse = 0.0;
uniform vec3  pulse_color = vec3(0.12, 0.70, 0.58);

uniform vec4 glow_lobes[4];         // xy = bearing, z = cos(halfwidth), w = intensity
uniform vec3 glow_colors[4];
uniform vec4 press_lobes[2];        // xy = bearing, z = cos(halfwidth), w = push
uniform vec3 press_color = vec3(0.78, 0.94, 0.90);
uniform float push_px = 86.0;

uniform float flash = 0.0;
uniform vec3  flash_color = vec3(0.90, 1.0, 0.97);
uniform float ingest = 0.0;
uniform vec3  ingest_color = vec3(0.35, 0.88, 0.42);
uniform float gain = 1.0;

void fragment() {
	vec2 px = UV * rect_px;
	vec2 c  = rect_px * 0.5;
	vec2 d  = px - c;

	// Aspect-corrected bearing: a signal at 45 degrees lands at the same
	// relative screen spot on 16:9 and on 20:9. Screen y is down; front is (0,-1).
	vec2 bd = normalize(vec2(d.x / max(c.x, 1.0), d.y / max(c.y, 1.0)) + vec2(1e-5, 1e-5));

	float pushv = 0.0;
	for (int i = 0; i < 2; i++) {
		float w = smoothstep(press_lobes[i].z, 1.0, dot(bd, press_lobes[i].xy));
		pushv = max(pushv, w * press_lobes[i].w);
	}

	vec2 half_ext = c - vec2(inset_px);
	float r = min(corner_px, min(half_ext.x, half_ext.y));
	vec2 q = abs(d) - (half_ext - vec2(r));
	float sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	sdf += pushv * push_px;

	// The contour must never read as a rectangle. bd.x and bd.y each sweep
	// -1..1 around the loop, so sines of them are seamless -- no atan, no seam.
	sdf -= wobble_px * (
		  0.55 * sin(bd.x * 3.1 + TIME * 0.23)
		+ 0.30 * sin(bd.y * 4.7 - TIME * 0.19)
		+ 0.15 * sin((bd.x + bd.y) * 7.3 + TIME * 0.31));

	float inner = smoothstep(-band_px, 0.0, sdf);
	float band  = inner * inner * (1.0 - smoothstep(0.0, 20.0, sdf));
	float line  = 1.0 - smoothstep(0.0, line_px, abs(sdf));

	vec3 glow = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float w = smoothstep(glow_lobes[i].z, 1.0, dot(bd, glow_lobes[i].xy));
		glow += glow_colors[i] * (w * glow_lobes[i].w);
	}

	float interior = 1.0 - smoothstep(0.0, 1.15, length(vec2(d.x / c.x, d.y / c.y)));

	vec3 col = mix(base_color, dread_color, clamp(dread, 0.0, 1.0));
	col += pulse_color * (pulse * (line * 0.50 + band * 0.05) * gain);
	col += glow * (band * gain);
	col += press_color * (pushv * line * 0.95 * gain);
	col += flash_color * (flash * (line * 1.0 + band * 0.22) * gain);
	col += ingest_color * (ingest * interior * 0.38 * gain);

	// 8-bit dither. Dim wide gradients on a near-black field band visibly
	// without it -- the tail of a faint lobe shows as a hard straight line.
	col += vec3(fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;

	COLOR = vec4(col, 1.0);
}
