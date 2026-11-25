import Testing
@testable import TownCore

@Suite struct OfficeColumnsTests {
    /// Blocks 7 m wide and 6 m deep (path included), an executive strip 2 m deep; as on screen.
    func office(_ projects: Int) -> (Int) -> SIMD2<Float> {
        { c in
            let rows = (projects + c - 1) / c
            return [Float(c) * 8 + 1, 3 + Float(rows) * 6]
        }
    }

    func best(_ projects: Int, current: Int = 1, window: SIMD2<Float>) -> Int {
        OfficeColumns.best(projects: projects, current: current, window: window, minScale: 35, maxScale: 165, office: office(projects))
    }

    @Test func aNarrowWindowKeepsOneColumn() {
        #expect(best(4, window: [500, 900]) == 1)
    }

    @Test func aWideWindowPutsBlocksSideBySide() {
        #expect(best(4, window: [2560, 1400]) == 2)
        #expect(best(6, window: [2560, 1400]) == 3)
    }

    @Test func oneProjectStaysInOneColumn() {
        #expect(best(1, window: [2560, 1400]) == 1)
        #expect(best(0, window: [2560, 1400]) == 1)
    }

    @Test func aTieKeepsFewerColumns() {
        // Both counts reach the largest scale in a huge window: no reason to spread out.
        #expect(best(2, window: [20000, 20000]) == 1)
    }

    @Test func aSmallGainKeepsTheCurrentCount() {
        // 3 projects: one column is 9 by 21, two are 17 by 15. In this window two columns draw
        // the office 5% larger: not enough to switch, nor to switch back.
        let o = office(3)
        func k(_ c: Int, _ w: SIMD2<Float>) -> Float { OfficeColumns.scale(office: o(c), window: w, minScale: 35, maxScale: 165) }
        let close: SIMD2<Float> = [1275, 1500]
        #expect(k(2, close) > k(1, close) && k(2, close) < k(1, close) * OfficeColumns.keep)
        #expect(best(3, current: 1, window: close) == 1)
        #expect(best(3, current: 2, window: close) == 2)
    }

    @Test func aNarrowedWindowGoesBackToOneColumn() {
        // Made narrow after being wide: two columns would need sideways scrolling.
        #expect(best(6, current: 2, window: [420, 900]) == 1)
        #expect(best(6, current: 3, window: [420, 900]) == 1)
    }

    @Test func aCountPastTheProjectsIsClamped() {
        #expect(best(2, current: 5, window: [500, 900]) <= 2)
    }

    @Test func theScaleStaysInItsRange() {
        #expect(OfficeColumns.scale(office: [10, 10], window: [100, 100], minScale: 35, maxScale: 165) == 35)
        #expect(OfficeColumns.scale(office: [10, 10], window: [5000, 5000], minScale: 35, maxScale: 165) == 165)
        #expect(OfficeColumns.scale(office: [10, 10], window: [800, 600], minScale: 35, maxScale: 165) == 60)
    }
}
