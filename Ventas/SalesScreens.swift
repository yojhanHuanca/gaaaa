import UIKit
import CoreData

final class RegisterViewController: UIViewController {
    @IBOutlet private weak var nameField: UITextField!
    @IBOutlet private weak var usernameField: UITextField!
    @IBOutlet private weak var passwordField: UITextField!
    @IBOutlet private weak var confirmationField: UITextField!
    @IBOutlet private weak var roleControl: UISegmentedControl!
    @IBOutlet private weak var availableLabel: UILabel!
    @IBOutlet private weak var errorLabel: UILabel!
    private var pendingUser: Usuario?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Crear cuenta"
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "‹ Ingresar", style: .plain, target: self, action: #selector(backToLogin))
        view.backgroundColor = AppStyle.background
        roleControl.selectedSegmentIndex = 0
        availableLabel.text = ""
        errorLabel.text = ""
        usernameField.addTarget(self, action: #selector(checkUsername), for: .editingChanged)
    }

    @objc private func backToLogin() { navigationController?.popViewController(animated: true) }

    @objc private func checkUsername() {
        let name = usernameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { availableLabel.text = ""; return }
        let exists = SalesService.shared.userExists(name)
        availableLabel.text = exists ? "Ese usuario ya existe" : "✓ Disponible"
        availableLabel.textColor = exists ? .systemRed : .systemGreen
    }

    @IBAction func registerTapped(_ sender: UIButton) {
        do {
            pendingUser = try SalesService.shared.register(
                name: nameField.text ?? "", username: usernameField.text ?? "",
                password: passwordField.text ?? "", confirmation: confirmationField.text ?? "",
                role: roleControl.selectedSegmentIndex == 0 ? AppRole.seller : AppRole.supervisor
            )
            performSegue(withIdentifier: "showMain", sender: sender)
        } catch { errorLabel.text = error.localizedDescription }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let tabs = segue.destination as? MainTabBarController { tabs.currentUser = pendingUser }
    }
}

final class MainTabBarController: UITabBarController {
    var currentUser: Usuario?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let user = currentUser else { return }
        let allTabs = viewControllers ?? []
        func tab(_ title: String) -> UIViewController? { allTabs.first { $0.tabBarItem.title == title } }
        if user.rol == AppRole.supervisor {
            viewControllers = [tab("Resumen"), tab("Mis ventas"), tab("Productos"), tab("Clientes"), tab("Cuenta")].compactMap { $0 }
        } else {
            viewControllers = [tab("Productos"), tab("Clientes"), tab("Venta"), tab("Mis ventas"), tab("Cuenta")].compactMap { $0 }
        }
        if let sales = viewControllers?.first(where: { $0.tabBarItem.title == "Mis ventas" }) {
            sales.tabBarItem.title = user.rol == AppRole.supervisor ? "Ventas" : "Mis ventas"
            if let nav = sales as? UINavigationController { nav.tabBarItem.title = user.rol == AppRole.supervisor ? "Ventas" : "Mis ventas" }
            if let list = (sales as? UINavigationController)?.viewControllers.first as? SalesListViewController {
                list.user = user; list.supervisorMode = user.rol == AppRole.supervisor
            }
        }
        for controller in viewControllers ?? [] {
            guard let nav = controller as? UINavigationController, let screen = nav.viewControllers.first else { continue }
            (screen as? ProductsViewController)?.user = user
            (screen as? ClientsViewController)?.user = user
            (screen as? NewSaleViewController)?.user = user
            (screen as? AccountViewController)?.user = user
            (screen as? DashboardViewController)?.user = user
            if let sales = screen as? SalesListViewController {
                sales.user = user
                sales.supervisorMode = user.rol == AppRole.supervisor
            }
        }
    }
}

final class ProductsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    var user: Usuario!
    @IBOutlet private weak var table: UITableView!
    @IBOutlet private weak var categoryControl: UISegmentedControl!
    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var addButton: UIButton!
    private var products: [Producto] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Productos"
        navigationController?.setNavigationBarHidden(true, animated: false)
        table.dataSource = self; table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "product-extra")
        searchBar.delegate = self
        addButton.isHidden = user?.rol != AppRole.supervisor
        navigationController?.setNavigationBarHidden(true, animated: false)
        reload()
    }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); reload() }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { reload() }
    @IBAction private func filterChanged(_ sender: UISegmentedControl) { reload() }
    @IBAction private func addProduct(_ sender: UIButton) { editProduct(nil) }

    private func reload() {
        guard isViewLoaded else { return }
        let category = categoryControl.titleForSegment(at: categoryControl.selectedSegmentIndex) ?? "Todos"
        products = SalesService.shared.fetchProducts(search: searchBar.text ?? "", category: category)
        table.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { products.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: indexPath.row < 4 ? "product-\(indexPath.row + 1)" : "product-extra", for: indexPath)
        let item = products[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        content.text = item.nombre ?? "Producto"
        content.secondaryText = "\(item.categoria ?? "") · \(AppStyle.money(item.precio)) · \(item.stock) u."
        content.image = UIImage(systemName: "shippingbox.fill"); content.imageProperties.tintColor = AppStyle.blue
        cell.contentConfiguration = content
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if user?.rol == AppRole.supervisor { editProduct(products[indexPath.row]) }
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, user?.rol == AppRole.supervisor else { return }
        CoreDataStack.shared.context.delete(products[indexPath.row])
        do { try CoreDataStack.shared.save(); reload() }
        catch { CoreDataStack.shared.context.rollback(); showError(SalesError.protectedRecord) }
    }
    private func editProduct(_ product: Producto?) {
        let alert = UIAlertController(title: product == nil ? "Nuevo producto" : "Editar producto", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Nombre"; $0.text = product?.nombre }
        alert.addTextField { $0.placeholder = "Categoría"; $0.text = product?.categoria }
        alert.addTextField { $0.placeholder = "Precio"; $0.keyboardType = .decimalPad; $0.text = product.map { String($0.precio) } }
        alert.addTextField { $0.placeholder = "Stock"; $0.keyboardType = .numberPad; $0.text = product.map { String($0.stock) } }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Guardar", style: .default) { [weak self] _ in
            guard let self, let name = alert.textFields?[0].text, !name.isEmpty,
                  let category = alert.textFields?[1].text, !category.isEmpty,
                  let price = Double((alert.textFields?[2].text ?? "").replacingOccurrences(of: ",", with: ".")),
                  let stock = Int64(alert.textFields?[3].text ?? "") else { self?.showMessage("Producto", "Revisa los datos ingresados."); return }
            let item = product ?? Producto(context: CoreDataStack.shared.context)
            item.nombre = name; item.categoria = category; item.precio = price; item.stock = stock
            do { try CoreDataStack.shared.save(); self.reload() } catch { self.showError(error) }
        })
        present(alert, animated: true)
    }
}

final class ClientsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    var user: Usuario!
    @IBOutlet private weak var table: UITableView!
    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var noteLabel: UILabel!
    private var clients: [Cliente] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Clientes"
        navigationController?.setNavigationBarHidden(true, animated: false)
        table.dataSource = self; table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "client-extra")
        searchBar.delegate = self
        navigationController?.setNavigationBarHidden(true, animated: false)
        noteLabel.text = "La categoría y el total comprado se calculan con las ventas no anuladas."
        reload()
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); reload() }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { reload() }
    @IBAction private func addClient(_ sender: UIButton) { editClient(nil) }
    private func reload() {
        guard isViewLoaded else { return }
        clients = SalesService.shared.fetchClients(search: searchBar.text ?? "")
        table.reloadData()
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { clients.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: indexPath.row < 4 ? "client-\(indexPath.row + 1)" : "client-extra", for: indexPath)
        let client = clients[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        content.text = client.nombre
        content.secondaryText = "\(client.documento ?? "") · \(AppStyle.money(client.totalComprado)) comprado · \(client.categoriaCompra)"
        content.image = UIImage(systemName: "person.crop.circle.fill"); content.imageProperties.tintColor = AppStyle.blue
        cell.contentConfiguration = content; cell.accessoryType = .disclosureIndicator
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true); editClient(clients[indexPath.row])
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, user?.rol == AppRole.supervisor else { return }
        CoreDataStack.shared.context.delete(clients[indexPath.row])
        do { try CoreDataStack.shared.save(); reload() }
        catch { CoreDataStack.shared.context.rollback(); showError(SalesError.protectedRecord) }
    }
    private func editClient(_ client: Cliente?) {
        let alert = UIAlertController(title: client == nil ? "Nuevo cliente" : "Editar cliente", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Nombre"; $0.text = client?.nombre }
        alert.addTextField { $0.placeholder = "DNI o RUC"; $0.keyboardType = .numberPad; $0.text = client?.documento }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Guardar", style: .default) { [weak self] _ in
            guard let self, let name = alert.textFields?[0].text, !name.isEmpty, let doc = alert.textFields?[1].text, !doc.isEmpty else { self?.showMessage("Cliente", "Completa el nombre y el documento."); return }
            let item = client ?? Cliente(context: CoreDataStack.shared.context)
            item.nombre = name; item.documento = doc
            do { try CoreDataStack.shared.save(); self.reload() } catch { self.showError(error) }
        })
        present(alert, animated: true)
    }
}

final class NewSaleViewController: UIViewController {
    var user: Usuario!
    @IBOutlet private weak var sellerLabel: UILabel!
    @IBOutlet private weak var clientButton: UIButton!
    @IBOutlet private weak var productButton: UIButton!
    @IBOutlet private weak var quantityLabel: UILabel!
    @IBOutlet private weak var quantityStepper: UIStepper!
    @IBOutlet private weak var summaryLabel: UILabel!
    @IBOutlet private weak var registerButton: UIButton!
    private var clients: [Cliente] = []
    private var products: [Producto] = []
    private var selectedClient: Cliente?
    private var selectedProduct: Producto?
    private var quantity = 1

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Nueva venta"
        navigationController?.setNavigationBarHidden(true, animated: false)
        sellerLabel.text = "\(user.nombre ?? "") · Vendedor\nLa venta se registra a tu nombre"
        quantityStepper.minimumValue = 1
        refreshData()
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); refreshData() }
    private func refreshData() { clients = SalesService.shared.fetchClients(); products = SalesService.shared.fetchProducts(); updateSummary() }

    @IBAction private func chooseClient(_ sender: UIButton) {
        let alert = UIAlertController(title: "Selecciona cliente", message: nil, preferredStyle: .actionSheet)
        clients.forEach { client in alert.addAction(UIAlertAction(title: "\(client.nombre ?? "") · \(client.categoriaCompra)", style: .default) { [weak self] _ in self?.selectedClient = client; self?.clientButton.setTitle(client.nombre, for: .normal); self?.updateSummary() }) }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel)); present(alert, animated: true)
    }
    @IBAction private func chooseProduct(_ sender: UIButton) {
        let alert = UIAlertController(title: "Selecciona producto", message: nil, preferredStyle: .actionSheet)
        products.forEach { product in alert.addAction(UIAlertAction(title: "\(product.nombre ?? "") · \(AppStyle.money(product.precio)) · stock \(product.stock)", style: .default) { [weak self] _ in
            guard let self else { return }; self.selectedProduct = product; self.productButton.setTitle(product.nombre, for: .normal)
            self.quantityStepper.maximumValue = Double(max(1, product.stock)); self.quantityStepper.value = min(self.quantityStepper.value, Double(max(1, product.stock))); self.quantityChanged(self.quantityStepper)
        }) }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel)); present(alert, animated: true)
    }
    @IBAction private func quantityChanged(_ sender: UIStepper) { quantity = Int(sender.value); updateSummary() }
    private func updateSummary() {
        quantityLabel.text = "Cantidad (stock \(selectedProduct?.stock ?? 0)): \(quantity)"
        guard let client = selectedClient, let product = selectedProduct else { summaryLabel.text = "Subtotal    —\nDescuento VIP    —\nIGV 18%    —\nTOTAL    —"; registerButton.isEnabled = false; return }
        let result = SalesService.shared.calculate(quantity: quantity, product: product, client: client)
        summaryLabel.text = "Subtotal    \(AppStyle.money(result.subtotal))\nDescuento VIP 10%    − \(AppStyle.money(result.descuento))\nIGV 18%    \(AppStyle.money(result.igv))\nTOTAL    \(AppStyle.money(result.total))"
        registerButton.isEnabled = quantity <= product.stock && product.stock > 0
    }
    @IBAction private func registerSale(_ sender: UIButton) {
        do { _ = try SalesService.shared.registerSale(seller: user, client: selectedClient, product: selectedProduct, quantity: quantity); showMessage("Venta registrada", "El stock se actualizó correctamente."); selectedClient = nil; selectedProduct = nil; quantity = 1; clientButton.setTitle("Cliente  ›", for: .normal); productButton.setTitle("Producto  ›", for: .normal); refreshData() }
        catch { showError(error) }
    }
}

final class SalesListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    var user: Usuario!
    var supervisorMode = false
    @IBOutlet private weak var table: UITableView!
    @IBOutlet private weak var periodControl: UISegmentedControl!
    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var sellersControl: UISegmentedControl!
    @IBOutlet private weak var totalsLabel: UILabel!
    private var sellers: [Usuario] = []
    private var selectedSeller: Usuario?
    private var sales: [Venta] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = supervisorMode ? "Ventas del equipo" : "Mis ventas"
        navigationController?.setNavigationBarHidden(true, animated: false)
        sellers = SalesService.shared.fetchUsers().filter { $0.rol == AppRole.seller }
        if let sellersControl { sellersControl.removeAllSegments(); sellersControl.insertSegment(withTitle: "Todos", at: 0, animated: false); sellers.enumerated().forEach { sellersControl.insertSegment(withTitle: $0.element.nombre ?? "Vendedor", at: $0.offset + 1, animated: false) }; sellersControl.selectedSegmentIndex = 0; sellersControl.isHidden = !supervisorMode }
        table.dataSource = self; table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "sale-extra")
        searchBar.delegate = self
        periodControl.selectedSegmentIndex = 0
        reload()
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); reload() }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { reload() }
    @IBAction private func filtersChanged(_ sender: UISegmentedControl) { if sender === sellersControl, sender.selectedSegmentIndex > 0 { selectedSeller = sellers[sender.selectedSegmentIndex - 1] } else if sender === sellersControl { selectedSeller = nil }; reload() }
    private func reload() {
        guard isViewLoaded, let user else { return }
        let names = ["Todas", "Hoy", "Mes"]
        let selectedPeriod = names[min(periodControl.selectedSegmentIndex, names.count - 1)]
        let all = SalesService.shared.fetchAllSales(for: user, supervisorMode: supervisorMode, period: selectedPeriod, clientSearch: searchBar.text ?? "", seller: selectedSeller)
        sales = all
        let total = all.filter { !$0.anulada }.reduce(0) { $0 + $1.total }
        totalsLabel.text = "\(selectedPeriod)   \(AppStyle.money(total))     \(all.count) ventas"
        table.reloadData()
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sales.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: indexPath.row < 3 ? "sale-\(indexPath.row + 1)" : "sale-extra", for: indexPath); let sale = sales[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell(); content.text = "\(sale.cliente?.nombre ?? "Cliente")     \(AppStyle.money(sale.total))"
        let seller = supervisorMode ? "\(sale.vendedor?.nombre ?? "Vendedor") · " : ""
        content.secondaryText = "\(seller)\(sale.producto?.nombre ?? "Producto") × \(sale.cantidad) · \(Self.date(sale.fecha))" + (sale.anulada ? " · ANULADA" : "")
        content.image = UIImage(systemName: sale.anulada ? "xmark.circle.fill" : "checkmark.circle.fill"); content.imageProperties.tintColor = sale.anulada ? .systemRed : .systemGreen; cell.contentConfiguration = content
        return cell
    }
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard supervisorMode, !sales[indexPath.row].anulada else { return nil }
        let action = UIContextualAction(style: .destructive, title: "Anular") { [weak self] _, _, done in self?.performSegue(withIdentifier: "showAnnul", sender: self?.sales[indexPath.row]); done(true) }
        return UISwipeActionsConfiguration(actions: [action])
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let annul = segue.destination as? AnnulSaleViewController, let sale = sender as? Venta { annul.sale = sale; annul.onCancelled = { [weak self] in self?.reload() } }
    }
    private static func date(_ date: Date?) -> String { guard let date else { return "" }; let f = DateFormatter(); f.dateFormat = "dd/MM"; return f.string(from: date) }
}

final class AnnulSaleViewController: UIViewController {
    var sale: Venta!
    var onCancelled: (() -> Void)?
    @IBOutlet private weak var summaryLabel: UILabel!
    @IBOutlet private weak var reasonField: UITextField!
    @IBOutlet private weak var confirmButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Anular venta"; navigationController?.setNavigationBarHidden(true, animated: false)
        summaryLabel.text = "\(sale.cliente?.nombre ?? "Cliente") · \(sale.producto?.nombre ?? "Producto") × \(sale.cantidad) · \(AppStyle.money(sale.total))\nEl stock se devolverá al inventario."
        confirmButton.isEnabled = false
    }
    @IBAction private func reasonChanged(_ sender: UITextField) { confirmButton.isEnabled = !(sender.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
    @IBAction private func close(_ sender: UIButton) { navigationController?.popViewController(animated: true) }
    @IBAction private func confirmCancellation(_ sender: UIButton) {
        do { try SalesService.shared.cancel(sale, reason: reasonField.text ?? ""); navigationController?.popViewController(animated: true); onCancelled?() }
        catch { showError(error) }
    }
}

final class DashboardViewController: UIViewController {
    var user: Usuario!
    @IBOutlet private weak var greetingLabel: UILabel!
    @IBOutlet private weak var soldTodayLabel: UILabel!
    @IBOutlet private weak var taxMonthLabel: UILabel!
    @IBOutlet private weak var comparisonLabel: UILabel!
    @IBOutlet private weak var rankingLabel: UILabel!
    @IBOutlet private weak var lowStockLabel: UILabel!
    override func viewDidLoad() { super.viewDidLoad(); title = "Resumen"; navigationController?.setNavigationBarHidden(true, animated: false); reload() }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); reload() }
    private func reload() {
        guard isViewLoaded, let user else { return }
        greetingLabel.text = "Hola, \(user.nombre?.components(separatedBy: " ").first ?? "equipo")"
        let all = SalesService.shared.fetchAllSales(for: user, supervisorMode: true).filter { !$0.anulada }
        let today = all.filter { Calendar.current.isDateInToday($0.fecha ?? .distantPast) }
        let yesterday = all.filter { Calendar.current.isDateInYesterday($0.fecha ?? .distantPast) }
        let month = all.filter { Calendar.current.isDate($0.fecha ?? .distantPast, equalTo: Date(), toGranularity: .month) }
        let todayTotal = today.reduce(0) { $0 + $1.total }, yesterdayTotal = yesterday.reduce(0) { $0 + $1.total }
        let change = yesterdayTotal > 0 ? (todayTotal - yesterdayTotal) / yesterdayTotal * 100 : 0
        soldTodayLabel.text = AppStyle.money(todayTotal); taxMonthLabel.text = AppStyle.money(month.reduce(0) { $0 + $1.igv }); comparisonLabel.text = String(format: "▲ %.0f%% vs ayer", change)
        let ranking = SalesService.shared.fetchUsers().filter { $0.rol == AppRole.seller }.map { seller in "\(seller.nombre ?? "") · \(AppStyle.money(month.filter { $0.vendedor == seller }.reduce(0) { $0 + $1.total }))" }.joined(separator: "\n")
        rankingLabel.text = ranking.isEmpty ? "Aún no hay ventas." : ranking
        let low = SalesService.shared.fetchProducts().filter { $0.stock <= 5 }
        lowStockLabel.text = low.isEmpty ? "No hay productos con stock bajo." : low.map { "\($0.nombre ?? "Producto") · \($0.stock) u." }.joined(separator: "\n")
    }
}

final class AccountViewController: UIViewController {
    var user: Usuario!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var usernameLabel: UILabel!
    @IBOutlet private weak var roleLabel: UILabel!
    override func viewDidLoad() { super.viewDidLoad(); title = "Cuenta"; navigationController?.setNavigationBarHidden(true, animated: false); nameLabel.text = user.nombre; usernameLabel.text = "@\(user.usuario ?? "")"; roleLabel.text = user.rol }
    @IBAction private func logoutTapped(_ sender: UIButton) { performSegue(withIdentifier: "logout", sender: sender) }
}
