import SwiftUI

struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink("Contacts Debug") {
                    ContactDebugView()
                }
                
                NavigationLink("Notes Debug") {
                    NoteDebugView()
                }
                
                NavigationLink("Circles Debug") {
                    CircleDebugView()
                }
                
                NavigationLink("Contact Insights Debug") {
                    ContactInsightDebugView()
                }
            }
            .navigationTitle("Core Data Debug")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 