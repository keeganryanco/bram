import SwiftUI
import UIKit

struct WorkoutNoteEditor: View {
    @Binding var noteBody: String
    let interpretedLines: [InterpretedWorkoutLine]
    let interpretationEnabled: Bool
    let onSelectExercise: (ExerciseAnchor) -> Void
    let onSelectCardio: (CardioEntry) -> Void
    @Binding var isEditing: Bool
    @State private var editorHeight: CGFloat = 250

    init(
        noteBody: Binding<String>,
        interpretedLines: [InterpretedWorkoutLine],
        interpretationEnabled: Bool,
        onSelectExercise: @escaping (ExerciseAnchor) -> Void,
        onSelectCardio: @escaping (CardioEntry) -> Void = { _ in },
        isEditing: Binding<Bool> = .constant(false)
    ) {
        _noteBody = noteBody
        self.interpretedLines = interpretedLines
        self.interpretationEnabled = interpretationEnabled
        self.onSelectExercise = onSelectExercise
        self.onSelectCardio = onSelectCardio
        _isEditing = isEditing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .topTrailing) {
                editableField

                if interpretationEnabled {
                    InlineWorkoutBadgeOverlay(
                        noteBody: noteBody,
                        interpretedLines: interpretedLines
                    )
                    .padding(.top, 20)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private var editableField: some View {
        ZStack(alignment: .topLeading) {
            if noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Write what you did.")
                    .font(BramFont.body(size: 20))
                    .foregroundStyle(BramColor.textTertiary.opacity(0.72))
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }

            WorkoutNoteTextView(
                text: $noteBody,
                interpretedLines: interpretationEnabled ? interpretedLines : [],
                dynamicHeight: $editorHeight,
                isEditing: $isEditing,
                onSelectExercise: onSelectExercise,
                onSelectCardio: onSelectCardio
            )
            .frame(minHeight: 250)
            .frame(height: max(250, editorHeight))
            .padding(.trailing, 76)
            .accessibilityLabel("Workout note")
        }
        .padding(.top, 20)
    }
}

private struct InlineWorkoutBadgeOverlay: View {
    let noteBody: String
    let interpretedLines: [InterpretedWorkoutLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(noteLines.enumerated()), id: \.offset) { index, line in
                InlineWorkoutBadgeLine(
                    rawLine: line,
                    interpretedLine: interpretedLine(for: index)
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
    }

    private var noteLines: [String] {
        noteBody.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func interpretedLine(for index: Int) -> InterpretedWorkoutLine? {
        interpretedLines.first { $0.lineIndex == index }
    }
}

private struct InlineWorkoutBadgeLine: View {
    let rawLine: String
    let interpretedLine: InterpretedWorkoutLine?

    var body: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 8)
            if let badges = interpretedLine?.badges, !badges.isEmpty {
                ForEach(badges) { badge in
                    WorkoutLineBadgeView(badge: badge)
                }
            }
        }
        .frame(height: rawLine.isEmpty ? 28 : 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorkoutNoteTextView: UIViewRepresentable {
    @Binding var text: String
    let interpretedLines: [InterpretedWorkoutLine]
    @Binding var dynamicHeight: CGFloat
    @Binding var isEditing: Bool
    let onSelectExercise: (ExerciseAnchor) -> Void
    let onSelectCardio: (CardioEntry) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.tintColor = .bramViolet
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applyTypingAttributes(to: textView, traitCollection: textView.traitCollection)

        let exerciseDoubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleExerciseDoubleTap(_:)))
        exerciseDoubleTap.numberOfTapsRequired = 2
        exerciseDoubleTap.cancelsTouchesInView = false
        textView.addGestureRecognizer(exerciseDoubleTap)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        let renderSignature = Self.renderSignature(
            interpretedLines: interpretedLines,
            traitCollection: textView.traitCollection
        )
        applyTypingAttributes(to: textView, traitCollection: textView.traitCollection)

        if textView.markedTextRange == nil,
           textView.text != text {
            applyAttributedText(
                to: textView,
                coordinator: context.coordinator,
                renderSignature: renderSignature
            )
        } else if textView.markedTextRange == nil,
                  context.coordinator.lastRenderSignature != renderSignature {
            applyAttributedText(
                to: textView,
                coordinator: context.coordinator,
                renderSignature: renderSignature
            )
        }

        recalculateHeight(textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func makeAttributedText(
        text: String,
        interpretedLines: [InterpretedWorkoutLine],
        traitCollection: UITraitCollection,
        coordinator: Coordinator
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.bramBody(size: 20),
                .foregroundColor: UIColor.bramTextPrimary(for: traitCollection),
                .paragraphStyle: paragraphStyle
            ]
        )
        coordinator.anchorRanges = []
        coordinator.cardioRanges = []

        for interpretedLine in interpretedLines {
            if let cardioEntry = interpretedLine.cardioEntry,
               let lineRange = nsRangeForLine(index: interpretedLine.lineIndex, in: text),
               let cardioRange = tappableLineRange(in: text, lineRange: lineRange) {
                attributed.addAttributes(
                    [
                        .foregroundColor: UIColor.bramTextPrimary(for: traitCollection),
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .underlineColor: UIColor.systemBlue.withAlphaComponent(0.36)
                    ],
                    range: cardioRange
                )
                coordinator.cardioRanges.append((range: cardioRange, entry: cardioEntry))
            }

            guard let anchor = interpretedLine.exerciseAnchor,
                  let lineRange = nsRangeForLine(index: interpretedLine.lineIndex, in: text),
                  let anchorRange = anchorRange(in: text, lineRange: lineRange, interpretedLine: interpretedLine)
            else { continue }

            attributed.addAttributes(
                [
                    .foregroundColor: UIColor.bramTextPrimary(for: traitCollection),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: UIColor.bramViolet.withAlphaComponent(0.48)
                ],
                range: anchorRange
            )
            coordinator.anchorRanges.append((range: anchorRange, anchor: anchor))
        }

        return attributed
    }

    private func applyAttributedText(
        to textView: UITextView,
        coordinator: Coordinator,
        renderSignature: String
    ) {
        let selectedRange = textView.selectedRange
        let wasFirstResponder = textView.isFirstResponder
        let attributedText = makeAttributedText(
            text: text,
            interpretedLines: interpretedLines,
            traitCollection: textView.traitCollection,
            coordinator: coordinator
        )

        guard textView.attributedText != attributedText else {
            coordinator.lastRenderedText = text
            coordinator.lastRenderSignature = renderSignature
            return
        }

        coordinator.isUpdatingText = true
        textView.attributedText = attributedText
        applyTypingAttributes(to: textView, traitCollection: textView.traitCollection)
        if wasFirstResponder, selectedRange.location <= textView.text.utf16.count {
            textView.selectedRange = selectedRange
        }
        coordinator.lastRenderedText = text
        coordinator.lastRenderSignature = renderSignature
        coordinator.isUpdatingText = false
    }

    private func applyTypingAttributes(to textView: UITextView, traitCollection: UITraitCollection) {
        textView.typingAttributes = [
            .font: UIFont.bramBody(size: 20),
            .foregroundColor: UIColor.bramTextPrimary(for: traitCollection),
            .paragraphStyle: paragraphStyle
        ]
    }

    private static func renderSignature(
        interpretedLines: [InterpretedWorkoutLine],
        traitCollection: UITraitCollection
    ) -> String {
        let lineSignature = interpretedLines.map { line in
            let anchor = line.exerciseAnchor?.displayName ?? ""
            let cardio = line.cardioEntry?.activityType ?? ""
            let badges = line.badges.map(\.label).joined(separator: ",")
            return "\(line.lineIndex):\(line.rawText):\(anchor):\(cardio):\(badges)"
        }
        .joined(separator: "|")
        return "\(traitCollection.userInterfaceStyle.rawValue):\(lineSignature)"
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        style.paragraphSpacing = 0
        return style
    }

    private func nsRangeForLine(index targetIndex: Int, in text: String) -> NSRange? {
        var location = 0
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for (index, line) in lines.enumerated() {
            let length = (line as NSString).length
            if index == targetIndex {
                return NSRange(location: location, length: length)
            }
            location += length + 1
        }
        return nil
    }

    private func anchorRange(
        in text: String,
        lineRange: NSRange,
        interpretedLine: InterpretedWorkoutLine
    ) -> NSRange? {
        let nsText = text as NSString
        let lineText = nsText.substring(with: lineRange)
        let trimmedLine = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else { return nil }

        let anchorText = interpretedLine.segments.first { $0.kind == .exerciseAnchor }?.text
            ?? interpretedLine.exerciseAnchor?.displayName
            ?? trimmedLine
        let foundRange = (lineText as NSString).range(
            of: anchorText,
            options: [.caseInsensitive, .diacriticInsensitive]
        )

        if foundRange.location != NSNotFound {
            return NSRange(location: lineRange.location + foundRange.location, length: foundRange.length)
        }

        let leadingWhitespaceLength = lineText.prefix { $0.isWhitespace }.reduce(0) { count, character in
            count + String(character).utf16.count
        }
        return NSRange(
            location: lineRange.location + leadingWhitespaceLength,
            length: (trimmedLine as NSString).length
        )
    }

    private func tappableLineRange(in text: String, lineRange: NSRange) -> NSRange? {
        let nsText = text as NSString
        let lineText = nsText.substring(with: lineRange)
        let trimmedLine = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else { return nil }
        let leadingWhitespaceLength = lineText.prefix { $0.isWhitespace }.reduce(0) { count, character in
            count + String(character).utf16.count
        }
        return NSRange(
            location: lineRange.location + leadingWhitespaceLength,
            length: (trimmedLine as NSString).length
        )
    }

    private func recalculateHeight(_ textView: UITextView) {
        let width = textView.bounds.width > 0 ? textView.bounds.width : UIScreen.main.bounds.width - 40
        let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let height = max(250, ceil(size.height))
        if abs(dynamicHeight - height) > 1 {
            DispatchQueue.main.async {
                dynamicHeight = height
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: WorkoutNoteTextView
        var anchorRanges: [(range: NSRange, anchor: ExerciseAnchor)] = []
        var cardioRanges: [(range: NSRange, entry: CardioEntry)] = []
        var isUpdatingText = false
        var lastRenderedText = ""
        var lastRenderSignature = ""

        init(parent: WorkoutNoteTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingText else { return }
            parent.text = textView.text
            parent.recalculateHeight(textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isEditing = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isEditing = false
        }

        @objc func handleExerciseDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let textView = recognizer.view as? UITextView
            else { return }

            let location = recognizer.location(in: textView)
            guard let characterIndex = textView.characterIndex(at: location) else { return }

            if let match = anchorRanges.first(where: { NSLocationInRange(characterIndex, $0.range) }) {
                parent.onSelectExercise(match.anchor)
                return
            }

            if let match = cardioRanges.first(where: { NSLocationInRange(characterIndex, $0.range) }) {
                parent.onSelectCardio(match.entry)
            }
        }
    }
}

private struct WorkoutLineBadgeView: View {
    let badge: WorkoutLineBadge

    var body: some View {
        Text(badge.label)
            .font(BramFont.label(size: 12))
            .foregroundStyle(BramColor.violet)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(BramColor.violet.opacity(0.12), in: Capsule())
            .overlay {
                Capsule().stroke(BramColor.violet.opacity(0.18), lineWidth: 1)
            }
    }
}

private extension UITextView {
    func characterIndex(at point: CGPoint) -> Int? {
        var point = point
        point.x -= textContainerInset.left
        point.y -= textContainerInset.top

        let glyphIndex = layoutManager.glyphIndex(
            for: point,
            in: textContainer,
            fractionOfDistanceThroughGlyph: nil
        )
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard characterIndex < text.utf16.count else { return nil }
        return characterIndex
    }
}

private extension UIFont {
    static func bramBody(size: CGFloat) -> UIFont {
        UIFont(name: "SuisseIntlTrial-Regular", size: size) ?? .systemFont(ofSize: size)
    }
}

private extension UIColor {
    static let bramViolet = UIColor(red: 0.365, green: 0.353, blue: 0.969, alpha: 1)

    static func bramTextPrimary(for traits: UITraitCollection) -> UIColor {
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 247 / 255, green: 242 / 255, blue: 234 / 255, alpha: 1)
            : UIColor(red: 35 / 255, green: 38 / 255, blue: 44 / 255, alpha: 1)
    }
}

#Preview {
    WorkoutNoteEditor(
        noteBody: .constant(BramPreviewData.populatedNote.body),
        interpretedLines: BramPreviewData.populatedNote.interpretedLines,
        interpretationEnabled: true,
        onSelectExercise: { _ in }
    )
        .padding()
        .background(BramColor.appBackground)
}
