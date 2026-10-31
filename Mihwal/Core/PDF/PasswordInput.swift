import Foundation

enum PasswordInput {
    /// What the user typed, plus the same text with Arabic-Indic (٠١٢٣) and Persian (۰۱۲۳)
    /// digits turned into 0–9. On an Arabic keyboard "1111" is typed as "١١١١", which is a
    /// different password to the PDF, so both are tried.
    static func candidates(_ typed: String) -> [String] {
        let western = String(String.UnicodeScalarView(typed.unicodeScalars.map { scalar in
            switch scalar.value {
            case 0x0660...0x0669: return Unicode.Scalar(0x30 + scalar.value - 0x0660) ?? scalar
            case 0x06F0...0x06F9: return Unicode.Scalar(0x30 + scalar.value - 0x06F0) ?? scalar
            default: return scalar
            }
        }))
        return western == typed ? [typed] : [typed, western]
    }
}
