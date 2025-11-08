#include "udpipe_wrapper.h"

#include <memory>
#include <sstream>
#include <string>
#include <vector>
#include <cstring>
#include <cstdlib>
#include <thread>
#include <atomic>

using namespace ufal::udpipe;

// A simple arena for allocating many small strings efficiently.
// This avoids the overhead of calling malloc for every single token feature.
class StringArena {
    // We allocate memory in blocks.
    std::vector<char*> blocks_;
    // Current block and allocation pointer.
    char* current_block_ = nullptr;
    size_t current_offset_ = 0;
    size_t block_size_ = 0;

    static constexpr size_t DEFAULT_BLOCK_SIZE = 8192;

public:
    StringArena(size_t block_size = DEFAULT_BLOCK_SIZE) : block_size_(block_size) {}

    ~StringArena() {
        for (char* block : blocks_) {
            std::free(block);
        }
    }

    // No copy/move semantics for simplicity
    StringArena(const StringArena&) = delete;
    StringArena& operator=(const StringArena&) = delete;

    char* allocate(const std::string& s) {
        size_t required = s.length() + 1;
        // Align to pointer size for safety on some architectures, though not strictly necessary for char.
        const size_t align = sizeof(void*);
        if ((current_offset_ % align) != 0) {
            current_offset_ += align - (current_offset_ % align);
        }

        if (current_block_ == nullptr || (current_offset_ + required) > block_size_) {
            size_t new_block_size = std::max(block_size_, required);
            current_block_ = static_cast<char*>(std::malloc(new_block_size));
            if (!current_block_) {
                // Fallback for allocation failure.
                static char empty_str[] = "";
                return empty_str;
            }
            blocks_.push_back(current_block_);
            current_offset_ = 0;
            block_size_ = new_block_size;
        }

        char* ptr = current_block_ + current_offset_;
        std::memcpy(ptr, s.c_str(), s.length() + 1);
        current_offset_ += required;
        return ptr;
    }

    // Allocate an empty C-string
    char* allocate_empty() {
        return allocate("");
    }
};

extern "C" const char* udpipe_version(void) {
    static std::string v;
    if (v.empty()) {
        auto ver = version::current();
        v = std::to_string(ver.major) + "." + std::to_string(ver.minor) + "." + std::to_string(ver.patch) +
            (ver.prerelease.empty() ? std::string() : std::string("-") + ver.prerelease);
    }
    return v.c_str();
}

extern "C" udpipe_model_t udpipe_model_load(const char* model_path) {
    if (!model_path) return nullptr;
    model* m = model::load(model_path);
    return static_cast<udpipe_model_t>(m);
}

extern "C" void udpipe_model_free(udpipe_model_t handle) {
    if (!handle) return;
    model* m = static_cast<model*>(handle);
    delete m;
}

extern "C" char* udpipe_tag_conllu(udpipe_model_t handle, const char* utf8_text) {
    if (!handle || !utf8_text) return nullptr;

    model* m = static_cast<model*>(handle);

    // Set up a pipeline: input via tokenizer, tagging only, CoNLL-U output
    pipeline p(m, /*input*/ "tokenizer", /*tagger*/ model::DEFAULT, /*parser*/ pipeline::NONE, /*output*/ "conllu");
    p.set_immediate(true);

    std::istringstream is(utf8_text);
    std::ostringstream os;
    std::string error;
    bool ok = p.process(is, os, error);
    std::string result_str = ok ? os.str() : (std::string("ERROR: ") + error);
    char* out = static_cast<char*>(std::malloc(result_str.size() + 1));
    if (!out) return nullptr;
    std::memcpy(out, result_str.c_str(), result_str.size() + 1);
    return out;
}

extern "C" void udpipe_string_free(char* p) {
    std::free(p);
}

extern "C" int udpipe_tag_structured(udpipe_model_t handle, const char* utf8_text, int do_parse,
                                      udpipe_doc_view* out_doc) {
    if (!handle || !utf8_text || !out_doc) return 0;
    out_doc->sentences = nullptr;
    out_doc->count = 0;
    out_doc->arena = nullptr;

    auto arena = new StringArena();
    out_doc->arena = arena;

    model* m = static_cast<model*>(handle);

    // Set up tokenizer input; we'll manually step sentences to access structures.
    std::unique_ptr<input_format> reader(m->new_tokenizer(""));
    if (!reader) return 0;
    reader->reset_document("");
    reader->set_text(utf8_text);

    std::vector<udpipe_sentence_view> sentences;
    sentence s;
    std::string error;
    while (reader->next_sentence(s, error)) {
        if (!error.empty()) { break; }
        // Run tagger and optionally parser
        if (!m->tag(s, model::DEFAULT, error)) { break; }
        if (do_parse) {
            if (!m->parse(s, model::DEFAULT, error)) { break; }
        }

        std::vector<udpipe_token> toks;
        toks.reserve(s.words.size());
        for (const auto& w : s.words) {
            if (w.id <= 0) continue; // skip non-words
            udpipe_token t{};
            t.id = w.id;
            t.head = w.head;
            t.form = arena->allocate(w.form);
            t.lemma = arena->allocate(w.lemma);
            t.upos = arena->allocate(w.upostag);
            t.xpostag = arena->allocate(w.xpostag);
            t.feats = arena->allocate(w.feats);
            t.deprel = arena->allocate(w.deprel);
            size_t start = 0, end = 0;
            if (w.get_token_range(start, end)) { t.start = start; t.end = end; }
            else { t.start = 0; t.end = 0; }
            toks.push_back(t);
        }
        // Allocate C array for tokens
        udpipe_sentence_view view{};
        view.count = toks.size();
        view.tokens = (udpipe_token*)std::malloc(sizeof(udpipe_token) * view.count);
        if (!view.tokens) { error = "alloc failure"; break; }
        std::memcpy(view.tokens, toks.data(), sizeof(udpipe_token) * view.count);
        sentences.push_back(view);

        s.clear();
    }

    if (!error.empty()) {
        // free partial allocations
        udpipe_doc_view tmp{sentences.data(), sentences.size()};
        udpipe_free_doc(&tmp);
        return 0;
    }

    // Allocate sentences array to return
    out_doc->count = sentences.size();
    out_doc->sentences = (udpipe_sentence_view*)std::malloc(sizeof(udpipe_sentence_view) * out_doc->count);
    if (!out_doc->sentences) {
        out_doc->count = 0; return 0;
    }
    std::memcpy(out_doc->sentences, sentences.data(), sizeof(udpipe_sentence_view) * out_doc->count);
    return 1;
}

extern "C" void udpipe_free_doc(udpipe_doc_view* doc) {
    if (!doc) return;

    // The arena owns all the string data. Freeing the arena frees the strings.
    if (doc->arena) {
        delete static_cast<StringArena*>(doc->arena);
    }

    // The doc owns the sentence_view array, and each sentence_view owns its token array.
    if (doc->sentences) {
        for (size_t i = 0; i < doc->count; ++i) {
            udpipe_sentence_view& sv = doc->sentences[i];
            if (sv.tokens) {
                std::free(sv.tokens);
            }
        }
        std::free(doc->sentences);
    }

    doc->sentences = nullptr;
    doc->count = 0;
    doc->arena = nullptr;
}

extern "C" int udpipe_tokenize_structured(udpipe_model_t handle, const char* utf8_text,
                                          const char* tokenizer_options,
                                          udpipe_doc_view* out_doc) {
    if (!handle || !utf8_text || !out_doc) return 0;
    out_doc->sentences = nullptr;
    out_doc->count = 0;
    out_doc->arena = nullptr;

    auto arena = new StringArena();
    out_doc->arena = arena;

    model* m = static_cast<model*>(handle);
    const char* opts = tokenizer_options ? tokenizer_options : "";

    std::unique_ptr<input_format> reader(m->new_tokenizer(opts));
    if (!reader) return 0;
    reader->reset_document("");
    reader->set_text(utf8_text);

    std::vector<udpipe_sentence_view> sentences;
    sentence s;
    std::string error;
    while (reader->next_sentence(s, error)) {
        if (!error.empty()) { break; }

        std::vector<udpipe_token> toks;
        toks.reserve(s.words.size());
        for (const auto& w : s.words) {
            if (w.id <= 0) continue; // skip non-words
            udpipe_token t{};
            t.id = w.id;
            t.head = -1;
            t.form = arena->allocate(w.form);
            t.lemma = arena->allocate_empty();
            t.upos = arena->allocate_empty();
            t.xpostag = arena->allocate_empty();
            t.feats = arena->allocate_empty();
            t.deprel = arena->allocate_empty();
            size_t start = 0, end = 0;
            if (w.get_token_range(start, end)) { t.start = start; t.end = end; }
            else { t.start = 0; t.end = 0; }
            toks.push_back(t);
        }
        udpipe_sentence_view view{};
        view.count = toks.size();
        view.tokens = (udpipe_token*)std::malloc(sizeof(udpipe_token) * view.count);
        if (!view.tokens) { error = "alloc failure"; break; }
        std::memcpy(view.tokens, toks.data(), sizeof(udpipe_token) * view.count);
        sentences.push_back(view);

        s.clear();
    }

    if (!error.empty()) {
        udpipe_doc_view tmp{sentences.data(), sentences.size()};
        udpipe_free_doc(&tmp);
        return 0;
    }

    out_doc->count = sentences.size();
    out_doc->sentences = (udpipe_sentence_view*)std::malloc(sizeof(udpipe_sentence_view) * out_doc->count);
    if (!out_doc->sentences) { out_doc->count = 0; return 0; }
    std::memcpy(out_doc->sentences, sentences.data(), sizeof(udpipe_sentence_view) * out_doc->count);
    return 1;
}

extern "C" int udpipe_tag_batch(udpipe_model_t handle, const char** utf8_texts, size_t batch_size, int do_parse,
                                 udpipe_doc_view** out_docs, size_t* out_size) {
    if (!handle || !utf8_texts || !out_docs || !out_size) return 0;
    *out_docs = nullptr;
    *out_size = 0;

    model* m = static_cast<model*>(handle);

    std::vector<udpipe_doc_view> results(batch_size);
    std::atomic<size_t> next_index(0);
    std::atomic<bool> success_flag(true);

    unsigned int num_threads = std::thread::hardware_concurrency();
    if (num_threads == 0) num_threads = 1;
    if (num_threads > batch_size) num_threads = (unsigned int)batch_size;

    std::vector<std::thread> threads;
    threads.reserve(num_threads);

    for (unsigned int i = 0; i < num_threads; ++i) {
        threads.emplace_back([&]() {
            while (success_flag) { // Stop if any thread has failed
                size_t current_index = next_index.fetch_add(1);
                if (current_index >= batch_size) break;

                udpipe_doc_view* doc = &results[current_index];
                doc->sentences = nullptr;
                doc->count = 0;
                doc->arena = nullptr;
                const char* text = utf8_texts[current_index];
                bool current_success = true;

                auto arena = new StringArena();
                doc->arena = arena;

                std::unique_ptr<input_format> reader(m->new_tokenizer(""));
                if (!reader) {
                    success_flag = false;
                    continue;
                }
                reader->reset_document("");
                reader->set_text(text);

                std::vector<udpipe_sentence_view> sentences;
                sentence s;
                std::string error;
                while (reader->next_sentence(s, error)) {
                    if (!error.empty()) { current_success = false; break; }
                    if (!m->tag(s, model::DEFAULT, error)) { current_success = false; break; }
                    if (do_parse) {
                        if (!m->parse(s, model::DEFAULT, error)) { current_success = false; break; }
                    }

                    std::vector<udpipe_token> toks;
                    toks.reserve(s.words.size());
                    for (const auto& w : s.words) {
                        if (w.id <= 0) continue;
                        udpipe_token t{};
                        t.id = w.id;
                        t.head = w.head;
                        t.form = arena->allocate(w.form);
                        t.lemma = arena->allocate(w.lemma);
                        t.upos = arena->allocate(w.upostag);
                        t.xpostag = arena->allocate(w.xpostag);
                        t.feats = arena->allocate(w.feats);
                        t.deprel = arena->allocate(w.deprel);
                        size_t start = 0, end = 0;
                        if (w.get_token_range(start, end)) { t.start = start; t.end = end; }
                        toks.push_back(t);
                    }
                    udpipe_sentence_view view{};
                    view.count = toks.size();
                    view.tokens = (udpipe_token*)std::malloc(sizeof(udpipe_token) * view.count);
                    if (!view.tokens) { error = "alloc failure"; current_success = false; break; }
                    std::memcpy(view.tokens, toks.data(), sizeof(udpipe_token) * view.count);
                    sentences.push_back(view);
                    s.clear();
                }

                if (!error.empty()) { current_success = false; }

                if (!current_success) {
                    success_flag = false;
                    udpipe_doc_view tmp{sentences.data(), sentences.size()};
                    udpipe_free_doc(&tmp);
                    continue;
                }

                doc->count = sentences.size();
                doc->sentences = (udpipe_sentence_view*)std::malloc(sizeof(udpipe_sentence_view) * doc->count);
                if (!doc->sentences) {
                    doc->count = 0;
                    success_flag = false;
                    udpipe_doc_view tmp{sentences.data(), sentences.size()};
                    udpipe_free_doc(&tmp);
                    continue;
                }
                std::memcpy(doc->sentences, sentences.data(), sizeof(udpipe_sentence_view) * doc->count);
            }
        });
    }

    for (auto& t : threads) {
        t.join();
    }

    if (!success_flag) {
        for(size_t i = 0; i < results.size(); ++i) {
            udpipe_free_doc(&results[i]);
        }
        return 0;
    }

    *out_size = results.size();
    *out_docs = (udpipe_doc_view*)std::malloc(sizeof(udpipe_doc_view) * *out_size);
    if (!*out_docs) {
        for(size_t i = 0; i < results.size(); ++i) {
            udpipe_free_doc(&results[i]);
        }
        *out_size = 0;
        return 0;
    }
    std::memcpy(*out_docs, results.data(), sizeof(udpipe_doc_view) * *out_size);

    return 1;
}

extern "C" void udpipe_free_batch(udpipe_doc_view* docs, size_t batch_size) {
    if (!docs) return;
    for (size_t i = 0; i < batch_size; ++i) {
        udpipe_free_doc(&docs[i]);
    }
    std::free(docs);
}
