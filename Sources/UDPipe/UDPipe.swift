import UDPipeCLib
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A Swift wrapper for the UDPipe NLP toolkit.
///
/// This class provides a high-level interface for loading a UDPipe model and using it
/// for tokenization, part-of-speech tagging, lemmatization, and dependency parsing.
///
/// To use it, first create an instance by loading a model file:
/// ```
/// let udpipe = try UDPipe(modelPath: "path/to/your/model.udpipe")
/// ```
///
/// Then, you can use the instance to process text:
/// ```
/// let text = "Hello world. This is a test."
///
/// // Tokenize text into sentences (default)
/// let sentences = udpipe.tokenize(text)
/// for sentence in sentences {
///     let words = sentence.tokens.map { $0.text }.joined(separator: " ")
///     print("Sentence:", words)
/// }
///
/// // Tokenize text into a flat list of words
/// let words = udpipe.tokenize(text, by: .words)
/// print("Words:", words.map { $0.text })
///
/// // Perform full tagging
/// let taggedSentences = udpipe.tagTokens(text)
/// for taggedSentence in taggedSentences {
///     for token in taggedSentence {
///         print("\(token.form) \(token.lemma) \(token.pos.rawValue)")
///     }
/// }
/// ```
public final class UDPipe {
    private let handle: udpipe_model_t

    /// Loads a UDPipe model from the specified file path.
    ///
    /// - Parameter modelPath: The path to the `.udpipe` model file.
    /// - Throws: `UDPipeError.modelLoadFailed` if the model cannot be loaded.
    public init(modelPath: String) throws {
        guard let h = udpipe_model_load(modelPath) else {
            throw UDPipeError.modelLoadFailed(path: modelPath)
        }
        self.handle = h
    }

    deinit {
        udpipe_model_free(handle)
    }

    /// Returns the version of the underlying UDPipe C++ library.
    public static func version() -> String {
        String(cString: udpipe_version())
    }

    /// Processes the input text and returns rich tagged information for each token,
    /// grouped by sentence. This includes lemmas, part-of-speech tags, and dependency parsing.
    ///
    /// - Parameter text: The text to process.
    /// - Returns: An array of sentences, where each sentence is an array of `TaggedToken`s.
    public func tagTokens(_ text: String, doParse: Bool = true) -> [[TaggedToken]] {
        var doc = udpipe_doc_view(sentences: nil, count: 0, arena: nil)
        let ok = text.withCString { cstr in
            udpipe_tag_structured(handle, cstr, doParse ? 1 : 0, &doc)
        }
        guard ok == 1 else { return [] }
        defer { udpipe_free_doc(&doc) }

        return _convertDocView(doc)
    }

    /// Processes a batch of input texts in parallel and returns rich tagged information for each.
    ///
    /// This method is highly optimized for server-side use and will use multiple threads
    /// to process the batch concurrently, taking advantage of multi-core CPUs.
    ///
    /// - Parameters:
    ///   - batch: An array of strings to process.
    ///   - doParse: If `true`, performs full dependency parsing. If `false`, only performs
    ///              tokenization, lemmatization, and part-of-speech tagging.
    /// - Returns: An array of results, where each result corresponds to an input string and contains
    ///            an array of sentences, which in turn contain an array of `TaggedToken`s.
    public func tagTokens(batch: [String], doParse: Bool = true) -> [[[TaggedToken]]] {
        // 1. Convert Swift [String] to a C-compatible array of C-strings.
        //    Keep owned mutable pointers for freeing, but pass as const char**.
        let ownedCStrings: [UnsafeMutablePointer<CChar>] = batch.map { s in
            if let p = strdup(s) { return p }
            return strdup("")!
        }
        var constCStringPtrs: [UnsafePointer<CChar>?] = ownedCStrings.map { UnsafePointer($0) }
        defer { for ptr in ownedCStrings { free(ptr) } }

        // 2. Prepare variables for the C function to write its results into.
        var outDocs: UnsafeMutablePointer<udpipe_doc_view>? = nil
        var outSize: Int = 0

        // 3. Call the parallel C++ batch processing function.
        //    Swift's C interop can bridge an array of pointers to a C-style
        //    array of pointers for the duration of the call. We use `withUnsafeBufferPointer`
        //    to handle the conversion from mutable to immutable pointers safely.
        let ok = constCStringPtrs.withUnsafeMutableBufferPointer { buf -> Int32 in
            guard let base = buf.baseAddress else { return 0 }
            // Signature expects UnsafeMutablePointer<UnsafePointer<CChar>?> (const char**)
            return udpipe_tag_batch(
                self.handle,
                base,
                batch.count,
                doParse ? 1 : 0,
                &outDocs,
                &outSize
            )
        }

        // 5. Ensure the call succeeded and the output looks correct.
        guard ok == 1, let docs = outDocs, outSize == batch.count else {
            // If the call failed but allocated some memory, try to clean up.
            if let docs = outDocs {
                udpipe_free_batch(docs, outSize)
            }
            // Return an empty array of arrays, maintaining the structure.
            return Array(repeating: [], count: batch.count)
        }

        // 6. Ensure the results are freed after we're done converting them.
        defer { udpipe_free_batch(docs, outSize) }

        // 7. Convert the C data structures back into Swift types.
        var batchResult: [[[TaggedToken]]] = []
        batchResult.reserveCapacity(outSize)

        for i in 0..<outSize {
            let docView = docs.advanced(by: i).pointee
            let taggedSentences = self._convertDocView(docView)
            batchResult.append(taggedSentences)
        }

        return batchResult
    }

    /// Tokenizes the input text into sentences.
    ///
    /// This is the default tokenization behavior. To get a flat list of words instead,
    /// use the overload that accepts a `by:` parameter.
    ///
    /// - Parameters:
    ///   - text: The text to tokenize.
    ///   - options: Optional tokenizer options for the underlying UDPipe engine.
    /// - Returns: An array of `Sentence` objects.
    public func tokenize(_ text: String, options: String? = nil) -> [Sentence] {
        return _tokenize(text, options: options)
    }

    /// Tokenizes the input text into a flat list of words.
    ///
    /// - Parameters:
    ///   - text: The text to tokenize.
    ///   - by: The desired output format. Currently only `.words` is supported.
    ///   - options: Optional tokenizer options for the underlying UDPipe engine.
    /// - Returns: A flat array of `Token` objects.
    public func tokenize(_ text: String, by: TokenizationOutput, options: String? = nil) -> [Token] {
        return _tokenize(text, options: options).flatMap { $0.tokens }
    }

    /// Internal tokenization implementation that always returns sentences.
    private func _tokenize(_ text: String, options: String? = nil) -> [Sentence] {
        var doc = udpipe_doc_view(sentences: nil, count: 0, arena: nil)
        let ok: Int32 = text.withCString { cstr in
            if let opt = options {
                return opt.withCString { o in udpipe_tokenize_structured(self.handle, cstr, o, &doc) }
            } else {
                return udpipe_tokenize_structured(self.handle, cstr, nil, &doc)
            }


        }
        guard ok == 1 else { return [] }
        defer { udpipe_free_doc(&doc) }

        var out: [Sentence] = []
        out.reserveCapacity(Int(doc.count))
        for i in 0..<Int(doc.count) {
            let sv = doc.sentences!.advanced(by: i).pointee
            var toks: [Token] = []
            toks.reserveCapacity(Int(sv.count))
            for j in 0..<Int(sv.count) {
                let ctok = sv.tokens!.advanced(by: j).pointee
                let tok = Token(text: String(cString: ctok.form), start: Int(ctok.start), end: Int(ctok.end))
                toks.append(tok)
            }
            out.append(Sentence(tokens: toks))
        }
        return out
    }

    /// Tags the input text and returns the output in CoNLL-U format.
    ///
    /// - Parameter text: The text to process.
    /// - Returns: A string containing the analysis in CoNLL-U format, or `nil` on failure.
    public func tagToConllu(_ text: String) -> String? {
        guard let c = udpipe_tag_conllu(handle, text) else { return nil }
        defer { udpipe_string_free(c) }
        return String(cString: c)
    }

    // MARK: - Private Helpers

    /// Converts a C `udpipe_doc_view` into a Swift `[[TaggedToken]]`.
    private func _convertDocView(_ doc: udpipe_doc_view) -> [[TaggedToken]] {
        var result: [[TaggedToken]] = []
        guard doc.count > 0, let sentences = doc.sentences else { return [] }
        result.reserveCapacity(Int(doc.count))

        for i in 0..<Int(doc.count) {
            let sv = sentences.advanced(by: i).pointee
            var sent: [TaggedToken] = []
            guard sv.count > 0, let tokens = sv.tokens else {
                result.append([])
                continue
            }
            sent.reserveCapacity(Int(sv.count))

            for j in 0..<Int(sv.count) {
                let ctok = tokens.advanced(by: j).pointee
                let form = String(cString: ctok.form)
                let lemma = String(cString: ctok.lemma)
                let uposS = String(cString: ctok.upos)
                let xpostagS = String(cString: ctok.xpostag)
                let featsS = String(cString: ctok.feats)
                let deprelS = String(cString: ctok.deprel)
                let tok = TaggedToken(
                    id: Int(ctok.id),
                    form: form,
                    lemma: lemma,
                    pos: POS.parse(uposS),
                    xpostag: xpostagS.isEmpty ? nil : xpostagS,
                    features: UDPipe.parseFeatures(featsS),
                    head: ctok.head >= 0 ? Int(ctok.head) : nil,
                    deprel: deprelS.isEmpty ? nil : Deprel.parse(deprelS),
                    start: Int(ctok.start),
                    end: Int(ctok.end)
                )
                sent.append(tok)
            }
            result.append(sent)
        }
        return result
    }
}
