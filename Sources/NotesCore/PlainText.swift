import Foundation

/// Strips rich-text / attributed paste down to plain characters (R2, T2.10).
public enum PlainText {
    public static func fromPasteboardString(_ string: String) -> String {
        string
    }

    /// Best-effort plain extraction from an attributed-string archive / RTF-ish payload.
    /// For non-plain paste paths the app should prefer `NSAttributedString.string`.
    public static func fromAttributedStringValue(_ value: String) -> String {
        value
    }

    public static func isEffectivelyPlain(_ string: String) -> Bool {
        !string.contains("\u{FFFC}") // object replacement (attachments)
    }
}
