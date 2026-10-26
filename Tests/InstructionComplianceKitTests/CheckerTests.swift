import XCTest
@testable import InstructionComplianceKit

final class CheckerTests: XCTestCase {
    let checker = ComplianceChecker()

    func result(_ kind: DirectiveKind, _ answer: String) -> DirectiveResult {
        checker.check(answer, against: Directive(kind: kind))
    }

    func testLengthAndLists() {
        XCTAssertEqual(result(.length(.words, .atMost(3)), "one two three four").observed, "4 words")
        XCTAssertEqual(result(.length(.sentences, .exactly(1)), "Just one.").status, .met)
        XCTAssertEqual(result(.length(.words, .atLeast(1)), "x").observed, "1 word")
        XCTAssertEqual(result(.list(.bulleted), "- a").observed, "1 bulleted item")
        XCTAssertEqual(result(.list(.numbered), "1. a\n2. b").observed, "2 numbered items")
        XCTAssertEqual(result(.list(.numbered), "- a").observed, "no numbered items")
        XCTAssertEqual(result(.noList, "prose").observed, "no list items")
        XCTAssertEqual(result(.noList, "- a").observed, "1 list item")
        XCTAssertEqual(result(.noList, "- a\n- b").status, .violated)
    }

    func testTermsCaseAndEdges() {
        XCTAssertEqual(result(.include("price"), "The prices rose.").observed, "uses \"price\"")
        XCTAssertEqual(result(.include("price"), "Costs rose.").observed, "no \"price\"")
        XCTAssertEqual(result(.exclude("very"), "Very good.").observed, "uses \"very\" once")
        XCTAssertEqual(result(.exclude("very"), "very very").observed, "uses \"very\" twice")
        XCTAssertEqual(result(.exclude("very"), "very very very").observed, "uses \"very\" 3 times")
        XCTAssertEqual(result(.exclude("very"), "Good.").observed, "no \"very\"")
        XCTAssertEqual(result(.letterCase(.lowercase), "all small").observed, "all lowercase")
        XCTAssertEqual(result(.letterCase(.lowercase), "Not small").observed, "has capital letters")
        XCTAssertEqual(result(.letterCase(.uppercase), "LOUD").status, .met)
        XCTAssertEqual(result(.letterCase(.uppercase), "Quiet").observed, "has lowercase letters")
        XCTAssertEqual(result(.startsWith(["No", "Yes"]), "Yes, indeed.").status, .met)
        XCTAssertEqual(result(.startsWith(["Yes"]), "This answer begins somewhere else entirely.").observed,
                       "starts \"This answer begins somew…\"")
        XCTAssertEqual(result(.endsWith(["Bye"]), "Short one").observed, "ends \"Short one\"")
        XCTAssertEqual(result(.endsWith(["Bye"]), "This answer ends somewhere else entirely.").observed,
                       "ends \"…somewhere else entirely.\"")
        XCTAssertEqual(result(.endsWithQuestion, "Ready?").observed, "ends with a question")
        XCTAssertEqual(result(.endsWithQuestion, "Done.").observed, "ends with \".\"")
        XCTAssertEqual(result(.endsWithQuestion, "  ").observed, "is empty")
    }

    func testFormatsAndCommas() {
        XCTAssertEqual(result(.format(.json), "{}").observed, "valid JSON")
        XCTAssertEqual(result(.format(.json), "nope").observed, "not valid JSON")
        XCTAssertEqual(result(.format(.table), "|a|\n|---|").observed, "has a table")
        XCTAssertEqual(result(.format(.table), "none").observed, "no table")
        XCTAssertEqual(result(.format(.plainText), "plain").observed, "no markdown")
        XCTAssertEqual(result(.noCommas, "a, b").observed, "1 comma")
        XCTAssertEqual(result(.noCommas, "a, b，c").observed, "2 commas")
        XCTAssertEqual(result(.noCommas, "ab").observed, "no commas")
    }

    func testLooseReadingsSetAsidePreambleAndSignOffOnly() {
        let answer = "Sure! here you go:\nall lowercase body\nCheers!"
        let strict = result(.letterCase(.lowercase), answer)
        XCTAssertEqual(strict.status, .metLoosely)
        XCTAssertEqual(result(.startsWith(["all"]), "Sure:\nall good").status, .metLoosely)
        XCTAssertEqual(result(.length(.items, .atMost(2)), "- a\n- b\n- c").status, .violated,
                       "a list item is content, never a preamble")
        XCTAssertEqual(result(.length(.items, .atMost(2)), "Here:\n- a\n- b").status, .met)
        XCTAssertEqual(result(.format(.plainText), "**bold** text").status, .violated)
        XCTAssertEqual(result(.noList, "* a\n* b").status, .violated)
        XCTAssertEqual(result(.include("key"), "the **key**").status, .met)
        XCTAssertEqual(result(.startsWith(["Note"]), "**Note**: x").status, .metLoosely)
        XCTAssertEqual(ComplianceChecker.looseReadings(of: "a\nb", unstarring: false), ["a\nb", "b", "a"])
        XCTAssertEqual(ComplianceChecker.looseReadings(of: "- a\nb\n- c", unstarring: false), ["- a\nb\n- c"])
    }
}
