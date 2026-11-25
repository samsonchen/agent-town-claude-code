import simd

/// How many columns the project blocks are laid out in (docs/spec.md: The office window): the
/// count that shows the office largest in the window, so a wide window (maximized, full screen)
/// puts blocks side by side instead of leaving the sides empty.
public enum OfficeColumns {
    /// A new count must show the office at least this much larger than the current one, so a
    /// window near the edge between two counts does not flip back and forth.
    public static let keep: Float = 1.08

    /// The scale (pixels per meter) the office is drawn at: as large as fits the window,
    /// between `minScale` (smaller windows scroll) and `maxScale`.
    /// `office` is its on-screen size at one pixel per meter (depth already foreshortened).
    public static func scale(office: SIMD2<Float>, window: SIMD2<Float>, minScale: Float, maxScale: Float) -> Float {
        let k = min(window.x / max(1, office.x), window.y / max(1, office.y))
        return min(maxScale, max(minScale, k))
    }

    /// The column count for `projects` blocks in `window`: the one that draws the office largest,
    /// fewer columns on a tie, and more than one only when they fit across the window. `current` is
    /// kept while it fits, unless another count is `keep` times larger.
    /// `office(c)` is the office's on-screen size at one pixel per meter with `c` columns.
    public static func best(projects: Int, current: Int, window: SIMD2<Float>, minScale: Float, maxScale: Float,
                            office: (Int) -> SIMD2<Float>) -> Int {
        let most = max(1, projects)
        func k(_ c: Int) -> Float { scale(office: office(c), window: window, minScale: minScale, maxScale: maxScale) }
        // Blocks side by side only when they fit across the window: a narrow one scrolls up and
        // down through one column, never sideways.
        func fits(_ c: Int) -> Bool { c == 1 || office(c).x * k(c) <= window.x + 0.5 }
        var best = 1
        for c in 2...max(2, most) where c <= most && fits(c) && k(c) > k(best) * 1.001 { best = c }
        let now = min(max(1, current), most)
        guard fits(now) else { return best }
        return k(best) > k(now) * keep ? best : now
    }
}
