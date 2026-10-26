import XCTest
@testable import InstructionComplianceKit

final class DirectiveTests: XCTestCase {
    func testSummariesAndFamilies() {
        let cases: [(DirectiveKind, String, DirectiveFamily)] = [
            (.length(.words, .atMost(1)), "at most 1 word", .length),
            (.length(.items, .between(3, 5)), "between 3 and 5 list items", .length),
            (.length(.characters, .around(100)), "about 100 characters", .length),
            (.length(.paragraphs, .exactly(2)), "exactly 2 paragraphs", .length),
            (.length(.sentences, .atLeast(1)), "at least 1 sentence", .length),
            (.list(.numbered), "a numbered list", .list),
            (.noList, "no lists", .list),
            (.include("x"), "use \"x\"", .terms),
            (.exclude("x"), "don't use \"x\"", .terms),
            (.letterCase(.uppercase), "all uppercase", .letterCase),
            (.startsWith(["A", "B"]), "start with \"A\" or \"B\"", .opening),
            (.endsWith(["C"]), "end with \"C\"", .ending),
            (.endsWithQuestion, "end with a question", .ending),
            (.format(.json), "valid JSON", .format),
            (.format(.table), "a table", .format),
            (.format(.plainText), "plain text, no markdown", .format),
            (.noCommas, "no commas", .punctuation)
        ]
        for (kind, summary, family) in cases {
            let directive = Directive(kind: kind)
            XCTAssertEqual(directive.summary, summary)
            XCTAssertEqual(directive.family, family)
            XCTAssertEqual(directive.scope, .turn)
        }
    }

    func testSlots() {
        let slots = [DirectiveKind.length(.words, .atMost(1)), .noList, .exclude("t"), .letterCase(.lowercase),
                     .startsWith(["a"]), .endsWithQuestion, .format(.json), .noCommas].map { Directive(kind: $0).slot }
        XCTAssertEqual(slots, [.length(.words), .list, .term("t"), .letterCase, .opening, .ending, .format, .commas])
    }

    func testBounds() {
        XCTAssertEqual(Bound.around(100).range, 80...120)
        XCTAssertTrue(Bound.atLeast(3).admits(1000))
        XCTAssertFalse(Bound.between(2, 4).admits(5))
        XCTAssertEqual(LengthUnit.items.noun(for: 1), "list item")
        XCTAssertEqual(LengthUnit.allCases.count, 5)
    }
}
