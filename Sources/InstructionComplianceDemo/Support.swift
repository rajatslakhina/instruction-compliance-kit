import InstructionComplianceKit

func heading(_ number: Int, _ title: String) {
    print("")
    print("── \(number). \(title)")
}

func showRequest(_ request: String, _ reading: RequestReading) {
    print("   request: \(request)")
    for directive in reading.directives {
        let scope = directive.scope == .standing ? "  [standing]" : ""
        print("   • \(directive.summary)\(scope)")
    }
    if reading.directives.isEmpty { print("   • nothing a program can check") }
}

func show(_ report: ComplianceReport) {
    for result in report.results {
        let summary = result.directive.summary.padding(toLength: 30, withPad: " ", startingAt: 0)
        let status = result.status.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0)
        print("   \(summary)\(status)\(result.observed)")
    }
    let strict = percent(report.strictAccuracy)
    let loose = percent(report.looseAccuracy)
    print("   verdict: \(report.verdict.rawValue)  strict \(strict)  loose \(loose)")
    if let note = report.note { print("   note: \(note)") }
}

func percent(_ value: Double?) -> String {
    guard let value else { return "n/a" }
    return "\(Int((value * 100).rounded()))%"
}

func indented(_ text: String) -> String {
    text.split(separator: "\n", omittingEmptySubsequences: false).map { "   | " + $0 }.joined(separator: "\n")
}
