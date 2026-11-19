import CoreData

enum DemoDataSeeder {
    static func seedIfNeeded() {
        let context = CoreDataStack.shared.context
        ensureDemoUser(username: "supervisor", name: "Lucía Paredes", role: AppRole.supervisor, in: context)
        ensureDemoUser(username: "carlos", name: "Carlos Ruiz", role: AppRole.seller, in: context)

        if count(Producto.fetchRequest(), in: context) == 0 {
            [
            ("Laptop Pro 14", "Laptops", 200.0, 40),
            ("Monitor 24”", "Monitores", 450.0, 9),
            ("Mouse inalámbrico", "Accesorios", 35.0, 120),
            ("Teclado mecánico", "Accesorios", 129.90, 4)
            ].forEach { name, category, price, stock in
                let product = Producto(context: context)
                product.nombre = name
                product.categoria = category
                product.precio = price
                product.stock = Int64(stock)
            }
        }

        if count(Cliente.fetchRequest(), in: context) == 0 {
            [
            ("Comercial Andina SAC", "20000000001"),
            ("María Quispe", "00000001"),
            ("Luis Rojas", "00000002"),
            ("Tienda Sol EIRL", "20000000044")
            ].forEach { name, document in
                let client = Cliente(context: context)
                client.nombre = name
                client.documento = document
            }
        }

        try? CoreDataStack.shared.save()
    }

    private static func ensureDemoUser(username: String, name: String, role: String, in context: NSManagedObjectContext) {
        let request = Usuario.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "usuario =[c] %@", username)

        if (try? context.fetch(request).first) != nil { return }

        let user = Usuario(context: context)
        user.nombre = name
        user.usuario = username
        user.clave = "123456"
        user.rol = role
    }

    private static func count<T: NSFetchRequestResult>(_ request: NSFetchRequest<T>, in context: NSManagedObjectContext) -> Int {
        (try? context.count(for: request)) ?? 0
    }
}
