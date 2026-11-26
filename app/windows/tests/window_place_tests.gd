extends TestSupport
## When the window's place is saved: after a move or resize settles, and while a saved place waits
## for its screen, only after the user's own move.

func test_a_move_is_saved_once_it_settles() -> void:
	var p := WindowPlace.new()
	check_eq(p.step(Rect2i(0, 0, 320, 400), true, false, 0), false, "the first look is not a change")
	check_eq(p.step(Rect2i(10, 0, 320, 400), true, true, 100), false, "dragging")
	check_eq(p.step(Rect2i(20, 0, 320, 400), true, true, 300), false, "still dragging")
	check_eq(p.step(Rect2i(20, 0, 320, 400), true, false, 700), false, "not yet half a second since the last step")
	check_eq(p.step(Rect2i(20, 0, 320, 400), true, false, 800), true, "saved")
	check_eq(p.step(Rect2i(20, 0, 320, 400), true, false, 2000), false, "saved once")


func test_a_resize_by_the_app_is_saved() -> void:
	var p := WindowPlace.new()
	p.step(Rect2i(0, 0, 320, 400), true, false, 0)
	p.step(Rect2i(0, 0, 320, 600), true, false, 10) # the height fits the office
	check_eq(p.step(Rect2i(0, 0, 320, 600), true, false, 510), true, "saved")


func test_a_maximized_window_is_not_saved() -> void:
	var p := WindowPlace.new()
	p.step(Rect2i(0, 0, 320, 400), true, false, 0)
	p.step(Rect2i(0, 0, 1920, 1040), false, true, 10)
	check_eq(p.step(Rect2i(0, 0, 1920, 1040), false, false, 1000), false, "not saved")


func test_a_waiting_place_is_kept_until_the_user_moves_the_window() -> void:
	var p := WindowPlace.new()
	p.waiting = true
	p.step(Rect2i(0, 0, 320, 400), true, false, 0)
	p.step(Rect2i(0, 0, 320, 700), true, false, 10) # placed and fitted by the app
	check_eq(p.step(Rect2i(0, 0, 320, 700), true, false, 600), false, "not the user's: not saved")
	check_eq(p.waiting, true, "still waiting")
	p.step(Rect2i(50, 0, 320, 700), true, true, 1000) # the user drags it
	check_eq(p.step(Rect2i(50, 0, 320, 700), true, false, 1600), true, "the user's move is saved")
	check_eq(p.waiting, false, "no longer waiting")
