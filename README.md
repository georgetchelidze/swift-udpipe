# Swift UDPipe Wrapper

This package exposes a Swift-friendly interface to the UDPipe NLP toolkit. It lets you load a `.udpipe` model once and reuse it for tokenization, lemmatization, part-of-speech tagging, and dependency parsing directly from Swift.

## Getting Started

```swift
import UDPipe

let udpipe = try UDPipe(modelPath: "path/to/your/model.udpipe")
```

Retrieve the bundled C++ library version if you need to confirm compatibility:

```swift
let version = UDPipe.version()
```

## Tokenize Text

```swift
let text = "Hello world. This is a test."

// Sentence tokenization (default)
let sentences = udpipe.tokenize(text)
for sentence in sentences {
    let words = sentence.tokens.map { $0.text }.joined(separator: " ")
    print("Sentence:", words)
}

// Flat list of words
let words = udpipe.tokenize(text, by: .words)
print("Words:", words.map { $0.text })
```

Pass tokenizer options if the underlying UDPipe tokenizer needs configuration:

```swift
let customSentences = udpipe.tokenize(text, options: "normalize")
```

## Tagging And Parsing

Perform full tagging (tokenization, lemma, POS, morphological features, dependency heads/relations) with optional parsing:

```swift
let taggedSentences = udpipe.tagTokens(text, doParse: true)
for taggedSentence in taggedSentences {
    for token in taggedSentence {
        print("\(token.form) \(token.lemma) \(token.pos.rawValue)")
    }
}
```

Process multiple texts concurrently via the optimized batch API:

```swift
let inputs = ["Hello world.", "This is a test."]
let results = udpipe.tagTokens(batch: inputs, doParse: true)
```

Each entry in `results` mirrors the structure of the single-text API (`[[TaggedToken]]`), making it easy to parallelize downstream logic.

## CoNLL-U Export

If you prefer working with standard CoNLL-U strings, convert directly:

```swift
if let conllu = udpipe.tagToConllu(text) {
    print(conllu)
}
```

## Strongly Typed Linguistic Data

`TaggedToken` surfaces rich, typed metadata so downstream code can stay safe and expressive:

- `POS` (`Sources/UDPipe/UDPipe+POS.swift`) enumerates the Universal POS tags; unknown tags fall back to `.other` and parsing is handled for you.
- `Deprel` (`Sources/UDPipe/UDPipe+Deprel.swift`) captures Universal Dependencies relations with the same fallback semantics.
- `MorphFeature` (`Sources/UDPipe/UDPipe+MorphFeature.swift`) represents parsed FEATS entries as enums (number, case, tense, etc.) with an escape hatch for custom values.
- Offsets, lemmas, XPOS tags, and dependency heads are all available through `TaggedToken`.

## Error Handling

Model loading throws `UDPipeError.modelLoadFailed(path:)` when the specified model cannot be opened. Tagging and tokenization functions return empty arrays (or `nil` for `tagToConllu`) when the underlying C API reports a failure, so be sure to handle those cases in production code.
