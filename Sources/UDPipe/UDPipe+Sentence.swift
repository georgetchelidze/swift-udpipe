public extension UDPipe {
    /// Represents a single sentence, which is composed of an array of tokens.
    struct Sentence: Sendable {
        /// The array of tokens that make up the sentence.
        public let tokens: [Token]
    }
}
