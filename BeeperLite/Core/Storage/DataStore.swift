import CoreData
import Foundation

final class DataStore {
    static let shared = DataStore()
    
    let container: NSPersistentContainer
    
    private init() {
        // Le nom doit correspondre au fichier .xcdatamodeld que nous créerons dans Xcode
        container = NSPersistentContainer(name: "BeeperLiteDataModel")
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // En production, il faudra gérer ça de manière plus résiliente qu'un fatalError
                fatalError("Erreur fatale de chargement CoreData: \(error), \(error.userInfo)")
            }
        }
        
        // Optimisation cruciale pour les mises à jour en background issues de la sync Matrix
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    var context: NSManagedObjectContext {
        return container.viewContext
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Erreur non gérée lors de la sauvegarde du contexte \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func clearAllData() {
        let entities = container.managedObjectModel.entities
        for entity in entities {
            if let entityName = entity.name {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                do {
                    try context.execute(deleteRequest)
                    print("Données effacées pour l'entité \(entityName)")
                } catch {
                    print("Erreur lors de l'effacement de l'entité \(entityName): \(error)")
                }
            }
        }
        saveContext()
    }
}
