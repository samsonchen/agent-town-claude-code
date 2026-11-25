class_name OfficeColumns
extends RefCounted
## How many columns the project blocks are laid out in (docs/spec.md: The office → A window larger
## than the office): the count that shows the office largest in the window, so a wide window
## (maximized) puts blocks side by side instead of leaving the sides empty.
## Port of `OfficeColumns` in app/macos/Sources/TownCore/OfficeColumns.swift.

## A new count must show the office at least this much larger than the current one, so a window
## near the edge between two counts does not flip back and forth.
const KEEP := 1.08


## The scale (pixels per meter) the office is drawn at: as large as fits the window, between
## `min_scale` (smaller windows scroll) and `max_scale`. `office` is its on-screen size at one pixel
## per meter (depth already foreshortened).
static func scale(office: Vector2, window: Vector2, min_scale: float, max_scale: float) -> float:
	var k := minf(window.x / maxf(1.0, office.x), window.y / maxf(1.0, office.y))
	return minf(max_scale, maxf(min_scale, k))


## The column count for `projects` blocks in `window`: the one that draws the office largest, fewer
## columns on a tie, and more than one only when they fit across the window. `current` is kept while
## it fits, unless another count is KEEP times larger. `office.call(c)` is the office's on-screen size
## at one pixel per meter with `c` columns.
static func best(projects: int, current: int, window: Vector2, min_scale: float, max_scale: float, office: Callable) -> int:
	var most := maxi(1, projects)
	var k := func(c: int) -> float: return scale(office.call(c), window, min_scale, max_scale)
	# Blocks side by side only when they fit across the window: a narrow one scrolls up and down
	# through one column, never sideways.
	var fits := func(c: int) -> bool: return c == 1 or (office.call(c) as Vector2).x * float(k.call(c)) <= window.x + 0.5
	var chosen := 1
	for c in range(2, most + 1):
		if fits.call(c) and float(k.call(c)) > float(k.call(chosen)) * 1.001:
			chosen = c
	var now := mini(maxi(1, current), most)
	if not fits.call(now):
		return chosen
	return chosen if float(k.call(chosen)) > float(k.call(now)) * KEEP else now
