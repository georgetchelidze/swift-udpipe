public extension UDPipe {
    /// Represents a single token with rich linguistic annotations from the UDPipe model.
    struct TaggedToken: Sendable {
        /// The 1-based index of the token within the sentence.
        public let id: Int
        /// The raw text form of the token.
        public let form: String
        /// The lemma, or base form, of the token.
        public let lemma: String
        /// The Universal Part-of-Speech (UPOS) tag.
        public let pos: POS
        /// The language-specific part-of-speech tag (XPOS).
        public let xpostag: String?
        /// A list of morphological features.
        public let features: [MorphFeature]
        /// The index of the token which is the syntactic head of this token.
        public let head: Int?
        /// The dependency relation to the head token.
        public let deprel: Deprel?
        /// The starting UTF-8 byte offset of the token in the original input string.
        public let start: Int
        /// The ending UTF-8 byte offset (exclusive) of the token in the original input string.
        public let end: Int
    }
}
