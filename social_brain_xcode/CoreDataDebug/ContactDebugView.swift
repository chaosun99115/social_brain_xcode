import SwiftUI
import CoreData

struct ContactDebugView: View {
    var body: some View {
        CoreDataDebugView<Contact>(
            title: "Contacts Debug",
            entityName: "Contact",
            sortDescriptors: [NSSortDescriptor(keyPath: \Contact.name, ascending: true)]
        )
    }
} 