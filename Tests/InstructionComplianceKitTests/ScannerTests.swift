import XCTest
@testable import InstructionComplianceKit

final class ScannerTests: XCTestCase {
    func tokens(_ text: String) -> [RequestToken] {
        RequestScanner.clauses(in: text).flatMap(\.tokens)
    }

    func testClausesBreakOutsideQuotesOnly() {
        let clauses = RequestScanner.clauses(in: "End with \"Any questions?\" Then stop! Pi is 3.14; ok\nnext")
        XCTAssertEqual(clauses.map(\.text), ["End with \"Any questions?\" Then stop!", "Pi is 3.14;", "ok", "next"])
        XCTAssertEqual(RequestScanner.clauses(in: "...  "), [])
    }

    func testQuotes() {
        XCTAssertEqual(tokens("say \"a b\" ‘c’ “d”"), [.word("say"), .quote("a b"), .quote("c"), .quote("d")])
        XCTAssertEqual(tokens("use 'x' don't"), [.word("use"), .quote("x"), .word("don't")])
        XCTAssertEqual(tokens("it's 'open"), [.word("it's"), .word("open")], "an unclosed quote is ignored")
        XCTAssertEqual(tokens("\"a\nb\""), [.word("a"), .word("b")], "a quote does not cross a line")
        XCTAssertEqual(tokens("say \"\" now"), [.word("say"), .word("now")])
        XCTAssertEqual(tokens("'rock'n'roll' x"), [.quote("rock'n'roll"), .word("x")])
    }

    func testWordsNumbersRangesAndMarks() {
        XCTAssertEqual(tokens("Don’t (1,000 words): 50-100, 3–5"),
                       [.word("don't"), .mark, .number(1000), .word("words"), .mark, .mark, .range(50, 100), .mark,
                        .range(3, 5)])
        XCTAssertEqual(tokens("12,34 7-word 100k"), [.number(12), .mark, .number(34), .number(7), .word("word"),
                                                       .word("100k")])
        XCTAssertEqual(tokens("99999999999999999999999 words"), [.word("99999999999999999999999"), .word("words")])
        XCTAssertEqual(tokens("ninety nine hundred two"), [.number(99), .number(100), .number(2)])
        XCTAssertEqual(tokens("five hundred"), [.number(500)])
        XCTAssertEqual(tokens("20,000"), [.number(20000)])
        XCTAssertEqual(tokens("1,0001"), [.number(1), .mark, .number(1)])
        XCTAssertEqual(tokens("5-99999999999999999999999"), [.number(5), .word("99999999999999999999999")])
    }

    func testTokenAccessors() {
        XCTAssertNil(RequestToken.mark.word)
        XCTAssertNil(RequestToken.word("x").number)
        XCTAssertEqual(RequestToken.number(3).number, 3)
        XCTAssertFalse([RequestToken.word("a")].containsSequence(["a", "b"]))
        XCTAssertFalse([RequestToken.quote("x"), .word("no")].hasNegator(before: 0))
        XCTAssertTrue([RequestToken.word("no"), .quote("x"), .word("y")].hasNegator(before: 2))
    }
}
