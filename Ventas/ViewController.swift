import UIKit

final class ViewController: UIViewController {
    @IBOutlet private weak var usernameField: UITextField!
    @IBOutlet private weak var passwordField: UITextField!
    @IBOutlet private weak var errorLabel: UILabel!
    private var pendingUser: Usuario?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ventas"
        view.backgroundColor = AppStyle.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        errorLabel.text = nil
    }

    @IBAction private func loginTapped(_ sender: UIButton) {
        do {
            pendingUser = try SalesService.shared.login(username: usernameField.text ?? "", password: passwordField.text ?? "")
            performSegue(withIdentifier: "showMain", sender: sender)
        } catch { errorLabel.text = "Usuario o clave incorrectos" }
    }

    @IBAction private func registerTapped(_ sender: UIButton) { performSegue(withIdentifier: "showRegister", sender: sender) }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); navigationController?.setNavigationBarHidden(true, animated: false) }

    @IBAction func unwindToLogin(_ segue: UIStoryboardSegue) { pendingUser = nil }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let tabs = segue.destination as? MainTabBarController { tabs.currentUser = pendingUser }
    }
}
