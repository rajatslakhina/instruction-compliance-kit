/// What a length instruction counts.
public enum LengthUnit: String, Sendable, Hashable, CaseIterable {
    case words
    case sentences
    case paragraphs
    /// Bulleted and numbered list items together.
    case items
    case characters

    /// The unit's name for a count, singular for one.
    public func noun(for count: Int) -> String {
        let plural = switch self {
        case .words: "words"
        case .sentences: "sentences"
        case .paragraphs: "paragraphs"
        case .items: "list items"
        case .characters: "characters"
        }
        return count == 1 ? String(plural.dropLast()) : plural
    }
}

/// A bound on a count. Every case is inclusive.
public enum Bound: Sendable, Hashable {
    case atMost(Int)
    case atLeast(Int)
    case exactly(Int)
    case between(Int, Int)
    /// Within a fifth either side, for "about 100 words".
    case around(Int)

    public var range: ClosedRange<Int> {
        switch self {
        case let .atMost(limit): 0...limit
        case let .atLeast(limit): limit...Int.max
        case let .exactly(count): count...count
        case let .between(low, high): low...high
        case let .around(count): (count - count / 5)...(count + count / 5)
        }
    }

    public func admits(_ count: Int) -> Bool {
        range.contains(count)
    }

    /// The number a summary names last, which decides singular or plural.
    var lastNumber: Int {
        switch self {
        case let .atMost(count), let .atLeast(count), let .exactly(count), let .around(count): count
        case let .between(_, high): high
        }
    }

    var text: String {
        switch self {
        case let .atMost(count): "at most \(count)"
        case let .atLeast(count): "at least \(count)"
        case let .exactly(count): "exactly \(count)"
        case let .between(low, high): "between \(low) and \(high)"
        case let .around(count): "about \(count)"
        }
    }
}

public enum ListStyle: String, Sendable, Hashable {
    case bulleted
    case numbered
}

public enum LetterCase: String, Sendable, Hashable {
    case lowercase
    case uppercase
}

public enum TextFormat: String, Sendable, Hashable {
    case json
    case table
    /// No markdown markup: headings, bold, code fences, tables or links.
    case plainText
}

/// One instruction a program can check.
public enum DirectiveKind: Sendable, Hashable {
    case length(LengthUnit, Bound)
    case list(ListStyle)
    case noList
    /// A word or phrase the answer has to use.
    case include(String)
    /// A word or phrase the answer must not use.
    case exclude(String)
    case letterCase(LetterCase)
    /// Any one of the options, compared without regard to case.
    case startsWith([String])
    case endsWith([String])
    case endsWithQuestion
    case format(TextFormat)
    case noCommas
}

/// Groups of instructions a user can lift together ("forget the word limit").
public enum DirectiveFamily: String, Sendable, Hashable, CaseIterable {
    case length
    case list
    case terms
    case letterCase
    case opening
    case ending
    case format
    case punctuation
}

public enum DirectiveScope: String, Sendable, Hashable {
    /// This turn only.
    case turn
    /// "From now on", "always", "every answer": kept until replaced or lifted.
    case standing
}

/// Instructions in the same slot replace each other across turns.
enum DirectiveSlot: Hashable {
    case length(LengthUnit)
    case list
    case term(String)
    case letterCase
    case opening
    case ending
    case format
    case commas
}

/// An instruction read from a request, with the clause it was read from.
public struct Directive: Sendable, Hashable {
    public let kind: DirectiveKind
    public let scope: DirectiveScope
    public let phrase: String

    public init(kind: DirectiveKind, scope: DirectiveScope = .turn, phrase: String = "") {
        self.kind = kind
        self.scope = scope
        self.phrase = phrase
    }

    public var family: DirectiveFamily {
        switch kind {
        case .length: .length
        case .list, .noList: .list
        case .include, .exclude: .terms
        case .letterCase: .letterCase
        case .startsWith: .opening
        case .endsWith, .endsWithQuestion: .ending
        case .format: .format
        case .noCommas: .punctuation
        }
    }

    var slot: DirectiveSlot {
        switch kind {
        case let .length(unit, _): .length(unit)
        case .list, .noList: .list
        case let .include(term), let .exclude(term): .term(term)
        case .letterCase: .letterCase
        case .startsWith: .opening
        case .endsWith, .endsWithQuestion: .ending
        case .format: .format
        case .noCommas: .commas
        }
    }

    /// The instruction in a few words: "at most 100 words", "don't use \"delve\"".
    public var summary: String {
        switch kind {
        case let .length(unit, bound): "\(bound.text) \(unit.noun(for: bound.lastNumber))"
        case let .list(style): "a \(style.rawValue) list"
        case .noList: "no lists"
        case let .include(term): "use \"\(term)\""
        case let .exclude(term): "don't use \"\(term)\""
        case let .letterCase(letterCase): "all \(letterCase.rawValue)"
        case let .startsWith(options): "start with " + Self.quoted(options)
        case let .endsWith(options): "end with " + Self.quoted(options)
        case .endsWithQuestion: "end with a question"
        case .format(.json): "valid JSON"
        case .format(.table): "a table"
        case .format(.plainText): "plain text, no markdown"
        case .noCommas: "no commas"
        }
    }

    static func quoted(_ options: [String]) -> String {
        options.map { "\"\($0)\"" }.joined(separator: " or ")
    }
}
