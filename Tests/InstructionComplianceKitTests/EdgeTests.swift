import XCTest
@testable import InstructionComplianceKit

/// Clause edges: a cue word with nothing before or after it.
final class EdgeTests: XCTestCase {
    func testCuesAtTheEdgeOfAClause() {
        XCTAssertEqual(kinds("In a paragraph."), [.length(.paragraphs, .exactly(1))])
        XCTAssertEqual(kinds("A sentence."), [])
        XCTAssertEqual(kinds("Write 10 words each."), [])
        XCTAssertEqual(kinds("Of 5 sentences."), [.length(.sentences, .exactly(5))])
        XCTAssertEqual(kinds("Please, keep it to 3 sentences."), [.length(.sentences, .atMost(3))])
        XCTAssertEqual(kinds("Prose please."), [])
        XCTAssertEqual(kinds("Go to 5 paragraphs."), [.length(.paragraphs, .exactly(5))])
    }

    func testMeasuresAtTheEdge() {
        XCTAssertEqual(TextMeasure.count(.paragraphs, in: "42"), 1)
        XCTAssertEqual(RequestScanner.clauses(in: "dogs' bowls").flatMap(\.tokens), [.word("dogs"), .word("bowls")])
    }
}
