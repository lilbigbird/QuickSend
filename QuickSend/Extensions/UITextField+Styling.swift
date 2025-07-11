import UIKit

extension UITextField {
    
    /// Apply consistent styling across the app
    func applyQuickSendStyle() {
        self.borderStyle = .none
        self.layer.cornerRadius = 12
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.systemGray4.cgColor
        self.backgroundColor = UIColor.systemBackground
        
        // Add padding for text
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: self.frame.height))
        self.leftView = paddingView
        self.leftViewMode = .always
        self.rightView = paddingView
        self.rightViewMode = .always
    }
    
    /// Apply error state styling
    func applyErrorStyle() {
        self.layer.borderColor = UIColor.systemRed.cgColor
    }
    
    /// Apply normal state styling
    func applyNormalStyle() {
        self.layer.borderColor = UIColor.systemGray4.cgColor
    }
    
    /// Apply focused state styling
    func applyFocusedStyle() {
        self.layer.borderColor = UIColor.systemBlue.cgColor
    }
} 