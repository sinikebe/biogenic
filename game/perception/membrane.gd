extends CanvasLayer
## The membrane layer: one full-rect ColorRect and one shader, per
## docs/design/perception.md §3.
##
## This node only keeps the shader's idea of the viewport honest. Every signal
## goes through the bus at $Signals, which is the only writer of uniforms.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const SignalBus := preload("res://game/perception/signal_bus.gd")

## Keeps the contour clear of rounded corners and camera cutouts. Raised from
## the reported safe area on Android when the device asks for more.
const BASE_INSET_PX := 28.0
## Breathing room past whatever inset the device reports, in canvas pixels.
const SAFE_AREA_PAD_PX := 8.0

@onready var field: ColorRect = $Field
## What gameplay talks to. Grab it as $Membrane.bus.
@onready var bus: SignalBus = $Signals


func _ready() -> void:
	bus.attach(field.material as ShaderMaterial)
	field.resized.connect(_refresh_geometry)
	_refresh_geometry()


func _refresh_geometry() -> void:
	bus.set_geometry(field.size, _inset_px())


## Canvas-space inset for the contour.
##
## Everything here is guarded: a headless boot has no window and reports a
## zero-sized safe area, and desktops have no cutouts to dodge.
func _inset_px() -> float:
	if OS.get_name() != "Android":
		return BASE_INSET_PX

	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return BASE_INSET_PX
	if field.size.y <= 0.0:
		return BASE_INSET_PX

	var worst := maxi(
		maxi(safe.position.x, safe.position.y),
		maxi(win.x - safe.position.x - safe.size.x, win.y - safe.position.y - safe.size.y))
	if worst <= 0:
		return BASE_INSET_PX

	# Physical pixels to canvas units: canvas_items/expand keeps the canvas 720
	# tall whatever the screen is.
	var to_canvas := field.size.y / float(win.y)
	return maxf(BASE_INSET_PX, float(worst) * to_canvas + SAFE_AREA_PAD_PX)
