import XCTest
@testable import InstructionComplianceKit

final class MeasureTests: XCTestCase {
    func testWords() {
        XCTAssertEqual(TextMeasure.count(.words, in: "Don't stop—well-known 3.5 rock 'n' roll -x x-"), 10)
        XCTAssertEqual(TextMeasure.count(.words, in: "1. First item\n- second\n# Title"), 4)
        XCTAssertEqual(TextMeasure.count(.words, in: ""), 0)
    }

    func testSentences() {
        XCTAssertEqual(TextMeasure.count(.sentences, in: "One. Two! Three?! Four"), 4)
        XCTAssertEqual(TextMeasure.count(.sentences, in: "See e.g. Dr. Smith and J. Doe. Pi is 3.14 today."), 2)
        XCTAssertEqual(TextMeasure.count(.sentences, in: "He said \"no.\" Then left."), 2)
        XCTAssertEqual(TextMeasure.count(.sentences, in: "# Heading\n\n---\n|---|---|\n- item one\n- item two."), 2)
        XCTAssertEqual(TextMeasure.count(.sentences, in: "Plan B.\n... !"), 1)
    }

    func testParagraphs() {
        XCTAssertEqual(TextMeasure.count(.paragraphs, in: "# Title\n\nFirst para.\nStill first.\n\n***\nSecond.\n\n\n"), 2)
        XCTAssertEqual(TextMeasure.count(.paragraphs, in: "  \n---\n"), 0)
    }

    func testListItems() {
        let text = "- a\n* b\n• c\n+ d\n  1. e\n2) f\n2026. g\n* * *\n-x\n1.x\n10.\n**bold**"
        XCTAssertEqual(TextMeasure.items(.bulleted, in: text), 4)
        XCTAssertEqual(TextMeasure.items(.numbered, in: text), 2)
        XCTAssertEqual(TextMeasure.count(.items, in: text), 6)
        XCTAssertNil(TextMeasure.listStyle(of: ""))
        XCTAssertEqual(TextMeasure.withoutMarker("plain"), "plain")
    }

    func testCharactersTablesJSONAndMarkdown() {
        XCTAssertEqual(TextMeasure.count(.characters, in: "héllo"), 5)
        XCTAssertTrue(TextMeasure.hasTable("| a | b |\n|:---|---:|\n| 1 | 2 |"))
        XCTAssertFalse(TextMeasure.hasTable("|---|"))
        XCTAssertFalse(TextMeasure.hasTable("a | b\nc | d"))
        XCTAssertTrue(TextMeasure.isJSON("{\"a\": 1}"))
        XCTAssertTrue(TextMeasure.isJSON("```json\n[1, 2]\n```"))
        XCTAssertTrue(TextMeasure.isJSON("```\n{}\n```"))
        XCTAssertFalse(TextMeasure.isJSON("```json```"))
        XCTAssertFalse(TextMeasure.isJSON("42"))
        XCTAssertFalse(TextMeasure.isJSON("{a: 1}"))
        XCTAssertEqual(TextMeasure.markdown(in: "## H\n**b** __u__\n```x```\n|a|b|\n|---|---|\n[l](u)"),
                       ["heading", "bold", "code fence", "table", "link"])
        XCTAssertEqual(TextMeasure.markdown(in: "#hashtag and plain words"), [])
        XCTAssertFalse(TextMeasure.isHeading("####### seven"))
    }

    func testLastSignificantCharacter() {
        XCTAssertEqual(TextMeasure.lastSignificant("Ready? **"), "?")
        XCTAssertEqual(TextMeasure.lastSignificant("(see \"this\")"), "s")
        XCTAssertNil(TextMeasure.lastSignificant(" \" "))
    }

    func testWholeWordMatching() {
        XCTAssertEqual(TextMatch.count(of: "price", in: "Prices, price's and the PRICE; not priceless or overprice."), 3)
        XCTAssertEqual(TextMatch.count(of: "box", in: "boxes box"), 2)
        XCTAssertEqual(TextMatch.count(of: "", in: "anything"), 0)
        XCTAssertEqual(TextMatch.count(of: "don't", in: "I don’t know"), 1)
        XCTAssertTrue(TextMatch.ends("Thanks for reading. Cheers!", with: "cheers"))
        XCTAssertTrue(TextMatch.ends("Done. Any questions?", with: "Any questions?"))
        XCTAssertFalse(TextMatch.ends("Done. Any questions", with: "Any questions?"))
        XCTAssertFalse(TextMatch.ends("Cheers mate", with: "cheers"))
        XCTAssertTrue(TextMatch.starts("  YES, it works", with: "yes"))
        XCTAssertFalse(TextMatch.starts("Well, yes", with: "yes"))
    }
}
