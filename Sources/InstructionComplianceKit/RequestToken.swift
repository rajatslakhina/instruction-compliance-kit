/// One token of a request.
enum RequestToken: Hashable {
    /// A lowercased word; apostrophes are kept ("don't").
    case word(String)
    case number(Int)
    /// `50-100`, `3–5`.
    case range(Int, Int)
    /// The text between quotes, as written.
    case quote(String)
    /// A comma, colon, parenthesis or dash. Look-backs stop here.
    case mark

    var word: String? {
        if case let .word(text) = self { text } else { nil }
    }

    var number: Int? {
        if case let .number(value) = self { value } else { nil }
    }
}

/// A sentence or line of a request, and its tokens.
struct RequestClause: Hashable {
    let text: String
    let tokens: [RequestToken]
}
