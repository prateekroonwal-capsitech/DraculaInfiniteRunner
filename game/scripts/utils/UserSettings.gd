class_name UserSettings
extends RefCounted

## UserSettings — Manages persistent local player preferences (e.g. controller styles).
## Uses ConfigFile ("user://settings.cfg") so settings survive restarts, scene transitions,
## and level retries without modifying unrelated gameplay systems or requiring new autoloads.

const SETTINGS_FILE := "user://settings.cfg"
const SECTION_CONTROLS := "controls"
const KEY_SUNLIGHT_CONTROLLER := "sunlight_controller"

const CONTROLLER_SLIDER := "slider"
const CONTROLLER_JOYSTICK := "joystick"

static var _cached_sunlight_controller: String = ""

static func get_sunlight_controller() -> String:
	if not _cached_sunlight_controller.is_empty():
		return _cached_sunlight_controller
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE)
	if err == OK:
		_cached_sunlight_controller = config.get_value(SECTION_CONTROLS, KEY_SUNLIGHT_CONTROLLER, CONTROLLER_SLIDER)
	else:
		_cached_sunlight_controller = CONTROLLER_SLIDER
	return _cached_sunlight_controller

static func set_sunlight_controller(controller_type: String) -> void:
	if controller_type != CONTROLLER_SLIDER and controller_type != CONTROLLER_JOYSTICK:
		controller_type = CONTROLLER_SLIDER
	_cached_sunlight_controller = controller_type
	var config := ConfigFile.new()
	var _err := config.load(SETTINGS_FILE) # Load existing settings to avoid overwriting other keys
	config.set_value(SECTION_CONTROLS, KEY_SUNLIGHT_CONTROLLER, controller_type)
	config.save(SETTINGS_FILE)
