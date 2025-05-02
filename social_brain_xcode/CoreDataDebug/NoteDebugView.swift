import SwiftUI
import CoreData

struct NoteDebugView: View {
    var body: some View {
        CoreDataDebugView<Note>(
            title: "Notes Debug",
            entityName: "Note",
            sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
        )
    }
} 