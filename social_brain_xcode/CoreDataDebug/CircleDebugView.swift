import SwiftUI
import CoreData

struct CircleDebugView: View {
    var body: some View {
        CoreDataDebugView<Circle>(
            title: "Circles Debug",
            entityName: "Circle",
            sortDescriptors: [NSSortDescriptor(keyPath: \Circle.name, ascending: true)]
        )
    }
} 