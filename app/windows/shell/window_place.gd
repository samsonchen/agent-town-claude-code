class_name WindowPlace
extends RefCounted
## When the office window's place is saved (spec: The window opens where it was). The window is
## watched each frame; a move or resize is saved about half a second after the last change, so a
## drag does not write the settings file on every step, and a force-closed app (the installer's
## `taskkill /F`, an OS restart) still opens where it was.
##
## A saved place whose screen is not connected at launch (at login an external display can come a
## little later) is `waiting`: it is not replaced by the place the window got instead, only by the
## user's own move or resize (made with a mouse button down). main.gd moves the window back there
## when that screen connects. Port of `WindowPlace` in app/macos/Sources/AgentTown/TownView.swift.

const SAVE_DELAY := 500 ## msec after the last change

var waiting := false
var _seen := Rect2i()
var _seen_once := false
var _save_at := -1
var _by_user := false


## Called each frame with the window's place (position and size). True when it should be saved
## now. Changes while the window is maximized, minimized or full screen are not saved.
func step(place: Rect2i, windowed: bool, mouse_down: bool, now: int) -> bool:
	if not _seen_once or place != _seen:
		var first := not _seen_once
		_seen = place
		_seen_once = true
		if not first and windowed:
			_save_at = now + SAVE_DELAY
			_by_user = _by_user or mouse_down
	if _save_at < 0 or now < _save_at:
		return false
	_save_at = -1
	var user := _by_user
	_by_user = false
	if waiting and not user:
		return false # where Windows or the app put the window: the saved place still waits
	waiting = false
	return true
