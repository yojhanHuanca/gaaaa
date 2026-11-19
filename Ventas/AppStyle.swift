import UIKit

enum AppStyle {
    static let blue = UIColor.systemBlue
    static let background = UIColor.systemGroupedBackground
    static let card = UIColor.secondarySystemGroupedBackground
    static let muted = UIColor.secondaryLabel
    static let green = UIColor.systemGreen
    static let amber = UIColor.systemOrange
    static let red = UIColor.systemRed

    static func money(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "S/ "
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "es_PE")
        return formatter.string(from: NSNumber(value: value)) ?? "S/ 0.00"
    }
}

extension UIViewController {
    func showMessage(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        present(alert, animated: true)
    }

    func showError(_ error: Error) { showMessage("Ventas", error.localizedDescription) }
}
