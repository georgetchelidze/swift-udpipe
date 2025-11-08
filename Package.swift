// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-udpipe",
    products: [
        .library(
            name: "UDPipe",
            targets: ["UDPipe"]
        ),
    ],
    targets: [
        // Core C++ library from vendored UDPipe sources
        .target(
            name: "UDPipeCore",
            path: "Vendors/udpipe/src",
            sources: [
                "parsito/tree/tree.cpp",
                "parsito/tree/tree_format.cpp",
                "parsito/tree/tree_format_conllu.cpp",
                "parsito/transition/transition_system.cpp",
                "parsito/transition/transition.cpp",
                "parsito/transition/transition_system_projective.cpp",
                "parsito/transition/transition_system_swap.cpp",
                "parsito/transition/transition_system_link2.cpp",
                "parsito/configuration/node_extractor.cpp",
                "parsito/configuration/value_extractor.cpp",
                "parsito/configuration/configuration.cpp",
                "parsito/network/neural_network.cpp",
                "parsito/network/neural_network_trainer.cpp",
                "parsito/embedding/embedding.cpp",
                "parsito/embedding/embedding_encode.cpp",
                "parsito/parser/parser_nn.cpp",
                "parsito/parser/parser_nn_trainer.cpp",
                "parsito/parser/parser.cpp",
                "parsito/version/version.cpp",
                "tokenizer/multiword_splitter_trainer.cpp",
                "tokenizer/morphodita_tokenizer_wrapper.cpp",
                "tokenizer/multiword_splitter.cpp",
                "tokenizer/detokenizer.cpp",
                "utils/compressor_save.cpp",
                "utils/options.cpp",
                "utils/url_detector.cpp",
                "utils/win_wmain_utf8.cpp",
                "utils/compressor_load.cpp",
                "morphodita/tagset_converter/tagset_converter.cpp",
                "morphodita/tagset_converter/identity_tagset_converter.cpp",
                "morphodita/tagset_converter/strip_lemma_comment_tagset_converter.cpp",
                "morphodita/tagset_converter/strip_lemma_id_tagset_converter.cpp",
                "morphodita/tagset_converter/pdt_to_conll2009_tagset_converter.cpp",
                "morphodita/morpho/tag_filter.cpp",
                "morphodita/morpho/czech_morpho.cpp",
                "morphodita/morpho/raw_morpho_dictionary_reader.cpp",
                "morphodita/morpho/english_morpho_encoder.cpp",
                "morphodita/morpho/english_morpho_guesser_encoder.cpp",
                "morphodita/morpho/external_morpho.cpp",
                "morphodita/morpho/external_morpho_encoder.cpp",
                "morphodita/morpho/morpho.cpp",
                "morphodita/morpho/generic_morpho_encoder.cpp",
                "morphodita/morpho/english_morpho_guesser.cpp",
                "morphodita/morpho/morpho_statistical_guesser_encoder.cpp",
                "morphodita/morpho/morpho_statistical_guesser.cpp",
                "morphodita/morpho/morpho_statistical_guesser_trainer.cpp",
                "morphodita/morpho/generic_morpho.cpp",
                "morphodita/morpho/morpho_prefix_guesser_encoder.cpp",
                "morphodita/morpho/english_morpho.cpp",
                "morphodita/morpho/czech_morpho_encoder.cpp",
                "morphodita/tokenizer/generic_tokenizer_factory.cpp",
                "morphodita/tokenizer/generic_tokenizer_factory_encoder.cpp",
                "morphodita/tokenizer/english_tokenizer.cpp",
                "morphodita/tokenizer/gru_tokenizer.cpp",
                "morphodita/tokenizer/vertical_tokenizer.cpp",
                "morphodita/tokenizer/gru_tokenizer_network.cpp",
                "morphodita/tokenizer/generic_tokenizer.cpp",
                "morphodita/tokenizer/unicode_tokenizer.cpp",
                "morphodita/tokenizer/tokenizer.cpp",
                "morphodita/tokenizer/gru_tokenizer_trainer.cpp",
                "morphodita/tokenizer/gru_tokenizer_factory.cpp",
                "morphodita/tokenizer/czech_tokenizer_factory.cpp",
                "morphodita/tokenizer/czech_tokenizer_factory_encoder.cpp",
                "morphodita/tokenizer/czech_tokenizer.cpp",
                "morphodita/tokenizer/tokenizer_factory.cpp",
                "morphodita/tokenizer/ragel_tokenizer.cpp",
                // Include runtime derivator dictionary (used by morpho), but exclude encoder (training-only)
                "morphodita/derivator/derivator_dictionary.cpp",
                "morphodita/version/version.cpp",
                "morphodita/tagger/tagger.cpp",
                "sentence/sentence.cpp",
                "sentence/output_format.cpp",
                "sentence/input_format.cpp",
                "sentence/token.cpp",
                "version/version.cpp",
                "unilib/unistrip.cpp",
                "unilib/version.cpp",
                "unilib/uninorms.cpp",
                "unilib/utf16.cpp",
                "unilib/utf8.cpp",
                "unilib/unicode.cpp",
                "model/pipeline.cpp",
                "model/evaluator.cpp",
                "model/model.cpp",
                "model/model_morphodita_parsito.cpp",
                "trainer/trainer.cpp",
                "trainer/trainer_morphodita_parsito.cpp",
                "trainer/training_failure.cpp",
            ],
            publicHeadersPath: ".",
            cxxSettings: [
                .define("UDPIPE_STATIC"),
                .unsafeFlags(["-std=c++17"]),
                .headerSearchPath("."),
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        ),

        .target(
            name: "UDPipeCLib",
            dependencies: ["UDPipeCore"],
            path: "Sources/UDPipeCLib",
            sources: [
                "udpipe_wrapper.cpp"
            ],
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("../../Vendors/udpipe/src_lib_only"),
                .define("UDPIPE_STATIC"),
                .unsafeFlags(["-std=c++17"])
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        ),

        .target(
            name: "UDPipe",
            dependencies: ["UDPipeCLib"],
            path: "Sources/UDPipe"
        ),

        .testTarget(
            name: "UDPipeTests",
            dependencies: ["UDPipe"],
            path: "Tests/UDPipeTests"
        ),
    ]
)
