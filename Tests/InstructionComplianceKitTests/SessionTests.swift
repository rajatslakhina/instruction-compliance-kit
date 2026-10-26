import XCTest
@testable import InstructionComplianceKit

final class SessionTests: XCTestCase {
    func testStandingInstructionsCarryUntilReplacedOrLifted() async {
        let session = ComplianceSession()
        let first = await session.begin(request: "From now on, answer in lowercase and under 40 words.")
        XCTAssertEqual(first.turn, 1)
        XCTAssertEqual(first.carried, [])
        let standing = await session.standing
        XCTAssertEqual(standing.count, 2)

        let second = await session.begin(request: "What is a mutex?")
        XCTAssertEqual(second.carried.map(\.kind), [.length(.words, .atMost(39)), .letterCase(.lowercase)])
        let report = await session.review(answer: "A lock.")
        XCTAssertEqual(report.verdict, .violated)

        let third = await session.begin(request: "In all caps this time.")
        XCTAssertEqual(third.directives.map(\.kind), [.letterCase(.uppercase), .length(.words, .atMost(39))])
        let kept = await session.standing.map(\.kind)
        XCTAssertEqual(kept, [.length(.words, .atMost(39)), .letterCase(.lowercase)])

        let fourth = await session.begin(request: "Forget the word limit. Always use bullets.")
        XCTAssertEqual(fourth.released, [.length])
        XCTAssertEqual(fourth.directives.map(\.kind), [.list(.bulleted), .letterCase(.lowercase)])

        let fifth = await session.begin(request: "Always answer in uppercase.")
        let replaced = await session.standing.map(\.kind)
        XCTAssertEqual(replaced, [.list(.bulleted), .letterCase(.uppercase)])
        XCTAssertEqual(fifth.carried.map(\.kind), [.list(.bulleted)])

        let sixth = await session.begin(request: "Use lowercase. Always use uppercase.")
        XCTAssertEqual(sixth.conflicts.count, 1)
        let totals = await session.totals
        XCTAssertEqual(totals.turns, 6)
        XCTAssertEqual(totals.conflictedTurns, 1)
        XCTAssertEqual(totals.checked, 2)
        XCTAssertEqual(totals.met, 1)
        XCTAssertEqual(totals.violated, 1)
    }

    func testReviewWithoutAPlanAndLooseTotals() async {
        let session = ComplianceSession()
        let unplanned = await session.review(answer: "Anything")
        XCTAssertEqual(unplanned.verdict, .noDirectives)
        await session.begin(request: "Answer in lowercase.")
        let plan = await session.plan
        XCTAssertEqual(plan?.turn, 1)
        _ = await session.review(answer: "Sure:\nok")
        let totals = await session.totals
        XCTAssertEqual(totals.metLoosely, 1)
    }
}
