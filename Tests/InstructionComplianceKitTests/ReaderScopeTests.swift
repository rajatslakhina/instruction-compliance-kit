import XCTest
@testable import InstructionComplianceKit

final class ReaderScopeTests: XCTestCase {
    func testStandingAndTurnScopes() {
        let reading = DirectiveReader().read("From now on, answer in lowercase. This time use bullets.")
        XCTAssertEqual(reading.directives.map(\.scope), [.standing, .turn])
        XCTAssertEqual(reading.directives.map(\.phrase), ["From now on, answer in lowercase.", "This time use bullets."])
        XCTAssertEqual(DirectiveReader().read("Always end with a question.").directives.first?.scope, .standing)
        XCTAssertEqual(DirectiveReader().read("Keep every answer short and use bullets.").directives.first?.scope,
                       .standing)
    }

    func testReleases() {
        let reader = DirectiveReader()
        XCTAssertEqual(reader.read("Forget the word limit.").released, [.length])
        XCTAssertEqual(reader.read("You no longer need bullets.").released, [.list])
        XCTAssertEqual(reader.read("No need for lowercase anymore.").released, [.letterCase])
        XCTAssertEqual(reader.read("Ignore my formatting rules.").released, Set(DirectiveFamily.allCases))
        XCTAssertEqual(reader.read("Drop the commas rule and the markdown one.").released, [.punctuation, .format])
        XCTAssertEqual(reader.read("Ignore the noise.").released, [])
        XCTAssertEqual(reader.read("Remove the word 'very'.").directives.map(\.kind), [.exclude("very")])
        let mixed = reader.read("Ignore the bullet point rule. Use 2 paragraphs.")
        XCTAssertEqual(mixed.released, [.list])
        XCTAssertEqual(mixed.directives.map(\.kind), [.length(.paragraphs, .exactly(2))])
    }

    func testDuplicatesAreReadOnce() {
        XCTAssertEqual(kinds("Use bullets. Use bullet points. Use \"x\" and the word \"x\"."),
                       [.list(.bulleted), .include("x")])
    }
}
