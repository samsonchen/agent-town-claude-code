extends TestSupport
## The column count for project blocks (OfficeColumnsTests.swift on the Mac).


## Blocks 7 m wide and 6 m deep (path included), an executive strip 2 m deep; as on screen.
func _office(projects: int) -> Callable:
	return func(c: int) -> Vector2:
		var rows := (projects + c - 1) / c
		return Vector2(float(c) * 8.0 + 1.0, 3.0 + float(rows) * 6.0)


func _best(projects: int, window: Vector2, current: int = 1) -> int:
	return OfficeColumns.best(projects, current, window, 35.0, 165.0, _office(projects))


func test_a_narrow_window_keeps_one_column() -> void:
	check_eq(_best(4, Vector2(500, 900)), 1, "narrow")


func test_a_wide_window_puts_blocks_side_by_side() -> void:
	check_eq(_best(4, Vector2(2560, 1400)), 2, "four projects")
	check_eq(_best(6, Vector2(2560, 1400)), 3, "six projects")


func test_one_project_stays_in_one_column() -> void:
	check_eq(_best(1, Vector2(2560, 1400)), 1, "one project")
	check_eq(_best(0, Vector2(2560, 1400)), 1, "none")


func test_a_tie_keeps_fewer_columns() -> void:
	# Both counts reach the largest scale in a huge window: no reason to spread out.
	check_eq(_best(2, Vector2(20000, 20000)), 1, "tie")


func test_a_small_gain_keeps_the_current_count() -> void:
	# 3 projects: one column is 9 by 21, two are 17 by 15. In this window two columns draw the
	# office 5% larger: not enough to switch, nor to switch back.
	var o := _office(3)
	var close := Vector2(1275, 1500)
	var k1 := OfficeColumns.scale(o.call(1), close, 35.0, 165.0)
	var k2 := OfficeColumns.scale(o.call(2), close, 35.0, 165.0)
	check(k2 > k1 and k2 < k1 * OfficeColumns.KEEP, "two columns a little larger")
	check_eq(_best(3, close, 1), 1, "stays at one")
	check_eq(_best(3, close, 2), 2, "stays at two")


func test_a_narrowed_window_goes_back_to_one_column() -> void:
	# Made narrow after being wide: two columns would need sideways scrolling.
	check_eq(_best(6, Vector2(420, 900), 2), 1, "from two")
	check_eq(_best(6, Vector2(420, 900), 3), 1, "from three")


func test_a_count_past_the_projects_is_clamped() -> void:
	check(_best(2, Vector2(500, 900), 5) <= 2, "clamped")


func test_the_scale_stays_in_its_range() -> void:
	check_eq(OfficeColumns.scale(Vector2(10, 10), Vector2(100, 100), 35.0, 165.0), 35.0, "smallest")
	check_eq(OfficeColumns.scale(Vector2(10, 10), Vector2(5000, 5000), 35.0, 165.0), 165.0, "largest")
	check_eq(OfficeColumns.scale(Vector2(10, 10), Vector2(800, 600), 35.0, 165.0), 60.0, "fits")


func test_layout_fills_columns_then_rows() -> void:
	# Executive block plus five projects in two columns: three rows, the executive block centered.
	var size := Layout.office_size(6, 2)
	check(is_equal_approx(size.x, 2.0 * Layout.MARGIN + 2.0 * Layout.BLOCK_WIDTH + Layout.GAP), "two blocks wide")
	check(is_equal_approx(size.y, 2.0 * Layout.MARGIN + Layout.EXEC_DEPTH + 3.0 * (Layout.GAP + Layout.BLOCK_DEPTH)), "three rows")
	check(is_equal_approx(Layout.block_origin(0, 6, 2).x, (size.x - Layout.BLOCK_WIDTH) / 2.0), "executive centered")
	check_eq(Layout.block_origin(1, 6, 2), Layout.block_origin(1, 6, 1), "first project at the left")
	check_eq(Layout.block_origin(2, 6, 2).y, Layout.block_origin(1, 6, 2).y, "second beside it")
	check(is_equal_approx(Layout.block_origin(2, 6, 2).x, Layout.MARGIN + Layout.BLOCK_WIDTH + Layout.GAP), "in the second column")
	check(is_equal_approx(Layout.block_origin(3, 6, 2).x, Layout.MARGIN), "third starts the next row")
	check_eq(Layout.office_size(2, 4), Layout.office_size(2, 1), "no more columns than projects")
