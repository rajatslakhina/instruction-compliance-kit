/// The instructions in force for one turn.
public struct TurnPlan: Sendable, Hashable {
    public let turn: Int
    /// This turn's instructions, then the standing ones it did not replace.
    public let directives: [Directive]
    /// Standing instructions from earlier turns, still in force.
    public let carried: [Directive]
    public let released: Set<DirectiveFamily>
    public let conflicts: [DirectiveConflict]
}

/// Running totals across a conversation.
public struct ComplianceTotals: Sendable, Hashable {
    public internal(set) var turns = 0
    public internal(set) var conflictedTurns = 0
    public internal(set) var checked = 0
    public internal(set) var met = 0
    public internal(set) var metLoosely = 0
    public internal(set) var violated = 0
}

/// Keeps a conversation's standing instructions. "From now on, answer in lowercase" holds on later
/// turns until a later instruction in the same slot replaces it or the user lifts it ("forget the
/// lowercase rule"). An instruction for one turn ("in all caps this time") sets a standing one aside
/// for that turn only.
///
/// An actor because a plan is made when the user sends and checked when the answer lands, and the
/// standing instructions must not change in between.
public actor ComplianceSession {
    public nonisolated let reader: DirectiveReader
    public nonisolated let checker: ComplianceChecker
    public private(set) var standing: [Directive] = []
    public private(set) var plan: TurnPlan?
    public private(set) var totals = ComplianceTotals()

    public init(reader: DirectiveReader = DirectiveReader(), checker: ComplianceChecker = ComplianceChecker()) {
        self.reader = reader
        self.checker = checker
    }

    @discardableResult
    public func begin(request: String) -> TurnPlan {
        let reading = reader.read(request)
        standing.removeAll { reading.released.contains($0.family) }
        let turnSlots = Set(reading.directives.map(\.slot))
        let carried = standing.filter { !turnSlots.contains($0.slot) }
        let newStanding = reading.directives.filter { $0.scope == .standing }
        let replaced = Set(newStanding.map(\.slot))
        standing = standing.filter { !replaced.contains($0.slot) } + newStanding
        let directives = reading.directives + carried
        totals.turns += 1
        let next = TurnPlan(
            turn: totals.turns,
            directives: directives,
            carried: carried,
            released: reading.released,
            conflicts: checker.detector.conflicts(in: directives)
        )
        totals.conflictedTurns += next.conflicts.isEmpty ? 0 : 1
        plan = next
        return next
    }

    /// Checks an answer against the current turn's plan.
    public func review(answer: String) -> ComplianceReport {
        let report = checker.report(answer: answer, directives: plan?.directives ?? [])
        totals.checked += report.results.count
        totals.met += report.results.filter { $0.status == .met }.count
        totals.metLoosely += report.results.filter { $0.status == .metLoosely }.count
        totals.violated += report.violated.count
        return report
    }
}
