class_name PausePanel
extends UIController

## Pause panel. Runs while the tree is paused (PROCESS_MODE_ALWAYS).
## Resume is handled here (GameManager.resume + close); leaving the run is an
## intent for ShadowRunFeature, which owns scene changes.
## Allows selecting between "Slider" and "Joystick" sunlight controller styles.

signal home_requested

@onready var _resume: Button = %ResumeButton
@onready var _home: Button = %HomeButton
@onready var _slider_btn: Button = %SliderButton
@onready var _joystick_btn: Button = %JoystickButton

var _style_selected: StyleBox
var _style_unselected: StyleBox
var _style_unselected_hover: StyleBox

var _bus: Node

func _ready() -> void:
	super._ready()
	# Keeps this UI receiving input while the scene tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_ready() -> void:
	if _resume == null and has_node("%ResumeButton"):
		_resume = %ResumeButton
	if _home == null and has_node("%HomeButton"):
		_home = %HomeButton
	if _slider_btn == null and has_node("%SliderButton"):
		_slider_btn = %SliderButton
	if _joystick_btn == null and has_node("%JoystickButton"):
		_joystick_btn = %JoystickButton

	var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry") if (get_tree() and get_tree().root) else null
	if registry:
		_bus = registry.get_service(&"bus") as Node

	# Cache styleboxes configured in the scene
	if _slider_btn:
		_style_selected = _slider_btn.get_theme_stylebox("normal")
	if _joystick_btn:
		_style_unselected = _joystick_btn.get_theme_stylebox("normal")
		_style_unselected_hover = _joystick_btn.get_theme_stylebox("hover")

	if _resume:
		_resume.pressed.connect(_on_resume_pressed)
	if _home:
		_home.pressed.connect(func() -> void: home_requested.emit())
	if _slider_btn:
		_slider_btn.pressed.connect(_on_slider_selected)
	if _joystick_btn:
		_joystick_btn.pressed.connect(_on_joystick_selected)

	_refresh_controller_selection()
	if _resume:
		_resume.grab_focus.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if _initialized and event.is_action_pressed("pause_run"):
		if get_viewport():
			get_viewport().set_input_as_handled()
		_on_resume_pressed()

func _on_resume_pressed() -> void:
	if _game_manager:
		_game_manager.resume()
	close()

func _on_slider_selected() -> void:
	_select_controller(UserSettings.CONTROLLER_SLIDER)

func _on_joystick_selected() -> void:
	_select_controller(UserSettings.CONTROLLER_JOYSTICK)

func _select_controller(controller_type: String) -> void:
	UserSettings.set_sunlight_controller(controller_type)
	_refresh_controller_selection()

	if _bus and _bus.has_signal("sunlight_controller_changed"):
		_bus.sunlight_controller_changed.emit(controller_type)

	var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry") if (get_tree() and get_tree().root) else null
	if registry:
		var save = registry.get_service(&"save") as SaveManager
		if save and save.has_method("set_value"):
			save.set_value("sunlight_controller", controller_type)

func _refresh_controller_selection() -> void:
	var current := UserSettings.get_sunlight_controller()
	var is_slider := (current == UserSettings.CONTROLLER_SLIDER)

	_apply_button_state(_slider_btn, is_slider, "Slider")
	_apply_button_state(_joystick_btn, not is_slider, "Joystick")

func _apply_button_state(btn: Button, selected: bool, label_text: String) -> void:
	if btn == null:
		return
	if selected:
		btn.text = "● " + label_text
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.9, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 0.9, 1.0))
		btn.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.82, 1.0))
		if _style_selected:
			btn.add_theme_stylebox_override("normal", _style_selected)
			btn.add_theme_stylebox_override("hover", _style_selected)
			btn.add_theme_stylebox_override("pressed", _style_selected)
			btn.add_theme_stylebox_override("focus", _style_selected)
	else:
		btn.text = label_text
		btn.add_theme_color_override("font_color", Color(0.7, 0.65, 0.72, 0.8))
		btn.add_theme_color_override("font_hover_color", Color(0.9, 0.85, 0.92, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.85, 0.92, 1.0))
		btn.add_theme_color_override("font_focus_color", Color(0.7, 0.65, 0.72, 0.8))
		if _style_unselected:
			btn.add_theme_stylebox_override("normal", _style_unselected)
			btn.add_theme_stylebox_override("focus", _style_unselected)
		if _style_unselected_hover:
			btn.add_theme_stylebox_override("hover", _style_unselected_hover)
			btn.add_theme_stylebox_override("pressed", _style_unselected_hover)
