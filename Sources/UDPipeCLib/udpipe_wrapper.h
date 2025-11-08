#pragma once

#include <stddef.h> // for size_t

#ifdef __cplusplus
// By including the core C++ header here, guarded for C++, we make the
// necessary C++ definitions available to the implementation file
// (`udpipe_wrapper.cpp`) without polluting the C-compatible interface
// that Swift consumes. This can help resolve static analyzer warnings
// about unused includes in the .cpp file.
#include "../../Vendors/udpipe/src_lib_only/udpipe.h"
extern "C" {
#endif

// Returns the UDPipe library version as a C string.
// The returned pointer is valid for the lifetime of the process.
const char* udpipe_version(void);

// Opaque model handle
typedef void* udpipe_model_t;

// Opaque handle for a memory arena used for string allocations.
typedef void* udpipe_arena_t;

// Load a UDPipe model from file path. Returns NULL on failure.
udpipe_model_t udpipe_model_load(const char* model_path);

// Release a model loaded by udpipe_model_load.
void udpipe_model_free(udpipe_model_t model);

// Tag the given UTF-8 text and return CoNLL-U as a newly allocated C string.
// Caller must free with udpipe_string_free.
char* udpipe_tag_conllu(udpipe_model_t model, const char* utf8_text);

// Free a string returned by this API.
void udpipe_string_free(char* p);

// Structured tagging API
// ----------------------
// Simple C token representation to avoid parsing textual formats in Swift.
typedef struct {
    int id;           // 1-based token id within sentence
    int head;         // head id (0=root), -1 if unavailable
    const char* form;     // token surface form
    const char* lemma;    // lemma (may be empty)
    const char* upos;     // UPOS tag (may be empty)
    const char* xpostag;  // XPOS tag (may be empty)
    const char* feats;    // FEATS string (may be empty)
    const char* deprel;   // dependency relation (may be empty)
    size_t start;     // UTF-8 byte start offset in input, if available
    size_t end;       // UTF-8 byte end offset (exclusive), if available
} udpipe_token;

typedef struct {
    udpipe_token* tokens;
    size_t count;
} udpipe_sentence_view;

typedef struct {
    udpipe_sentence_view* sentences;
    size_t count;
    udpipe_arena_t arena; // Internal memory arena for this document
} udpipe_doc_view;

// Tag text and return structured sentences/tokens. If do_parse != 0, also run the parser
// and fill head/deprel when available. Returns 1 on success, 0 on failure.
int udpipe_tag_structured(udpipe_model_t model, const char* utf8_text, int do_parse,
                          udpipe_doc_view* out_doc);

// Release memory allocated inside udpipe_tag_structured.
void udpipe_free_doc(udpipe_doc_view* doc);

// Tag a batch of texts in parallel and return an array of structured documents.
// The caller is responsible for freeing the `out_docs` array and its contents
// by calling `udpipe_free_batch`.
// Returns 1 on success, 0 on failure.
int udpipe_tag_batch(udpipe_model_t model, const char** utf8_texts, size_t batch_size, int do_parse,
                     udpipe_doc_view** out_docs, size_t* out_size);

// Release memory for a batch of documents allocated by `udpipe_tag_batch`.
void udpipe_free_batch(udpipe_doc_view* docs, size_t batch_size);

// Tokenize-only: build sentences and tokens with offsets, but no POS/parsing.
// `tokenizer_options` can be NULL or an empty string for defaults.
int udpipe_tokenize_structured(udpipe_model_t model, const char* utf8_text,
                               const char* tokenizer_options,
                               udpipe_doc_view* out_doc);

#ifdef __cplusplus
}
#endif
