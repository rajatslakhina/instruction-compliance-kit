/// Two instructions no answer can satisfy together.
public struct DirectiveConflict: Sendable, Hashable {
    public let first: Directive
    public let second: Directive
    public let reason: String
}

/// Finds instructions that contradict each other, before anyone pays for an answer that cannot
/// follow them: "at most 2 sentences" with "at least 3 paragraphs", "use \"latency\"" with "don't use
/// \"latency\"", valid JSON as a bulleted list.
public struct ConflictDetector: Sendable {
    /// Each unit on the left holds at least one of the unit on the right.
    static let containment: [(LengthUnit, LengthUnit)] = [
        (.paragraphs, .sentences), (.paragraphs, .words), (.sentences, .words), (.items, .words),
        (.paragraphs, .characters), (.sentences, .characters), (.items, .characters), (.words, .characters)
    ]

    public init() {}

    public func conflicts(in directives: [Directive]) -> [DirectiveConflict] {
        var found: [DirectiveConflict] = []
        for (offset, first) in directives.enumerated() {
            for second in directives[(offset + 1)...] {
                if let reason = reason(first.kind, second.kind) ?? reason(second.kind, first.kind) {
                    found.append(DirectiveConflict(first: first, second: second, reason: reason))
                }
            }
        }
        return found
    }

    func reason(_ first: DirectiveKind, _ second: DirectiveKind) -> String? {
        shapeReason(first, second) ?? textReason(first, second)
    }

    /// Lengths, letter case and lists.
    func shapeReason(_ first: DirectiveKind, _ second: DirectiveKind) -> String? {
        switch (first, second) {
        case let (.length(unit, bound), .length(otherUnit, otherBound)):
            return lengthReason(unit, bound, otherUnit, otherBound)
        case (.letterCase(.lowercase), .letterCase(.uppercase)):
            return "an answer cannot be all lowercase and all uppercase"
        case (.list, .noList):
            return "a list was asked for and lists were ruled out"
        case (.list(.bulleted), .list(.numbered)):
            return "a list cannot be bulleted and numbered at once"
        case let (.length(.items, bound), .noList) where bound.range.lowerBound > 0:
            return "list items were asked for and lists were ruled out"
        default:
            return nil
        }
    }

    /// Words, required text and formats.
    func textReason(_ first: DirectiveKind, _ second: DirectiveKind) -> String? {
        switch (first, second) {
        case let (.include(term), .exclude(avoided)) where TextMatch.count(of: avoided, in: term) > 0:
            return term == avoided ? "\"\(term)\" is both required and ruled out"
                : "\"\(term)\" has to appear and contains \"\(avoided)\", which must not"
        case let (.startsWith(options), .exclude(avoided)), let (.endsWith(options), .exclude(avoided)):
            let blocked = options.allSatisfy { TextMatch.count(of: avoided, in: $0) > 0 }
            return blocked ? "the required text contains \"\(avoided)\", which must not appear" : nil
        case let (.endsWith(options), .endsWithQuestion):
            return options.contains { $0.hasSuffix("?") } ? nil : "the required ending is not a question"
        case (.format(.json), .format(.table)), (.format(.plainText), .format(.table)):
            return "a markdown table cannot be \(first == .format(.json) ? "valid JSON" : "plain text")"
        case (.format(.json), .list):
            return "valid JSON cannot be a markdown list"
        case (.format(.json), .endsWithQuestion):
            return "valid JSON cannot end with a question"
        case let (.format(.json), .startsWith(options)):
            return options.contains { $0.hasPrefix("{") || $0.hasPrefix("[") } ? nil : "valid JSON starts with { or ["
        case let (.noCommas, .include(text)):
            return text.contains(",") ? "\"\(text)\" has a comma" : nil
        default:
            return nil
        }
    }

    func lengthReason(_ unit: LengthUnit, _ bound: Bound, _ otherUnit: LengthUnit, _ otherBound: Bound) -> String? {
        let first = "\(bound.text) \(unit.noun(for: bound.lastNumber))"
        let second = "\(otherBound.text) \(otherUnit.noun(for: otherBound.lastNumber))"
        if unit == otherUnit {
            return bound.range.overlaps(otherBound.range) ? nil : "no length is both \(first) and \(second)"
        }
        let holds = Self.containment.contains { $0 == (unit, otherUnit) }
        guard holds, bound.range.lowerBound > otherBound.range.upperBound else { return nil }
        return "\(first) need at least \(bound.range.lowerBound) \(otherUnit.rawValue), more than \(second) allows"
    }
}
