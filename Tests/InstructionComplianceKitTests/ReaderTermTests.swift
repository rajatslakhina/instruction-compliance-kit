import XCTest
@testable import InstructionComplianceKit

final class ReaderTermTests: XCTestCase {
    func testQuotedOpeningsAndClosings() {
        XCTAssertEqual(kinds("Start your answer with \"Yes\"."), [.startsWith(["Yes"])])
        XCTAssertEqual(kinds("Begin with 'Yes' or 'No'."), [.startsWith(["Yes", "No"])])
        XCTAssertEqual(kinds("Sign off with “Cheers” or “Thanks”."), [.endsWith(["Cheers", "Thanks"])])
        XCTAssertEqual(kinds("Open with \"Hi\" and \"Hello\"."), [.startsWith(["Hi"]), .startsWith(["Hello"])])
        XCTAssertEqual(kinds("End with \"Bye\", or use \"later\"."), [.endsWith(["Bye"]), .include("later")])
    }

    func testQuotedTermsToUseOrAvoid() {
        XCTAssertEqual(kinds("Use the word \"Synergy\"."), [.include("synergy")])
        XCTAssertEqual(kinds("Mention 'A', and avoid 'B' and 'C'."), [.include("a"), .exclude("b"), .exclude("c")])
        XCTAssertEqual(kinds("Never use the phrase \"circle back\"."), [.exclude("circle back")])
        XCTAssertEqual(kinds("Without the word ‘delve’."), [.exclude("delve")])
        XCTAssertEqual(kinds("Don't mention \"Acme\"."), [.exclude("acme")])
        XCTAssertEqual(kinds("Translate 'Good morning' into French."), [])
        XCTAssertEqual(kinds("What does \"idempotent\" mean in this context for us here?"), [])
    }

    func testUnquotedTermsToAvoid() {
        XCTAssertEqual(kinds("Don't mention the vendor names."), [.exclude("vendor names")])
        XCTAssertEqual(kinds("Do not mention competitors or pricing in the answer."),
                       [.exclude("competitors"), .exclude("pricing")])
        XCTAssertEqual(kinds("No mention of the budget at all."), [.exclude("budget")])
        XCTAssertEqual(kinds("Never discuss our quarterly revenue numbers again."), [.exclude("quarterly revenue numbers")])
        XCTAssertEqual(kinds("Don't mention it."), [.exclude("it")])
        XCTAssertEqual(kinds("Mention the price somewhere."), [])
        XCTAssertEqual(kinds("Use the word synergy."), [.include("synergy")])
        XCTAssertEqual(kinds("Avoid the word very, please."), [.exclude("very")])
        XCTAssertEqual(kinds("Watch the word count."), [])
        XCTAssertEqual(kinds("Use the word count tool."), [])
        XCTAssertEqual(kinds("Start with the word hello."), [])
        XCTAssertEqual(kinds("Don't mention, ever."), [])
    }
}
