import InstructionComplianceKit

let reader = DirectiveReader()
let checker = ComplianceChecker()

let summaryRequest = """
    Summarize this 2,000-word incident report in under 80 words, as 3 to 5 bullet points. \
    Don't mention the vendor names, avoid the word "synergy", and end with a question.
    """

func readingOneRequest() {
    heading(1, "Reading one request")
    showRequest(summaryRequest, reader.read(summaryRequest))
    print("   (\"this 2,000-word incident report\" describes the material, so it is not a limit)")
}

func strictAndLoose() {
    heading(2, "A preamble the loose reading sets aside")
    let answer = """
        Sure! Here is a short summary of the incident for you:
        - The cache layer stopped answering at 09:12 after a config push.
        - Failover took 14 minutes because the health check was disabled.
        - The config push has been reverted and the check turned back on.
        Should the health check be made mandatory before any config push?
        Let me know if you want the full timeline.
        """
    print(indented(answer))
    show(checker.report(answer: answer, directives: reader.read(summaryRequest).directives))
}

func violationAndRewrite() {
    heading(3, "A violation, the feedback for the model, and the rewrite")
    let directives = reader.read(summaryRequest).directives
    let first = """
        - Acme Cloud's cache layer stopped answering at 09:12 after a config push.
        - Failover took 14 minutes because the health check was disabled.
        - The team showed real synergy in the recovery.
        - The config push was reverted.
        - The check is back on.
        - A review is booked for Friday.
        """
    print(indented(first))
    let report = checker.report(answer: first, directives: directives)
    show(report)
    print("   feedback sent back to the model:")
    print(indented(report.feedback ?? ""))
    let second = """
        - The cache layer stopped answering at 09:12 after a config push.
        - Failover took 14 minutes because the health check was disabled.
        - The push is reverted and the check is back on.
        Should health checks block config pushes from now on?
        """
    print("   rewrite:")
    print(indented(second))
    show(checker.report(answer: second, directives: directives))
}

func conflictsBeforeTheCall() {
    heading(4, "Conflicts found before anyone pays for an answer")
    let requests = [
        "Explain it in at most 2 sentences, across at least 3 paragraphs.",
        "Mention \"latency\" in the answer. Never use the word \"latency\".",
        "Return valid JSON as a bulleted list, all in lowercase and all caps."
    ]
    for request in requests {
        let directives = reader.read(request).directives
        print("   request: \(request)")
        for conflict in ConflictDetector().conflicts(in: directives) {
            print("   ✗ \(conflict.first.summary) / \(conflict.second.summary): \(conflict.reason)")
        }
    }
}

func standingAcrossTurns() async {
    heading(5, "Standing instructions across turns")
    let session = ComplianceSession()
    let turns: [(String, String)] = [
        ("From now on, answer in all lowercase and keep every answer under 40 words. What is a mutex?",
         "a mutex is a lock that lets one thread at a time into a critical section."),
        ("And a semaphore?",
         "A semaphore is a counter that lets up to N threads in at once."),
        ("Forget the word limit. Explain condition variables properly.",
         """
         a condition variable lets a thread sleep until another thread signals that some state has \
         changed. it is always used with a mutex: the waiting thread releases the mutex while it sleeps \
         and takes it back before it returns, so it can re-check the state without a race. spurious \
         wake-ups happen, so the check runs in a loop.
         """),
        ("Answer in all caps this time: what is a spinlock?",
         "A LOCK THAT BUSY-WAITS INSTEAD OF SLEEPING."),
        ("What about a barrier?",
         "a barrier makes every thread wait until all of them have reached the same point.")
    ]
    for (request, answer) in turns {
        let plan = await session.begin(request: request)
        let report = await session.review(answer: answer)
        let rules = plan.directives.map { $0.summary + ($0.scope == .standing ? "*" : "") }
        let carried = plan.carried.isEmpty ? "" : "  (carried: \(plan.carried.count))"
        let liftedNames = plan.released.map(\.rawValue).sorted().joined(separator: ", ")
        let lifted = plan.released.isEmpty ? "" : "  (lifted: \(liftedNames))"
        print("   turn \(plan.turn): \(request)")
        print("     in force: \(rules.isEmpty ? "none" : rules.joined(separator: ", "))\(carried)\(lifted)")
        let broken = report.violated.map(\.observed).joined(separator: "; ")
        print("     verdict: \(report.verdict.rawValue)\(broken.isEmpty ? "" : "  " + broken)")
    }
    let totals = await session.totals
    print("   totals: \(totals.turns) turns, \(totals.checked) checks, \(totals.met) met, \(totals.violated) violated")
}

func whatTheReaderLeavesAlone() {
    heading(6, "What the reader leaves alone")
    let requests = [
        "Rewrite this 500-word email in 3 sentences.",
        "Give me 2 paragraphs, each under 60 words.",
        "Translate 'Good morning' into French.",
        "Don't use a numbered list, use bullets.",
        "Mention the price somewhere."
    ]
    for request in requests {
        let summaries = reader.read(request).directives.map(\.summary)
        print("   \(request)")
        print("     → \(summaries.isEmpty ? "nothing to check" : summaries.joined(separator: ", "))")
    }
}

func formats() {
    heading(7, "JSON, tables, plain text and commas")
    let cases: [(String, String)] = [
        ("Give the result as valid JSON.", "```json\n{\"region\": \"eu-west\", \"errors\": 14}\n```"),
        ("Compare the two plans in a table.", "| Plan | Price |\n|---|---|\n| Basic | $9 |\n| Pro | $29 |"),
        ("Plain text only, no markdown and no commas.",
         "**Short answer**: yes, but only on weekdays, and only before 9.")
    ]
    for (request, answer) in cases {
        print("   request: \(request)")
        print(indented(answer))
        show(checker.report(answer: answer, directives: reader.read(request).directives))
    }
}
