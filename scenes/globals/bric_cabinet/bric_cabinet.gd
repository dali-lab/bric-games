# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node
## Arcade-cabinet behaviour for the Cider Quest build.
##
## Does nothing unless the game is an exported build with the [code]bric_cider[/code] feature
## tag. In the editor, and when running a single scene with F6, it stays inactive so it never
## gets in the way of testing.
## [br][br]
## When active, it:
## [br]• adds the cabinet controls to the input map (see [CabinetInput]);
## [br]• never keeps progress, settings or window changes between plays;
## [br]• goes back to the title screen after [constant IDLE_TIMEOUT] seconds without input, so
##   the next player doesn't start in the middle of someone else's level;
## [br]• leaves the game when all three cabinet buttons are held for [constant EXIT_HOLD_TIME]
##   seconds: native builds quit, web builds close their window.

const FEATURE := "bric_cider"

## Seconds without any input before going back to the title screen.
const IDLE_TIMEOUT := 90.0

## Seconds to hold A, B and C together to leave the game.
const EXIT_HOLD_TIME := 2.0

## Stick movement smaller than this doesn't count as input, so a drifting stick can't keep an
## abandoned game alive.
const STICK_DEAD_ZONE := 0.3

## Show the exit countdown once the buttons have been held this long, so that pressing them
## together briefly doesn't flash it.
const EXIT_HINT_DELAY := 0.3

const TITLE_SCENE := "uid://stdqc6ttomff"

var _numbering: CabinetInput.Numbering
var _idle_time := 0.0
var _exit_hold := 0.0
## Whether the exit chord must be released before it can trigger again. Used after a web build
## fails to close its window, which browsers refuse for tabs that a script didn't open.
var _exit_needs_release := false
## Single-level tester links (web builds opened with a #scene hash) are debugging sessions, so
## they are never sent back to the title screen.
var _idle_reset_enabled := true
## Joypads that have sent input, in addition to [method Input.get_connected_joypads]. Some
## platforms only report a pad as connected after its first input.
var _seen_devices: Dictionary[int, bool] = {}
var _exit_hint: Label


static func is_active() -> bool:
	return OS.has_feature(FEATURE) and not OS.has_feature("editor")


func _enter_tree() -> void:
	if not is_active():
		return
	# Before the GameState and Settings autoloads read these files.
	_forget_user_files()


func _ready() -> void:
	if not is_active():
		set_process(false)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	_numbering = (
		CabinetInput.Numbering.STANDARD if OS.has_feature("web") else CabinetInput.Numbering.CABINET
	)
	CabinetInput.apply(_numbering)

	GameState.persist_progress = false
	GameState.clear()

	if OS.has_feature("web") and JavaScriptBridge.eval("window.location.hash", true):
		_idle_reset_enabled = false

	get_window().window_input.connect(_on_window_input)
	_build_exit_hint()


func _process(delta: float) -> void:
	var exit_buttons: Array = CabinetInput.BUTTONS[_numbering]
	var any_input := false
	var exit_held := false
	for device: int in Input.get_connected_joypads():
		_seen_devices[device] = true
	for device: int in _seen_devices:
		any_input = any_input or _is_pad_in_use(device)
		exit_held = (
			exit_held
			or exit_buttons.all(
				func(button: int) -> bool: return Input.is_joy_button_pressed(device, button)
			)
		)

	_update_exit(exit_held, delta)

	if any_input:
		_idle_time = 0.0
	else:
		_idle_time += delta
	if _idle_reset_enabled and _idle_time >= IDLE_TIMEOUT:
		_reset_to_title()


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_seen_devices[event.device] = true
	if event is InputEventJoypadMotion and absf(event.axis_value) < STICK_DEAD_ZONE:
		return
	_idle_time = 0.0


func _is_pad_in_use(device: int) -> bool:
	for button: int in JOY_BUTTON_SDL_MAX:
		if Input.is_joy_button_pressed(device, button):
			return true
	for axis: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if absf(Input.get_joy_axis(device, axis)) >= STICK_DEAD_ZONE:
			return true
	return false


func _update_exit(exit_held: bool, delta: float) -> void:
	if not exit_held:
		_exit_hold = 0.0
		_exit_needs_release = false
		_exit_hint.hide()
		return
	if _exit_needs_release:
		return

	_exit_hold += delta
	if _exit_hold >= EXIT_HOLD_TIME:
		_exit_hint.hide()
		_exit_to_arcade()
	elif _exit_hold >= EXIT_HINT_DELAY:
		_exit_hint.text = (
			tr("Keep holding to leave the game… %d") % ceili(EXIT_HOLD_TIME - _exit_hold)
		)
		_exit_hint.show()


func _exit_to_arcade() -> void:
	_exit_needs_release = true
	_forget_user_files()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.close()", true)
	else:
		get_tree().quit()


func _reset_to_title() -> void:
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.scene_file_path == ResourceUID.ensure_path(TITLE_SCENE):
		_idle_time = 0.0
		return
	if Transitions.is_running():
		# Try again next frame.
		return

	_idle_time = 0.0
	if PauseOverlay.visible:
		PauseOverlay.toggle_pause()
	get_tree().paused = false
	GameState.clear()
	_forget_user_files()
	SceneSwitcher.change_to_file_with_transition(
		TITLE_SCENE, ^"", Transition.Effect.FADE, Transition.Effect.FADE
	)


func _forget_user_files() -> void:
	for path: String in [
		GameState.SAVE_PATH,
		Settings.SETTINGS_PATH,
		ProjectSettings.get_setting("application/config/project_settings_override"),
	]:
		if path and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _build_exit_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_exit_hint = Label.new()
	_exit_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_exit_hint.position.y = 24
	_exit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_exit_hint.add_theme_font_size_override(&"font_size", 32)
	_exit_hint.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_exit_hint.add_theme_constant_override(&"outline_size", 8)
	_exit_hint.hide()
	layer.add_child(_exit_hint)
