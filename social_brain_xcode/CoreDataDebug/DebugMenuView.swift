import SwiftUI
import CoreData

struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isIngesting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Seed Data Management") {
                    Button(action: {
                        Task {
                            await ingestSeedData()
                        }
                    }) {
                        HStack {
                            Text("Ingest Seed Data")
                            if isIngesting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isIngesting)
                }
                
                Section("Core Data Debug") {
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
            }
            .navigationTitle("Debug Menu")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Seed Data", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func ingestSeedData() async {
        isIngesting = true
        do {
            try await SeedDataManager.shared.importSeedData(into: viewContext)
            await MainActor.run {
                alertMessage = "Seed data successfully ingested"
                showAlert = true
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to ingest seed data: \(error.localizedDescription)"
                showAlert = true
            }
        }
        isIngesting = false
    }
} 