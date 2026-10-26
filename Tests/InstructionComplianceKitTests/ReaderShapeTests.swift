import XCTest
@testable import InstructionComplianceKit

final class ReaderShapeTests: XCTestCase {
    func testListStyles() {
        XCTAssertEqual(kinds("Use bullet points."), [.list(.bulleted)])
        XCTAssertEqual(kinds("As a numbered list."), [.list(.numbered)])
        XCTAssertEqual(kinds("Bulleted, then numbered."), [.list(.bulleted), .list(.numbered)])
        XCTAssertEqual(kinds("No bullet points."), [.noList])
        XCTAssertEqual(kinds("Please don't use lists."), [.noList])
        XCTAssertEqual(kinds("Write it in prose."), [.noList])
        XCTAssertEqual(kinds("Don't use a numbered list, use bullets."), [.list(.bulleted)])
        XCTAssertEqual(kinds("No commas, bullet points please."), [.list(.bulleted), .noCommas])
        XCTAssertEqual(kinds("List three reasons."), [])
        XCTAssertEqual(kinds("Some prose."), [])
    }

    func testLetterCase() {
        XCTAssertEqual(kinds("Answer in all lowercase."), [.letterCase(.lowercase)])
        XCTAssertEqual(kinds("Use lower case."), [.letterCase(.lowercase)])
        XCTAssertEqual(kinds("Not lowercased, not lower case."), [])
        XCTAssertEqual(kinds("Reply in UPPERCASE."), [.letterCase(.uppercase)])
        XCTAssertEqual(kinds("Upper case only."), [.letterCase(.uppercase)])
        XCTAssertEqual(kinds("Don't use uppercase."), [.letterCase(.lowercase)])
        XCTAssertEqual(kinds("No upper case."), [.letterCase(.lowercase)])
        XCTAssertEqual(kinds("In all caps."), [.letterCase(.uppercase)])
        XCTAssertEqual(kinds("No caps at all."), [.letterCase(.lowercase)])
        XCTAssertEqual(kinds("Caps lock is broken."), [])
        XCTAssertEqual(kinds("Write in all capital letters."), [.letterCase(.uppercase)])
        XCTAssertEqual(kinds("Don't use a capital letter."), [.letterCase(.lowercase)])
        XCTAssertEqual(kinds("Start each sentence with a capital letter."), [])
        XCTAssertEqual(kinds("Upper bound."), [])
    }

    func testFormats() {
        XCTAssertEqual(kinds("Return JSON."), [.format(.json)])
        XCTAssertEqual(kinds("Not JSON."), [])
        XCTAssertEqual(kinds("In tabular form."), [.format(.table)])
        XCTAssertEqual(kinds("Not tabular."), [])
        XCTAssertEqual(kinds("Put it in a table."), [.format(.table)])
        XCTAssertEqual(kinds("Use table format."), [.format(.table)])
        XCTAssertEqual(kinds("Don't use a table."), [])
        XCTAssertEqual(kinds("Add a table of contents."), [])
        XCTAssertEqual(kinds("Sit at the table."), [])
        XCTAssertEqual(kinds("Plain text only."), [.format(.plainText)])
        XCTAssertEqual(kinds("Not plain text."), [])
        XCTAssertEqual(kinds("No markdown."), [.format(.plainText)])
        XCTAssertEqual(kinds("Without formatting."), [.format(.plainText)])
        XCTAssertEqual(kinds("Markdown is fine."), [])
        XCTAssertEqual(kinds("Don't use any commas."), [.noCommas])
        XCTAssertEqual(kinds("Commas are fine."), [])
        XCTAssertEqual(kinds("No markdown, no formatting."), [.format(.plainText)])
    }

    func testEndingWithAQuestion() {
        XCTAssertEqual(kinds("End with a question."), [.endsWithQuestion])
        XCTAssertEqual(kinds("Finish by asking a follow-up question."), [.endsWithQuestion])
        XCTAssertEqual(kinds("Ask me a question at the end."), [.endsWithQuestion])
        XCTAssertEqual(kinds("End with \"Any questions?\""), [.endsWith(["Any questions?"])])
        XCTAssertEqual(kinds("At the end, list sources."), [])
        XCTAssertEqual(kinds("Close the door."), [])
    }
}
