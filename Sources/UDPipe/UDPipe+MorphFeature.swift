public extension UDPipe {
    /// Represents a single morphological feature from the `FEATS` column in CoNLL-U format.
    ///
    /// Morphological features describe the specific grammatical properties of a token.
    enum MorphFeature: Equatable, Sendable {
        // Each of these nested enums represents a specific category of morphological feature.
        public enum Number: String, Sendable { case singular = "Sing", plural = "Plur", dual = "Dual", other }
        public enum Gender: String, Sendable { case masculine = "Masc", feminine = "Fem", neuter = "Neut", common = "Com", other }
        public enum CaseFeature: String, Sendable { case nom = "Nom", acc = "Acc", gen = "Gen", dat = "Dat", loc = "Loc", ins = "Ins", voc = "Voc", abl = "Abl", all = "All", ess = "Ess", ill = "Ill", ine = "Ine", lat = "Lat", other }
        public enum Tense: String, Sendable { case past = "Past", pres = "Pres", fut = "Fut", imp = "Imp", pqp = "Pqp", other }
        public enum Person: String, Sendable { case p1 = "1", p2 = "2", p3 = "3", other }
        public enum Mood: String, Sendable { case ind = "Ind", imp = "Imp", cnd = "Cnd", sbj = "Sub", opt = "Opt", other }
        public enum VerbForm: String, Sendable { case fin = "Fin", inf = "Inf", ger = "Ger", part = "Part", conv = "Conv", sup = "Sup", other }
        public enum Definite: String, Sendable { case def = "Def", ind = "Ind", cons = "Cons", spec = "Spec", other }
        public enum PronType: String, Sendable { case art = "Art", dem = "Dem", emp = "Emp", ind = "Ind", int = "Int", neg = "Neg", prn = "Prs", rel = "Rel", tot = "Tot", other }
        public enum Degree: String, Sendable { case pos = "Pos", cmp = "Cmp", sup = "Sup", abs = "Abs", other }
        public enum Animacy: String, Sendable { case anim = "Anim", inan = "Inan", hum = "Hum", nhum = "Nhum", other }
        public enum Polarity: String, Sendable { case pos = "Pos", neg = "Neg", other }

        // The main enum cases, which associate a feature category with its value.
        case number(Number)
        case gender(Gender)
        case grammaticalCase(CaseFeature)
        case tense(Tense)
        case person(Person)
        case mood(Mood)
        case verbForm(VerbForm)
        case definite(Definite)
        case pronType(PronType)
        case degree(Degree)
        case animacy(Animacy)
        case polarity(Polarity)
        /// A feature that doesn't match any of the strongly-typed cases.
        case other(name: String, value: String)
    }

    /// Parses a UD `FEATS` string into an array of typed `MorphFeature`s. This is an internal helper.
    static func parseFeatures(_ feats: String) -> [MorphFeature] {
        if feats.isEmpty || feats == "_" { return [] }
        var out: [MorphFeature] = []
        for pair in feats.split(separator: "|") {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2 else { continue }
            let key = String(kv[0])
            let val = String(kv[1])
            switch key {
            case "Number":
                switch val { case "Sing": out.append(.number(.singular)); case "Plur": out.append(.number(.plural)); case "Dual": out.append(.number(.dual)); default: out.append(.number(.other)) }
            case "Gender":
                switch val { case "Masc": out.append(.gender(.masculine)); case "Fem": out.append(.gender(.feminine)); case "Neut": out.append(.gender(.neuter)); case "Com": out.append(.gender(.common)); default: out.append(.gender(.other)) }
            case "Case":
                switch val { case "Nom": out.append(.grammaticalCase(.nom)); case "Acc": out.append(.grammaticalCase(.acc)); case "Gen": out.append(.grammaticalCase(.gen)); case "Dat": out.append(.grammaticalCase(.dat)); case "Loc": out.append(.grammaticalCase(.loc)); case "Ins": out.append(.grammaticalCase(.ins)); case "Voc": out.append(.grammaticalCase(.voc)); case "Abl": out.append(.grammaticalCase(.abl)); case "All": out.append(.grammaticalCase(.all)); case "Ess": out.append(.grammaticalCase(.ess)); case "Ill": out.append(.grammaticalCase(.ill)); case "Ine": out.append(.grammaticalCase(.ine)); case "Lat": out.append(.grammaticalCase(.lat)); default: out.append(.grammaticalCase(.other)) }
            case "Tense":
                switch val { case "Past": out.append(.tense(.past)); case "Pres": out.append(.tense(.pres)); case "Fut": out.append(.tense(.fut)); case "Imp": out.append(.tense(.imp)); case "Pqp": out.append(.tense(.pqp)); default: out.append(.tense(.other)) }
            case "Person":
                switch val { case "1": out.append(.person(.p1)); case "2": out.append(.person(.p2)); case "3": out.append(.person(.p3)); default: out.append(.person(.other)) }
            case "Mood":
                switch val { case "Ind": out.append(.mood(.ind)); case "Imp": out.append(.mood(.imp)); case "Cnd": out.append(.mood(.cnd)); case "Sub": out.append(.mood(.sbj)); case "Opt": out.append(.mood(.opt)); default: out.append(.mood(.other)) }
            case "VerbForm":
                switch val { case "Fin": out.append(.verbForm(.fin)); case "Inf": out.append(.verbForm(.inf)); case "Ger": out.append(.verbForm(.ger)); case "Part": out.append(.verbForm(.part)); case "Conv": out.append(.verbForm(.conv)); case "Sup": out.append(.verbForm(.sup)); default: out.append(.verbForm(.other)) }
            case "Definite":
                switch val { case "Def": out.append(.definite(.def)); case "Ind": out.append(.definite(.ind)); case "Cons": out.append(.definite(.cons)); case "Spec": out.append(.definite(.spec)); default: out.append(.definite(.other)) }
            case "PronType":
                switch val { case "Art": out.append(.pronType(.art)); case "Dem": out.append(.pronType(.dem)); case "Emp": out.append(.pronType(.emp)); case "Ind": out.append(.pronType(.ind)); case "Int": out.append(.pronType(.int)); case "Neg": out.append(.pronType(.neg)); case "Prs": out.append(.pronType(.prn)); case "Rel": out.append(.pronType(.rel)); case "Tot": out.append(.pronType(.tot)); default: out.append(.pronType(.other)) }
            case "Degree":
                switch val { case "Pos": out.append(.degree(.pos)); case "Cmp": out.append(.degree(.cmp)); case "Sup": out.append(.degree(.sup)); case "Abs": out.append(.degree(.abs)); default: out.append(.degree(.other)) }
            case "Animacy":
                switch val { case "Anim": out.append(.animacy(.anim)); case "Inan": out.append(.animacy(.inan)); case "Hum": out.append(.animacy(.hum)); case "Nhum": out.append(.animacy(.nhum)); default: out.append(.animacy(.other)) }
            case "Polarity":
                switch val { case "Pos": out.append(.polarity(.pos)); case "Neg": out.append(.polarity(.neg)); default: out.append(.polarity(.other)) }
            default:
                out.append(MorphFeature.other(name: key, value: val))
            }
        }
        return out
    }
}
