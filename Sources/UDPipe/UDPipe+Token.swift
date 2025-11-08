public extension UDPipe {
    /// A simple token, representing a single word or punctuation mark from the input text.
    struct Token: Sendable {
        /// The raw text of the token.
        public let text: String
        /// The starting UTF-8 byte offset of the token in the original input string.
        public let start: Int
        /// The ending UTF-8 byte offset (exclusive) of the token in the original input string.
        public let end: Int
    }
}
