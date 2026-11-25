class_name ViewScale
extends RefCounted
## The office's drawing scale and text size at its normal size. The office is drawn at half the scale
## of the first versions and its text at 75%, the smallest that stays readable; a window larger than
## the office draws both larger (`zoom`). (Large view, the full-size setting, was removed in Windows
## app 1.0.12: the office grows with the window instead.) Port of `ViewScale` in
## app/macos/Sources/AgentTown/Layout.swift.

## The office's drawing scale.
const world := 0.5
## Tags, signs, statements and context bars.
const text := 0.75
## How much larger than its normal size the office is drawn now, when the window is larger than the
## office (1 to main.gd's MAX_ZOOM). Set by main.gd as the camera is placed; text grows with it.
static var zoom := 1.0


## Text size now: `text` times `zoom`.
static func label() -> float:
	return text * zoom
