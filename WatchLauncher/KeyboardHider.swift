import UIKit
import SwiftUI

final class GlobalKeyboardAccessory {
    static let shared = GlobalKeyboardAccessory()
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setAccessory),
            name: UITextField.textDidBeginEditingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setAccessory),
            name: UITextView.textDidBeginEditingNotification,
            object: nil
        )
    }
    
    @objc private func setAccessory(_ notification: Notification) {
        guard let view = notification.object as? UIView else { return }
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem.flexibleSpace(),
            UIBarButtonItem(
                image: UIImage(systemName: "keyboard.chevron.compact.down"),
                style: .plain,
                target: self,
                action: #selector(hideKeyboard)
            )
        ]
        if let textField = view as? UITextField {
            textField.inputAccessoryView = toolbar
            textField.reloadInputViews()
        } else if let textView = view as? UITextView {
            textView.inputAccessoryView = toolbar
            textView.reloadInputViews()
        }
    }
    
    @objc private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
