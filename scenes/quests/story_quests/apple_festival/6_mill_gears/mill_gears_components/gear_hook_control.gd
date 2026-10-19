# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
## A [HookControl] that aims in global space, for needles planted on a gear.
##
## [HookControl] stores the aim as a global angle -- it comes from the mouse position or the
## input vector, and [method HookControl._throw] measures its air point in global space -- but
## assigns it to the node's own [member Node2D.rotation]. On an upright needle the two are the
## same thing. On one that is tilted, or bolted to a gear that is turning underneath it, the
## aim arrow and the ray both come out skewed by however far the needle has gone round, so the
## throw does not go where the player pointed.
##
## Only the aim is corrected. Everything the needle owns stays attached to the needle, the
## bouncing [code]HookableIndicator[/code] included: that one is meant to lean with it.
class_name GearHookControl
extends HookControl


## Mirrors [method HookControl._process], except that the aim angle is applied globally.
##
## It has to be a copy rather than a call up to [HookControl]: the base sets the rotation and
## then casts the ray against it in one pass, so there is no point in between at which this
## could correct the angle without the ray having already been aimed at the wrong thing.
func _process(_delta: float) -> void:
	if state == State.DISABLED:
		return
	global_rotation = _get_hook_angle()
	if state == State.AIMING:
		_update_pointing_at_area()
	sprite_2d.modulate = Color.WHITE if _pointing_at_area else Color(Color.WHITE, 0.5)
	if hooked_to:
		# Currently the control can be hooked to a single area.
		return
	if state != State.AIMING_PAUSED and pressing_throw_action and not throw_failed_while_pressing:
		_throw()
