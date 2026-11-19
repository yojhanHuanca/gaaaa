import CoreData

@objc(Usuario)
final class Usuario: NSManagedObject {
    @NSManaged var nombre: String?
    @NSManaged var usuario: String?
    @NSManaged var clave: String?
    @NSManaged var rol: String?
    @NSManaged var ventas: NSSet?
    var ventasArray: [Venta] { (ventas?.allObjects as? [Venta] ?? []) }
    @nonobjc class func fetchRequest() -> NSFetchRequest<Usuario> {
        NSFetchRequest<Usuario>(entityName: "Usuario")
    }
}

@objc(Producto)
final class Producto: NSManagedObject {
    @NSManaged var nombre: String?
    @NSManaged var categoria: String?
    @NSManaged var precio: Double
    @NSManaged var stock: Int64
    @NSManaged var ventas: NSSet?
    var ventasArray: [Venta] { (ventas?.allObjects as? [Venta] ?? []) }
    @nonobjc class func fetchRequest() -> NSFetchRequest<Producto> {
        NSFetchRequest<Producto>(entityName: "Producto")
    }
}

@objc(Cliente)
final class Cliente: NSManagedObject {
    @NSManaged var nombre: String?
    @NSManaged var documento: String?
    @NSManaged var ventas: NSSet?
    var ventasArray: [Venta] { (ventas?.allObjects as? [Venta] ?? []) }
    @nonobjc class func fetchRequest() -> NSFetchRequest<Cliente> {
        NSFetchRequest<Cliente>(entityName: "Cliente")
    }

    var totalComprado: Double {
        ventasArray.filter { !$0.anulada }.reduce(0) { $0 + $1.total }
    }

    var categoriaCompra: String {
        if totalComprado >= 5_000 { return "VIP" }
        if totalComprado >= 1_000 { return "Frecuente" }
        return "Regular"
    }
}

@objc(Venta)
final class Venta: NSManagedObject {
    @NSManaged var fecha: Date?
    @NSManaged var cantidad: Int64
    @NSManaged var precioUnitario: Double
    @NSManaged var descuento: Double
    @NSManaged var igv: Double
    @NSManaged var total: Double
    @NSManaged var anulada: Bool
    @NSManaged var motivoAnulacion: String?
    @NSManaged var vendedor: Usuario?
    @NSManaged var producto: Producto?
    @NSManaged var cliente: Cliente?
    @nonobjc class func fetchRequest() -> NSFetchRequest<Venta> {
        NSFetchRequest<Venta>(entityName: "Venta")
    }
}

enum AppRole {
    static let seller = "Vendedor"
    static let supervisor = "Supervisor"
}
