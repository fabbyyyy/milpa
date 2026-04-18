import SwiftUI

/// Renders a string as Markdown using AttributedString.
/// Falls back to plain text if parsing fails.
struct MarkdownText: View {
    let text: String
    let font: Font
    let foregroundColor: Color
    
    init(_ text: String, font: Font = MilpaFont.sans(15), foregroundColor: Color = MilpaColor.ink) {
        self.text = text
        self.font = font
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(font)
                .foregroundStyle(foregroundColor)
                .lineSpacing(3)
                .tint(MilpaColor.greenD)
        } else {
            Text(text)
                .font(font)
                .foregroundStyle(foregroundColor)
                .lineSpacing(3)
        }
    }
}
