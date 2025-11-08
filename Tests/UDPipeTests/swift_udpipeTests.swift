import Testing
@testable import UDPipe

@Test func example() async throws {
    // Print the UDPipe version exposed by the C wrapper
    let v = UDPipe.version()
    print("UDPipe version:", v)

    // Hard-coded model path (local to George's machine)
    let modelPath = "/Users/george/Documents/ML/swift-udpipe/english-ewt-ud-2.5-191206.udpipe"
    let text = "Hello world. This is a UDPipe tagging demo."

    // Initialize the model with the new API
    let udpipe = try UDPipe(modelPath: modelPath)

    // 1) Tokenization: sentence-level (default)
    let sentences = udpipe.tokenize(text)
    print("Sentence count:", sentences.count)
    #expect(sentences.count == 2)

    // 2) Tokenization: word-level (using the new overload)
    let words = udpipe.tokenize(text, by: .words)
    print("Word count:", words.count)
    print("Words:", words.map { $0.text }.joined(separator: " "))
    #expect(words.count == 10)

    // 3) Tagging
    let taggedSentences = udpipe.tagTokens(text)
    print("Tagged sentence count:", taggedSentences.count)
    #expect(taggedSentences.count == 2)

    // Verify some content from tagging
    if let firstToken = taggedSentences.first?.first {
        print("First token form: \(firstToken.form), lemma: \(firstToken.lemma), POS: \(firstToken.pos.rawValue)")
        #expect(firstToken.form == "Hello")
    } else {
        #expect(false, "Failed to get tagged tokens")
    }
}
