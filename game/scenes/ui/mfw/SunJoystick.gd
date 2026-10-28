class_name SunJoystick
extends UIController

## SunJoystick — virtual joystick for sunlight control (bottom-right corner).
##
## Transparent background: no black panel, background circle, or container.
## Only shows the control elements: a thin, subtle base outline and a minimal handle.
## Located in the bottom-right corner within the screen safe area.
##
## Controls the exact same SunRig target azimuth/elevation and limits as SunControl.
## Touch arbitration: touches on the joystick are consumed in _input() so DraculaController
## never sees them as lane swipes.
## Releasing the joystick preserves the current sunlight angle.

@export var base_radius: float = 110.0
@export var handle_radius: float = 36.0
@export var drag_sensitivity: float = 1.0
@export var key_azimuth_speed: float = 135.0
@export var key_elevation_speed: float = 135.0

@export var base_border_color: Color = Color(1.0, 0.86, 0.55, 0.28)
@export var guide_color: Color = Color(1.0, 0.86, 0.55, 0.35)
@export var sun_color: Color = Color(1.0, 0.8, 0.28, 1.0)
@export var label_font_size: int = 20

var _sun: SunRig
var _owned_touches: Dictionary = {}   # touch index (-1 = mouse) -> grab anchor {touch_start, az_start, el_start}
var _enabled: bool = true

var travel_radius: float:
	get:
		return maxf(1.0, base_radius - handle_radius)

func bind_sun(sun: SunRig) -> void:
	if _sun and _sun.sun_moved.is_connected(_on_sun_moved):
		_sun.sun_moved.disconnect(_on_sun_moved)
	_sun = sun
	if _sun:
		_sun.sun_moved.connect(_on_sun_moved)
	queue_redraw()

func set_controls_enabled(enabled: bool) -> void:
	_enabled = enabled
	_owned_touches.clear()
	set_process(false)
	set_process_input(enabled)

func _on_ready() -> void:
	set_process_input(true)

func _exit_tree() -> void:
	bind_sun(null)

# ── Input ─────────────────────────────────────────────────────────────────

func _is_paused() -> bool:
	return get_tree().paused if get_tree() else false

func _consume_input() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not _enabled or _sun == null or _is_paused():
		return
	if event is InputEventKey:
		if event.is_action("sun_left") or event.is_action("sun_right") or event.is_action("sun_up") or event.is_action("sun_down"):
			set_process(true)
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _is_inside(st.position):
			_begin_drag(st.index, st.position)
			_consume_input()
		elif not st.pressed and _owned_touches.erase(st.index):
			_consume_input()
			queue_redraw()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _owned_touches.has(sd.index):
			_drag_to(sd.index, sd.position)
			_consume_input()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed and _is_inside(mb.position):
			_begin_drag(-1, mb.position)
			_consume_input()
		elif not mb.pressed and _owned_touches.erase(-1):
			_consume_input()
			queue_redraw()
	elif event is InputEventMouseMotion and _owned_touches.has(-1):
		_drag_to(-1, (event as InputEventMouseMotion).position)
		_consume_input()

func _process(delta: float) -> void:
	if not _enabled or _sun == null or _is_paused():
		set_process(false)
		return
	var d_az := Input.get_axis("sun_left", "sun_right") * key_azimuth_speed * delta
	var d_el := Input.get_axis("sun_down", "sun_up") * key_elevation_speed * delta
	if is_zero_approx(d_az) and is_zero_approx(d_el):
		set_process(false)
		return
	_sun.nudge_target(d_az, d_el)
	queue_redraw()

# ── Geometry & Dragging ───────────────────────────────────────────────────

func _to_local(viewport_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_pos

func _is_inside(viewport_pos: Vector2) -> bool:
	var local_p := _to_local(viewport_pos)
	return local_p.distance_to(_get_center()) <= (base_radius + 24.0)

func _get_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5)

func _begin_drag(index: int, viewport_pos: Vector2) -> void:
	var local_p := _to_local(viewport_pos)
	_owned_touches[index] = {
		"touch_start": local_p,
		"az_start": _sun.target_azimuth,
		"el_start": _sun.target_elevation
	}
	_consume_input()
	queue_redraw()

func _drag_to(index: int, viewport_pos: Vector2) -> void:
	if not _owned_touches.has(index) or _sun == null or not _enabled or _is_paused():
		return
	var grab: Dictionary = _owned_touches[index]
	var local_p := _to_local(viewport_pos)
	var delta: Vector2 = local_p - grab.touch_start

	var half_az := (_sun.azimuth_max - _sun.azimuth_min) * 0.5
	var half_el := (_sun.elevation_max - _sun.elevation_min) * 0.5

	# Map pixel travel to angle delta
	var d_az: float = (delta.x / travel_radius) * half_az * drag_sensitivity
	var d_el: float = (-delta.y / travel_radius) * half_el * drag_sensitivity

	var target_az: float = grab.az_start + d_az
	var target_el: float = grab.el_start + d_el

	# Circular boundary clamping in normalized joystick space
	var mid_az := (_sun.azimuth_min + _sun.azimuth_max) * 0.5
	var mid_el := (_sun.elevation_min + _sun.elevation_max) * 0.5
	var norm := Vector2((target_az - mid_az) / half_az, (target_el - mid_el) / half_el)
	if norm.length_squared() > 1.0:
		norm = norm.normalized()
		target_az = mid_az + norm.x * half_az
		target_el = mid_el + norm.y * half_el

	_sun.set_target(target_az, target_el)

	# Clamped at a limit: re-anchor so reversing direction responds immediately
	if not is_equal_approx(_sun.target_azimuth, grab.az_start + d_az) or not is_equal_approx(_sun.target_elevation, grab.el_start + d_el):
		_owned_touches[index] = {
			"touch_start": local_p,
			"az_start": _sun.target_azimuth,
			"el_start": _sun.target_elevation
		}
	queue_redraw()

func _angles_to_local(az: float, el: float) -> Vector2:
	if _sun == null:
		return _get_center()
	var mid_az := (_sun.azimuth_min + _sun.azimuth_max) * 0.5
	var half_az := maxf(1.0, (_sun.azimuth_max - _sun.azimuth_min) * 0.5)
	var mid_el := (_sun.elevation_min + _sun.elevation_max) * 0.5
	var half_el := maxf(1.0, (_sun.elevation_max - _sun.elevation_min) * 0.5)

	var nx := clampf((az - mid_az) / half_az, -1.0, 1.0)
	var ny := clampf((el - mid_el) / half_el, -1.0, 1.0)
	var norm := Vector2(nx, ny)
	if norm.length_squared() > 1.0:
		norm = norm.normalized()

	return _get_center() + Vector2(norm.x * travel_radius, -norm.y * travel_radius)

# ── Drawing ───────────────────────────────────────────────────────────────

func _on_sun_moved(_az: float, _el: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Transparent background: no black panel, background circle, or container.
	if _sun == null:
		return

	var c := _get_center()
	var font := get_theme_default_font()

	# 1. Thin, subtle base outline (no fill, fully transparent inside)
	draw_arc(c, base_radius, 0.0, TAU, 48, base_border_color, 1.8, true)
	draw_arc(c, travel_radius, 0.0, TAU, 36, Color(guide_color.r, guide_color.g, guide_color.b, 0.12), 1.0, true)

	# 2. Subtle cardinal ticks on rim
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * (base_radius - 6.0), c + dir * (base_radius + 4.0), Color(guide_color.r, guide_color.g, guide_color.b, 0.35), 1.5, true)

	# 3. HIGH and LOW subtle labels
	var high_pos := Vector2(c.x, c.y - base_radius - 6.0)
	draw_string(font, high_pos + Vector2(-24, 0), "HIGH", HORIZONTAL_ALIGNMENT_CENTER, 48, label_font_size, Color(guide_color.r, guide_color.g, guide_color.b, 0.45))
	var low_pos := Vector2(c.x, c.y + base_radius + 20.0)
	draw_string(font, low_pos + Vector2(-24, 0), "LOW", HORIZONTAL_ALIGNMENT_CENTER, 48, label_font_size, Color(guide_color.r, guide_color.g, guide_color.b, 0.45))

	# 4. Target and Live positions
	var target_pos := _angles_to_local(_sun.target_azimuth, _sun.target_elevation)
	var live_pos := _angles_to_local(_sun.azimuth, _sun.elevation)

	# Connecting arm from center to handle
	draw_line(c, target_pos, Color(sun_color.r, sun_color.g, sun_color.b, 0.22), 2.0, true)

	# Subtle trail if live sun hasn't caught up to target
	if live_pos.distance_to(target_pos) > 3.0:
		draw_line(live_pos, target_pos, Color(sun_color.r, sun_color.g, sun_color.b, 0.3), 2.5, true)
		draw_arc(live_pos, handle_radius * 0.5, 0.0, TAU, 24, Color(sun_color.r, sun_color.g, sun_color.b, 0.4), 1.5, true)

	# Active drag feedback ring
	if not _owned_touches.is_empty():
		draw_arc(target_pos, handle_radius + 4.0, 0.0, TAU, 32, Color(1.0, 0.92, 0.6, 0.6), 2.0, true)

	# Minimal golden sun handle
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector2(cos(a), sin(a))
		draw_line(target_pos + d * (handle_radius * 0.65), target_pos + d * handle_radius, Color(sun_color.r, sun_color.g, sun_color.b, 0.85), 2.5, true)

	# Disc & gothic core
	draw_circle(target_pos, handle_radius * 0.62, sun_color)
	draw_circle(target_pos, handle_radius * 0.38, Color(1.0, 0.97, 0.82))
	draw_circle(target_pos, handle_radius * 0.18, Color(0.72, 0.06, 0.10))
