# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name CabinetInput
extends RefCounted
## Input profile for the BRIC arcade cabinet: one stick and three buttons, A, B and C.
##
## The bindings are only ever added, never removed, so keyboard and normal gamepad controls keep
## working alongside them.
## [br][br]
## The same physical button has a different index depending on how the game runs, and the two
## numberings overlap (index 2 is C in one and A in the other). So [BricCabinet] applies exactly
## one of them, picked by platform, rather than both living in the project's input map.
## [br][br]
## [b]A[/b]: talk, interact, advance dialogue, confirm in menus.
## [br][b]B[/b]: run; throw the grappling hook in levels that have it; back in menus.
## [br][b]C[/b]: pause menu.
## [br][b]Stick[/b]: move, navigate menus, and aim the grappling hook.

enum Numbering {
	## Standard gamepad layout. The arcade launcher's web gamepad shim presents the cabinet this
	## way, so it is what web builds see.
	STANDARD,
	## The cabinet's raw button indices, as a native build on the cabinet sees them.
	CABINET,
}

## Button index of A, B and C in each [enum Numbering].
const BUTTONS: Dictionary[Numbering, Array] = {
	Numbering.STANDARD: [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X],
	Numbering.CABINET: [2, 3, 4],
}

## Actions triggered by A, B and C, in that order.
const BUTTON_ACTIONS: Array[Array] = [
	[&"ui_accept", &"interact", &"dialogue_next", &"dialogue_skip"],
	[&"running", &"throw", &"ui_cancel"],
	[&"pause"],
]

## There is no right stick, so the left stick also aims. Levels where that clashes with walking
## (the mill gears) use [JoystickAimMode] to hold the player still while aiming.
const STICK_ACTIONS: Dictionary[StringName, Array] = {
	&"aim_left": [JOY_AXIS_LEFT_X, -1.0],
	&"aim_right": [JOY_AXIS_LEFT_X, 1.0],
	&"aim_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"aim_down": [JOY_AXIS_LEFT_Y, 1.0],
}


## Adds the cabinet bindings in [param numbering] to the input map.
static func apply(numbering: Numbering) -> void:
	var buttons: Array = BUTTONS[numbering]
	for i: int in BUTTON_ACTIONS.size():
		for action: StringName in BUTTON_ACTIONS[i]:
			var event := InputEventJoypadButton.new()
			event.device = -1
			event.button_index = buttons[i]
			_add_event(action, event)

	for action: StringName in STICK_ACTIONS:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = STICK_ACTIONS[action][0]
		event.axis_value = STICK_ACTIONS[action][1]
		_add_event(action, event)


static func _add_event(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		push_warning("Cabinet input: no action named %s" % action)
		return
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
