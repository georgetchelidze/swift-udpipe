public extension UDPipe {
    // MARK: - Helper Types & Parsers

    /// An enum to specify the desired output of tokenization.
    enum TokenizationOutput {
        /// Return a flat array of word tokens.
        case words
    }

    /// Defines errors that can be thrown by the UDPipe wrapper.
    enum UDPipeError: Error, Sendable {
        /// Thrown when loading a model from a file path fails.
        case modelLoadFailed(path: String)
    }

    /// Parses a string in CoNLL-U format into tagged tokens, grouped by sentence.
    ///
    /// Note: This parser is minimal and may not handle all edge cases. It also doesn't
    /// fill in character offsets (`start`, `end`).
    ///
    /// - Parameter conllu: The string containing the CoNLL-U data.
    /// - Returns: An array of sentences, where each sentence is an array of `TaggedToken`s.
    static func parseConllu(_ conllu: String) -> [[TaggedToken]] {
        var sentences: [[TaggedToken]] = []
        var current: [TaggedToken] = []

        func flush() {
            if !current.isEmpty { sentences.append(current); current.removeAll(keepingCapacity: true) }
        }

        for rawLine in conllu.split(maxSplits: .max, omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }) {
            let line = String(rawLine)
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("#") { continue }
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 4 else { continue }
            let idField = fields[0]
            // Skip ranges like 1-2 and empty nodes like 2.1
            if idField.contains("-") || idField.contains(".") { continue }
            guard let id = Int(idField) else { continue }
            let form = String(fields[1])
            let lemma = fields.count > 2 ? String(fields[2]) : ""
            let upos = fields.count > 3 ? String(fields[3]) : "X"
            let xpostag = fields.count > 4 ? String(fields[4]) : ""
            let featsS = fields.count > 5 ? String(fields[5]) : ""
            let head = fields.count > 6 ? Int(fields[6]) : nil
            let deprelS = fields.count > 7 ? String(fields[7]) : ""
            let tok = TaggedToken(
                id: id,
                form: form,
                lemma: lemma,
                pos: POS.parse(upos),
                xpostag: xpostag.isEmpty ? nil : xpostag,
                features: UDPipe.parseFeatures(featsS),
                head: head,
                deprel: deprelS.isEmpty ? nil : Deprel.parse(deprelS),
                start: 0, end: 0
            )
            current.append(tok)
        }
        flush()
        return sentences
    }


}
