import XCTest
@testable import SleepRecord

final class PDFLayoutBuilderTests: XCTestCase {
    func testSinglePage_30Days() {
        XCTAssertEqual(PDFExporter.pages(totalDays: 30), 1)
    }

    func testSinglePage_35Days() {
        XCTAssertEqual(PDFExporter.pages(totalDays: 35), 1)
    }

    func testTwoPages_36Days() {
        XCTAssertEqual(PDFExporter.pages(totalDays: 36), 2)
    }

    func testThreePages_71Days() {
        XCTAssertEqual(PDFExporter.pages(totalDays: 71), 3)
    }

    func testZeroDays_AtLeastOnePage() {
        XCTAssertEqual(PDFExporter.pages(totalDays: 0), 1)
    }
}
