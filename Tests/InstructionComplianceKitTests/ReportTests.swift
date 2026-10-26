import XCTest
@testable import InstructionComplianceKit

final class ReportTests: XCTestCase {
    let checker = ComplianceChecker()

    func testVerdictsAndAccuracy() {
        let empty = checker.report(answer: "x", directives: [])
        XCTAssertEqual(empty.verdict, .noDirectives)
        XCTAssertNil(empty.strictAccuracy)
        XCTAssertNil(empty.looseAccuracy)
        XCTAssertNil(empty.note)
        XCTAssertNil(empty.feedback)

        let loose = checker.report(answer: "Sure:\nyes", directives: [Directive(kind: .letterCase(.lowercase))])
        XCTAssertEqual(loose.verdict, .compliantLoosely)
        XCTAssertEqual(loose.strictAccuracy, 0)
        XCTAssertEqual(loose.looseAccuracy, 1)
        XCTAssertNil(loose.note)

        let met = checker.report(answer: "yes", directives: [Directive(kind: .letterCase(.lowercase))])
        XCTAssertEqual(met.verdict, .compliant)
    }

    func testNoteAndFeedback() {
        let one = checker.report(answer: "Delve.", directives: [Directive(kind: .exclude("delve"))])
        XCTAssertEqual(one.verdict, .violated)
        XCTAssertEqual(one.note, "This answer doesn't follow the one instruction in your request: don't use \"delve\" "
                       + "(uses \"delve\" once).")
        XCTAssertEqual(one.feedback, """
            The answer above breaks these instructions from the user's request:
            - don't use "delve" (the answer: uses "delve" once)
            Rewrite it so it follows every one of them. Keep everything else the same.
            """)

        let directives = [Directive(kind: .length(.sentences, .atMost(1))), Directive(kind: .length(.sentences, .atLeast(3))),
                          Directive(kind: .noCommas)]
        let report = checker.report(answer: "One. Two.", directives: directives)
        XCTAssertEqual(report.conflicts.count, 1)
        XCTAssertEqual(report.violated.count, 2)
        XCTAssertEqual(report.note, "This answer doesn't follow 2 of the 3 instructions in your request: "
                       + "at most 1 sentence (2 sentences); at least 3 sentences (2 sentences). "
                       + "Some of those instructions conflict, so no answer could follow them all.")
    }
}
