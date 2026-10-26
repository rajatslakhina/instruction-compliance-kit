import XCTest
@testable import InstructionComplianceKit

func kinds(_ request: String) -> [DirectiveKind] {
    DirectiveReader().read(request).directives.map(\.kind)
}

final class ReaderLengthTests: XCTestCase {
    func testBoundsWrittenBeforeTheNumber() {
        XCTAssertEqual(kinds("Answer in at most 50 words."), [.length(.words, .atMost(50))])
        XCTAssertEqual(kinds("Use at least 200 words."), [.length(.words, .atLeast(200))])
        XCTAssertEqual(kinds("Write exactly 4 sentences."), [.length(.sentences, .exactly(4))])
        XCTAssertEqual(kinds("Keep it within 280 characters."), [.length(.characters, .atMost(280))])
        XCTAssertEqual(kinds("Write a minimum 300 words."), [.length(.words, .atLeast(300))])
        XCTAssertEqual(kinds("Write about 100 words."), [.length(.words, .around(100))])
        XCTAssertEqual(kinds("Answer in under 120 words."), [.length(.words, .atMost(119))])
        XCTAssertEqual(kinds("Use over 100 words."), [.length(.words, .atLeast(101))])
        XCTAssertEqual(kinds("Don't go under 50 words."), [.length(.words, .atLeast(50))])
        XCTAssertEqual(kinds("Do not exceed 100 words."), [.length(.words, .atMost(100))])
        XCTAssertEqual(kinds("Make sure it exceeds 500 words."), [.length(.words, .atLeast(501))])
        XCTAssertEqual(kinds("Up to 3 paragraphs."), [.length(.paragraphs, .atMost(3))])
        XCTAssertEqual(kinds("Keep it to 2 sentences."), [.length(.sentences, .atMost(2))])
        XCTAssertEqual(kinds("Give a maximum of 3 paragraphs."), [.length(.paragraphs, .atMost(3))])
        XCTAssertEqual(kinds("Give a minimum of 3 paragraphs."), [.length(.paragraphs, .atLeast(3))])
    }

    func testComparativesAndTheirNegations() {
        XCTAssertEqual(kinds("Use more than 100 words."), [.length(.words, .atLeast(101))])
        XCTAssertEqual(kinds("No more than two paragraphs."), [.length(.paragraphs, .atMost(2))])
        XCTAssertEqual(kinds("Not longer than 80 words."), [.length(.words, .atMost(80))])
        XCTAssertEqual(kinds("Fewer than 5 sentences."), [.length(.sentences, .atMost(4))])
        XCTAssertEqual(kinds("No fewer than 5 sentences."), [.length(.sentences, .atLeast(5))])
        XCTAssertEqual(kinds("Don't make it more than 100 words."), [.length(.words, .atMost(100))])
        XCTAssertEqual(kinds("Less than 1 word."), [.length(.words, .atMost(0))])
        XCTAssertEqual(kinds("Use fewer than 0 words."), [.length(.words, .atMost(0))])
        XCTAssertEqual(kinds("Bigger than 100 words."), [.length(.words, .atMost(100))], "unknown comparative: default")
    }

    func testBoundsWrittenAfterTheUnit() {
        XCTAssertEqual(kinds("100 words or less."), [.length(.words, .atMost(100))])
        XCTAssertEqual(kinds("300 words or more."), [.length(.words, .atLeast(300))])
        XCTAssertEqual(kinds("3 paragraphs at most."), [.length(.paragraphs, .atMost(3))])
        XCTAssertEqual(kinds("3 paragraphs at least."), [.length(.paragraphs, .atLeast(3))])
        XCTAssertEqual(kinds("A 100-word limit."), [.length(.words, .atMost(100))])
        XCTAssertEqual(kinds("300 words minimum."), [.length(.words, .atLeast(300))])
        XCTAssertEqual(kinds("5 paragraphs or so."), [.length(.paragraphs, .exactly(5))], "'or so' is no bound")
    }

    func testRangesAndDefaults() {
        XCTAssertEqual(kinds("Use 3 to 5 bullet points."), [.length(.items, .between(3, 5)), .list(.bulleted)])
        XCTAssertEqual(kinds("In 2 or 3 sentences."), [.length(.sentences, .between(2, 3))])
        XCTAssertEqual(kinds("Between 50 and 100 words."), [.length(.words, .between(50, 100))])
        XCTAssertEqual(kinds("Write 100-50 words."), [.length(.words, .between(50, 100))])
        XCTAssertEqual(kinds("Write 5 and 6 words."), [.length(.words, .atMost(6))], "'and' alone is no range")
        XCTAssertEqual(kinds("In one sentence."), [.length(.sentences, .exactly(1))])
        XCTAssertEqual(kinds("In a sentence."), [.length(.sentences, .exactly(1))])
        XCTAssertEqual(kinds("A one-word answer."), [.length(.words, .atMost(1))])
        XCTAssertEqual(kinds("In twenty five words."), [.length(.words, .atMost(25))])
        XCTAssertEqual(kinds("In two hundred words."), [.length(.words, .atMost(200))])
        XCTAssertEqual(kinds("Use 3 short paragraphs."), [.length(.paragraphs, .exactly(3))])
        XCTAssertEqual(kinds("A word."), [], "'a' only means one inside 'in a sentence'")
        XCTAssertEqual(kinds("Paragraphs please."), [])
        XCTAssertEqual(kinds("Bullet points"), [.list(.bulleted)])
    }

    func testItemNounsNeedAListCue() {
        XCTAssertEqual(kinds("A numbered list of 5 items."), [.length(.items, .exactly(5)), .list(.numbered)])
        XCTAssertEqual(kinds("Give 4 bulleted items."), [.length(.items, .exactly(4)), .list(.bulleted)])
        XCTAssertEqual(kinds("Make 3 points."), [])
    }

    func testCountsThatDescribeTheMaterialOrEachPart() {
        XCTAssertEqual(kinds("Rewrite this 500-word email in 3 sentences."), [.length(.sentences, .exactly(3))])
        XCTAssertEqual(kinds("The draft is 900 words long; cut it."), [])
        XCTAssertEqual(kinds("Give me 2 paragraphs, each under 60 words."), [.length(.paragraphs, .exactly(2))])
        XCTAssertEqual(kinds("Max 10 words per bullet."), [.list(.bulleted)])
        XCTAssertEqual(kinds("Keep each answer under 40 words."), [.length(.words, .atMost(39))])
        XCTAssertEqual(kinds("Summarize these 3-5 paragraphs."), [])
    }
}
