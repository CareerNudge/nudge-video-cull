//
//  LUTAutoMapperTests.swift
//  VideoCullingApp Tests
//

import XCTest
@testable import VideoCullingApp

class LUTAutoMapperTests: XCTestCase {

    var availableLUTs: [LUT] = []

    override func setUp() {
        super.setUp()

        // Create test LUTs
        availableLUTs = [
            LUT(id: UUID(), name: "[Default] SGamut3CineSLog3_To_LC-709", fileName: "SGamut3CineSLog3_To_LC-709.cube"),
            LUT(id: UUID(), name: "[Default] SLog2SGumut_To_LC-709_", fileName: "From_SLog2SGumut_To_LC-709_.cube"),
            LUT(id: UUID(), name: "[Default] AppleLogToRec709", fileName: "AppleLogToRec709.cube")
        ]
    }

    // MARK: - Normalization Tests

    func testNormalizationRemovesHyphens() {
        let result = LUTAutoMapper.normalizeForMatching("s-log3-cine")
        XCTAssertEqual(result, "slog3cine", "Should remove hyphens")
    }

    func testNormalizationRemovesDots() {
        let result = LUTAutoMapper.normalizeForMatching("s.log3.cine")
        XCTAssertEqual(result, "slog3cine", "Should remove dots")
    }

    func testNormalizationRemovesSpaces() {
        let result = LUTAutoMapper.normalizeForMatching("s log3 cine")
        XCTAssertEqual(result, "slog3cine", "Should remove spaces")
    }

    func testNormalizationCombined() {
        let result = LUTAutoMapper.normalizeForMatching("s-log3.cine ")
        XCTAssertEqual(result, "slog3cine", "Should handle mixed separators")
    }

    // MARK: - LUT Matching Tests

    func testSLog3SGamut3CineMatching() {
        let lut = LUTAutoMapper.findBestLUT(
            gamma: "S-Log3",
            colorSpace: "S-Gamut3.Cine",
            availableLUTs: availableLUTs
        )

        XCTAssertNotNil(lut, "Should find matching LUT for S-Log3/S-Gamut3.Cine")
        XCTAssertTrue(lut?.fileName.contains("SGamut3Cine") ?? false, "Should match S-Gamut3.Cine LUT")
    }

    func testSLog2SGamutMatching() {
        let lut = LUTAutoMapper.findBestLUT(
            gamma: "S-Log2",
            colorSpace: "S-Gamut",
            availableLUTs: availableLUTs
        )

        XCTAssertNotNil(lut, "Should find matching LUT for S-Log2/S-Gamut")
        XCTAssertTrue(lut?.fileName.contains("SLog2") ?? false, "Should match S-Log2 LUT")
    }

    func testAppleLogMatching() {
        let lut = LUTAutoMapper.findBestLUT(
            gamma: "Apple Log",
            colorSpace: "Rec.709",
            availableLUTs: availableLUTs
        )

        XCTAssertNotNil(lut, "Should find matching LUT for Apple Log")
        XCTAssertTrue(lut?.fileName.contains("AppleLog") ?? false, "Should match Apple Log LUT")
    }

    func testNoMatchForUnknownProfile() {
        let lut = LUTAutoMapper.findBestLUT(
            gamma: "Unknown-Gamma",
            colorSpace: "Unknown-ColorSpace",
            availableLUTs: availableLUTs
        )

        XCTAssertNil(lut, "Should return nil for unknown camera profile")
    }

    func testNilGammaReturnsNil() {
        let lut = LUTAutoMapper.findBestLUT(
            gamma: nil,
            colorSpace: "S-Gamut3.Cine",
            availableLUTs: availableLUTs
        )

        XCTAssertNil(lut, "Should return nil when gamma is nil")
    }

    func testNilColorSpaceReturnsNil() {
        let lut = LUTAutoMapper.findBestLUT(
            gamma: "S-Log3",
            colorSpace: nil,
            availableLUTs: availableLUTs
        )

        XCTAssertNil(lut, "Should return nil when colorSpace is nil")
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitiveMatching() {
        let lut1 = LUTAutoMapper.findBestLUT(
            gamma: "s-log3",
            colorSpace: "s-gamut3.cine",
            availableLUTs: availableLUTs
        )

        let lut2 = LUTAutoMapper.findBestLUT(
            gamma: "S-LOG3",
            colorSpace: "S-GAMUT3.CINE",
            availableLUTs: availableLUTs
        )

        XCTAssertNotNil(lut1, "Should match lowercase")
        XCTAssertNotNil(lut2, "Should match uppercase")
        XCTAssertEqual(lut1?.id, lut2?.id, "Should match same LUT regardless of case")
    }

    // MARK: - Performance Tests

    func testPerformanceOfNormalization() {
        measure {
            for _ in 0..<1000 {
                _ = LUTAutoMapper.normalizeForMatching("S-Log3.Gamut3.Cine")
            }
        }
    }

    func testPerformanceOfLUTMatching() {
        measure {
            for _ in 0..<100 {
                _ = LUTAutoMapper.findBestLUT(
                    gamma: "S-Log3",
                    colorSpace: "S-Gamut3.Cine",
                    availableLUTs: availableLUTs
                )
            }
        }
    }
}
