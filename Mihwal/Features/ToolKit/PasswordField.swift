import SwiftUI
import UIKit

/// A UIKit text field for PDF passwords, used because the SwiftUI fields kept losing the
/// first characters or showing nothing on some devices:
/// - it focuses itself once, when it appears;
/// - it applies every keystroke itself, so a secure field never clears what was typed;
/// - large, high-contrast monospaced text, always left-to-right, English keyboard first.
struct PasswordField: UIViewRepresentable {
    @Binding var text: String
    var isSecure: Bool
    var placeholder: String
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = AutoFocusTextField()
        field.delegate = context.coordinator
        field.font = .monospacedSystemFont(ofSize: 22, weight: .medium)
        field.textColor = .label
        field.keyboardType = .asciiCapable
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.returnKeyType = .go
        field.semanticContentAttribute = .forceLeftToRight
        field.textAlignment = .left
        field.accessibilityIdentifier = "password.field"
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.isSecureTextEntry != isSecure {
            field.isSecureTextEntry = isSecure
        }
        if field.text != text {
            field.text = text
        }
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.secondaryLabel]
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PasswordField

        init(parent: PasswordField) {
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            // Applying the change ourselves stops a secure field from wiping its text
            // on the next keystroke (UIKit's default when it regains focus).
            let current = textField.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return false }
            let updated = current.replacingCharacters(in: swiftRange, with: string)
            textField.text = updated
            parent.text = updated
            return false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}

/// Becomes first responder once, as soon as it is on screen.
private final class AutoFocusTextField: UITextField {
    private var didFocus = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !didFocus else { return }
        didFocus = true
        DispatchQueue.main.async { [weak self] in
            self?.becomeFirstResponder()
        }
    }
}
