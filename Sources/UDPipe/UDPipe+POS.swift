public extension UDPipe {
    /// Represents the Universal Part-of-Speech (UPOS) tags.
    ///
    /// These tags are part of the Universal Dependencies standard for grammatical annotation.
    enum POS: String, Sendable {
        case adjective = "ADJ"
        case adposition = "ADP"
        case adverb = "ADV"
        case auxiliary = "AUX"
        case coordinatingConjunction = "CCONJ"
        case determiner = "DET"
        case interjection = "INTJ"
        case noun = "NOUN"
        case numeral = "NUM"
        case particle = "PART"
        case pronoun = "PRON"
        case properNoun = "PROPN"
        case punctuation = "PUNCT"
        case subordinatingConjunction = "SCONJ"
        case symbol = "SYM"
        case verb = "VERB"
        case other = "X"

        /// Parses a raw string tag into a `POS` enum case.
        ///
        /// - Parameter tag: The string representation of the UPOS tag.
        /// - Returns: The corresponding `POS` case, or `.other` if no match is found.
        static func parse(_ tag: String) -> POS {
            return POS(rawValue: tag.uppercased()) ?? .other
        }
    }
}
