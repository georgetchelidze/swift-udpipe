public extension UDPipe {
    /// Represents the Universal Dependency relation labels (`deprel`).
    ///
    /// These labels define the grammatical relationship between a dependent token and its head.
    enum Deprel: String, Sendable {
        // A list of common dependency relations from the Universal Dependencies standard.
        case root, nsubj, csubj, obj, iobj, ccomp, xcomp, obl, vocative, expl, dislocated, advcl, advmod, discourse, aux, cop, mark, nmod, appos, nummod, amod, acl, det, `case`, cc, conj, fixed, flat, compound, list, orphan, goeswith, reparandum, parataxis, punct, dep

        /// Represents a dependency relation not specifically covered by the other cases.
        case other

        /// Parses a raw string into a `Deprel` enum case.
        ///
        /// - Parameter s: The string representation of the dependency relation.
        /// - Returns: The corresponding `Deprel` case, or `.other` if no match is found.
        static func parse(_ s: String) -> Deprel { Deprel(rawValue: s) ?? .other }
    }
}
