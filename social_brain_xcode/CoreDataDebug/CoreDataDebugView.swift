import SwiftUI
import CoreData

struct CoreDataDebugView<T: NSManagedObject>: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var items: FetchedResults<T>
    @State private var showingAddSheet = false
    @State private var selectedItem: T?
    @State private var showingEditSheet = false
    
    let title: String
    let entityName: String
    
    init(title: String, entityName: String, sortDescriptors: [NSSortDescriptor] = []) {
        self.title = title
        self.entityName = entityName
        
        let request = NSFetchRequest<T>(entityName: entityName)
        request.sortDescriptors = sortDescriptors
        _items = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        List {
            ForEach(items, id: \.self) { item in
                Button(action: {
                    selectedItem = item
                    showingEditSheet = true
                }) {
                    VStack(alignment: .leading) {
                        Text("ID: \(item.objectID.uriRepresentation().lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        // Display all attributes
                        ForEach(item.entity.attributesByName.keys.sorted(), id: \.self) { key in
                            if let value = item.value(forKey: key) {
                                Text("\(key): \(String(describing: value))")
                            }
                        }
                        
                        // Display relationships
                        ForEach(item.entity.relationshipsByName.keys.sorted(), id: \.self) { key in
                            if let relationship = item.entity.relationshipsByName[key] {
                                if relationship.isToMany {
                                    if let set = item.value(forKey: key) as? NSSet {
                                        Text("\(key): \(set.count) items")
                                    } else {
                                        Text("\(key): 0 items")
                                    }
                                } else {
                                    if let relatedObject = item.value(forKey: key) as? NSManagedObject {
                                        Text("\(key): \(relatedObject.objectID.uriRepresentation().lastPathComponent)")
                                    } else {
                                        Text("\(key): nil")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddSheet = true
                }) {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEntityView(entityName: entityName)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let item = selectedItem {
                EditEntityView(entity: item)
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

struct AddEntityView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let entityName: String
    @State private var attributes: [String: String] = [:]
    
    var body: some View {
        NavigationView {
            Form {
                ForEach(Array(attributes.keys.sorted()), id: \.self) { key in
                    TextField(key, text: Binding(
                        get: { attributes[key] ?? "" },
                        set: { attributes[key] = $0 }
                    ))
                }
            }
            .navigationTitle("Add \(entityName)")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntity()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let entity = NSEntityDescription.entity(forEntityName: entityName, in: viewContext) {
                    for (key, _) in entity.attributesByName {
                        attributes[key] = ""
                    }
                }
            }
        }
    }
    
    private func saveEntity() {
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: viewContext)
        
        for (key, value) in attributes {
            entity.setValue(value, forKey: key)
        }
        
        try? viewContext.save()
        dismiss()
    }
}

struct EditEntityView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let entity: NSManagedObject
    @State private var attributes: [String: String] = [:]
    
    var body: some View {
        NavigationView {
            Form {
                ForEach(Array(attributes.keys.sorted()), id: \.self) { key in
                    TextField(key, text: Binding(
                        get: { attributes[key] ?? "" },
                        set: { attributes[key] = $0 }
                    ))
                }
            }
            .navigationTitle("Edit \(entity.entity.name ?? "")")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntity()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                for (key, _) in entity.entity.attributesByName {
                    if let value = entity.value(forKey: key) {
                        attributes[key] = String(describing: value)
                    }
                }
            }
        }
    }
    
    private func saveEntity() {
        for (key, value) in attributes {
            entity.setValue(value, forKey: key)
        }
        
        try? viewContext.save()
        dismiss()
    }
} 