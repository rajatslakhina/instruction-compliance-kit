/// Look-ups over a clause's tokens. Look-backs stop at a mark or a joining word, so the "no" in
/// "no commas, bullet points please" does not reach "bullet".
extension Array where Element == RequestToken {
    static let negators: Set<String> = [
        "no", "not", "don't", "dont", "never", "without", "nor", "doesn't", "shouldn't", "mustn't",
        "cannot", "can't", "won't", "avoid"
    ]
    static let joiners: Set<String> = ["and", "but", "then", "also", "plus"]

    func word(at index: Int) -> String? {
        indices.contains(index) ? self[index].word : nil
    }

    /// Whether a negating word sits within `window` tokens before `index`.
    func hasNegator(before index: Int, within window: Int = 3) -> Bool {
        var position = index - 1
        while position >= 0, position >= index - window {
            guard let word = self[position].word, !Self.joiners.contains(word) else {
                if case .quote = self[position] {
                    position -= 1
                    continue
                }
                return false
            }
            if Self.negators.contains(word) { return true }
            position -= 1
        }
        return false
    }

    func containsSequence(_ words: [String]) -> Bool {
        guard count >= words.count else { return false }
        return (0...(count - words.count)).contains { start in
            words.indices.allSatisfy { self[start + $0].word == words[$0] }
        }
    }

    func containsWord(in words: Set<String>) -> Bool {
        contains { $0.word.map(words.contains) ?? false }
    }
}
