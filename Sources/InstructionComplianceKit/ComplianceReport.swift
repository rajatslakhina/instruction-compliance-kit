public enum ComplianceVerdict: String, Sendable, Hashable {
    /// The request had nothing a program can check.
    case noDirectives
    case compliant
    /// Compliant once a preamble or sign-off line is set aside.
    case compliantLoosely
    case violated
}

/// An answer checked against every instruction its request set.
public struct ComplianceReport: Sendable, Hashable {
    public let answer: String
    public let results: [DirectiveResult]
    /// Pairs of instructions no answer could satisfy together.
    public let conflicts: [DirectiveConflict]

    public init(answer: String, results: [DirectiveResult], conflicts: [DirectiveConflict] = []) {
        self.answer = answer
        self.results = results
        self.conflicts = conflicts
    }

    public var verdict: ComplianceVerdict {
        if results.isEmpty { return .noDirectives }
        if results.allSatisfy(\.metStrictly) { return .compliant }
        return results.allSatisfy(\.metLoosely) ? .compliantLoosely : .violated
    }

    /// Instructions the answer breaks on every reading.
    public var violated: [DirectiveResult] {
        results.filter { !$0.metLoosely }
    }

    /// Share of instructions met strictly (IFEval's instruction-level strict accuracy).
    public var strictAccuracy: Double? {
        fraction(results.filter(\.metStrictly).count)
    }

    public var looseAccuracy: Double? {
        fraction(results.filter(\.metLoosely).count)
    }

    /// For the person who asked. Nil unless something is violated.
    public var note: String? {
        guard verdict == .violated else { return nil }
        let items = violated.map { "\($0.directive.summary) (\($0.observed))" }
        let count = results.count == 1
            ? "the one instruction" : "\(violated.count) of the \(results.count) instructions"
        var note = "This answer doesn't follow \(count) in your request: " + items.joined(separator: "; ") + "."
        if !conflicts.isEmpty { note += " Some of those instructions conflict, so no answer could follow them all." }
        return note
    }

    /// For the model, to rewrite the answer. Nil unless something is violated.
    public var feedback: String? {
        guard verdict == .violated else { return nil }
        let lines = violated.map { "- \($0.directive.summary) (the answer: \($0.observed))" }
        return (["The answer above breaks these instructions from the user's request:"] + lines
            + ["Rewrite it so it follows every one of them. Keep everything else the same."])
            .joined(separator: "\n")
    }

    func fraction(_ count: Int) -> Double? {
        results.isEmpty ? nil : Double(count) / Double(results.count)
    }
}
