import XCTest
@testable import InstructionComplianceKit

final class ConflictTests: XCTestCase {
    func reasons(_ kinds: [DirectiveKind]) -> [String] {
        ConflictDetector().conflicts(in: kinds.map { Directive(kind: $0) }).map(\.reason)
    }

    func testLengths() {
        XCTAssertEqual(reasons([.length(.words, .atMost(50)), .length(.words, .atLeast(100))]),
                       ["no length is both at most 50 words and at least 100 words"])
        XCTAssertEqual(reasons([.length(.words, .atMost(50)), .length(.words, .atLeast(10))]), [])
        XCTAssertEqual(reasons([.length(.sentences, .atMost(2)), .length(.paragraphs, .atLeast(3))]),
                       ["at least 3 paragraphs need at least 3 sentences, more than at most 2 sentences allows"])
        XCTAssertEqual(reasons([.length(.items, .exactly(5)), .length(.words, .atMost(4))]).count, 1)
        XCTAssertEqual(reasons([.length(.items, .exactly(5)), .length(.words, .atMost(40))]), [])
        XCTAssertEqual(reasons([.length(.items, .exactly(5)), .length(.paragraphs, .atMost(1))]), [])
    }

    func testShapes() {
        XCTAssertEqual(reasons([.letterCase(.uppercase), .letterCase(.lowercase)]),
                       ["an answer cannot be all lowercase and all uppercase"])
        XCTAssertEqual(reasons([.noList, .list(.numbered)]), ["a list was asked for and lists were ruled out"])
        XCTAssertEqual(reasons([.list(.numbered), .list(.bulleted)]), ["a list cannot be bulleted and numbered at once"])
        XCTAssertEqual(reasons([.length(.items, .atLeast(2)), .noList]), ["list items were asked for and lists were ruled out"])
        XCTAssertEqual(reasons([.length(.items, .atMost(2)), .noList]), [])
    }

    func testTermsAndText() {
        XCTAssertEqual(reasons([.include("latency"), .exclude("latency")]), ["\"latency\" is both required and ruled out"])
        XCTAssertEqual(reasons([.include("low latency"), .exclude("latency")]),
                       ["\"low latency\" has to appear and contains \"latency\", which must not"])
        XCTAssertEqual(reasons([.include("cost"), .exclude("price")]), [])
        XCTAssertEqual(reasons([.startsWith(["Dear team"]), .exclude("team")]),
                       ["the required text contains \"team\", which must not appear"])
        XCTAssertEqual(reasons([.endsWith(["Bye", "Thanks team"]), .exclude("team")]), [])
        XCTAssertEqual(reasons([.endsWith(["Bye"]), .endsWithQuestion]), ["the required ending is not a question"])
        XCTAssertEqual(reasons([.endsWith(["Ok?"]), .endsWithQuestion]), [])
        XCTAssertEqual(reasons([.noCommas, .include("a, b")]), ["\"a, b\" has a comma"])
        XCTAssertEqual(reasons([.noCommas, .include("ab")]), [])
    }

    func testFormats() {
        XCTAssertEqual(reasons([.format(.table), .format(.json)]), ["a markdown table cannot be valid JSON"])
        XCTAssertEqual(reasons([.format(.plainText), .format(.table)]), ["a markdown table cannot be plain text"])
        XCTAssertEqual(reasons([.format(.json), .list(.bulleted)]), ["valid JSON cannot be a markdown list"])
        XCTAssertEqual(reasons([.endsWithQuestion, .format(.json)]), ["valid JSON cannot end with a question"])
        XCTAssertEqual(reasons([.format(.json), .startsWith(["Here"])]), ["valid JSON starts with { or ["])
        XCTAssertEqual(reasons([.format(.json), .startsWith(["{\"a\""])]), [])
        XCTAssertEqual(reasons([.format(.json), .noCommas]), [])
    }
}
