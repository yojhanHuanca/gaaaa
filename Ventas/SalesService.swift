import CoreData

struct SaleBreakdown {
    let subtotal: Double
    let descuento: Double
    let igv: Double
    let total: Double
}

enum SalesError: LocalizedError {
    case missingFields, duplicateUser, shortPassword, passwordMismatch
    case invalidCredentials, noStock, missingSaleData, invalidReason
    case protectedRecord, alreadyCancelled

    var errorDescription: String? {
        switch self {
        case .missingFields: return "Completa todos los campos."
        case .duplicateUser: return "Ese usuario ya está registrado."
        case .shortPassword: return "La clave debe tener al menos 6 caracteres."
        case .passwordMismatch: return "Las claves no coinciden."
        case .invalidCredentials: return "Usuario o clave incorrectos."
        case .noStock: return "No hay stock suficiente para esa cantidad."
        case .missingSaleData: return "Selecciona cliente, producto y cantidad."
        case .invalidReason: return "Escribe el motivo para anular la venta."
        case .protectedRecord: return "No se puede borrar porque tiene ventas asociadas."
        case .alreadyCancelled: return "Esta venta ya fue anulada."
        }
    }
}

final class SalesService {
    static let shared = SalesService()
    private let context = CoreDataStack.shared.context
    private init() {}

    func userExists(_ username: String) -> Bool {
        let request = Usuario.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "usuario ==[c] %@", username.trimmingCharacters(in: .whitespacesAndNewlines))
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    func login(username: String, password: String) throws -> Usuario {
        let request = Usuario.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "usuario ==[c] %@ AND clave == %@", username.trimmingCharacters(in: .whitespacesAndNewlines), password)
        guard let user = try context.fetch(request).first else { throw SalesError.invalidCredentials }
        return user
    }

    func register(name: String, username: String, password: String, confirmation: String, role: String) throws -> Usuario {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else { throw SalesError.missingFields }
        guard password.count >= 6 else { throw SalesError.shortPassword }
        guard password == confirmation else { throw SalesError.passwordMismatch }
        guard !userExists(username) else { throw SalesError.duplicateUser }
        let user = Usuario(context: context)
        user.nombre = name.trimmingCharacters(in: .whitespacesAndNewlines)
        user.usuario = username.trimmingCharacters(in: .whitespacesAndNewlines)
        user.clave = password
        user.rol = role
        try CoreDataStack.shared.save()
        return user
    }

    func calculate(quantity: Int, product: Producto, client: Cliente) -> SaleBreakdown {
        let subtotal = money(Double(quantity) * product.precio)
        let discount = client.categoriaCompra == "VIP" ? money(subtotal * 0.10) : 0
        let tax = money((subtotal - discount) * 0.18)
        return SaleBreakdown(subtotal: subtotal, descuento: discount, igv: tax, total: money(subtotal - discount + tax))
    }

    func registerSale(seller: Usuario, client: Cliente?, product: Producto?, quantity: Int) throws -> Venta {
        guard let client, let product, quantity > 0 else { throw SalesError.missingSaleData }
        guard Int64(quantity) <= product.stock else { throw SalesError.noStock }
        let amounts = calculate(quantity: quantity, product: product, client: client)
        let sale = Venta(context: context)
        sale.fecha = Date()
        sale.cantidad = Int64(quantity)
        sale.precioUnitario = product.precio
        sale.descuento = amounts.descuento
        sale.igv = amounts.igv
        sale.total = amounts.total
        sale.anulada = false
        sale.vendedor = seller
        sale.cliente = client
        sale.producto = product
        product.stock -= Int64(quantity)
        try CoreDataStack.shared.save()
        return sale
    }

    func cancel(_ sale: Venta, reason: String) throws {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SalesError.invalidReason }
        guard !sale.anulada else { throw SalesError.alreadyCancelled }
        sale.anulada = true
        sale.motivoAnulacion = trimmed
        sale.producto?.stock += sale.cantidad
        try CoreDataStack.shared.save()
    }

    func fetchProducts(search: String = "", category: String? = nil) -> [Producto] {
        let request = Producto.fetchRequest()
        var predicates: [NSPredicate] = []
        if !search.isEmpty {
            predicates.append(NSPredicate(format: "nombre CONTAINS[cd] %@ OR categoria CONTAINS[cd] %@", search, search))
        }
        if let category, category != "Todos" {
            predicates.append(NSPredicate(format: "categoria ==[c] %@", category))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func fetchClients(search: String = "") -> [Cliente] {
        let request = Cliente.fetchRequest()
        if !search.isEmpty {
            request.predicate = NSPredicate(format: "nombre CONTAINS[cd] %@ OR documento CONTAINS[cd] %@", search, search)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func fetchUsers() -> [Usuario] {
        let request = Usuario.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func fetchSales(for user: Usuario, supervisorMode: Bool, period: String = "Todas", clientSearch: String = "", seller: Usuario? = nil) -> [Venta] {
        let request = Venta.fetchRequest()
        var filters: [NSPredicate] = [NSPredicate(format: "anulada == NO")]
        if !supervisorMode { filters.append(NSPredicate(format: "vendedor == %@", user)) }
        if let seller { filters.append(NSPredicate(format: "vendedor == %@", seller)) }
        if !clientSearch.isEmpty { filters.append(NSPredicate(format: "cliente.nombre CONTAINS[cd] %@", clientSearch)) }
        let calendar = Calendar.current
        let now = Date()
        if period == "Hoy", let start = calendar.startOfDay(for: now) as Date? {
            filters.append(NSPredicate(format: "fecha >= %@", start as NSDate))
        } else if period == "Mes",
                  let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) {
            filters.append(NSPredicate(format: "fecha >= %@", start as NSDate))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: filters)
        request.sortDescriptors = [NSSortDescriptor(key: "fecha", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    func fetchAllSales(for user: Usuario, supervisorMode: Bool, period: String = "Todas", clientSearch: String = "", seller: Usuario? = nil) -> [Venta] {
        let request = Venta.fetchRequest()
        var filters: [NSPredicate] = []
        if !supervisorMode { filters.append(NSPredicate(format: "vendedor == %@", user)) }
        if let seller { filters.append(NSPredicate(format: "vendedor == %@", seller)) }
        if !clientSearch.isEmpty { filters.append(NSPredicate(format: "cliente.nombre CONTAINS[cd] %@", clientSearch)) }
        let calendar = Calendar.current
        if period == "Hoy" {
            filters.append(NSPredicate(format: "fecha >= %@", calendar.startOfDay(for: Date()) as NSDate))
        } else if period == "Mes", let start = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) {
            filters.append(NSPredicate(format: "fecha >= %@", start as NSDate))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: filters)
        request.sortDescriptors = [NSSortDescriptor(key: "fecha", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    func money(_ value: Double) -> Double { (value * 100).rounded() / 100 }
}
