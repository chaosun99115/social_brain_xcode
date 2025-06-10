import SwiftUI
import CoreData

/// A view that demonstrates displaying both sample and user data together
struct DataDisplayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var allContacts: [Contact] = []
    @State private var allNotes: [Note] = []
    @State private var allCircles: [Circle] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                Section("所有数据 (样本 + 用户)") {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                        Text("联系人")
                        Spacer()
                        Text("\(allContacts.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.green)
                        Text("笔记")
                        Spacer()
                        Text("\(allNotes.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "circle.grid.3x3.fill")
                            .foregroundColor(.orange)
                        Text("圈子")
                        Spacer()
                        Text("\(allCircles.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("样本数据 (type == 0)") {
                    let sampleData = getSampleData()
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                        Text("样本联系人")
                        Spacer()
                        Text("\(sampleData.contacts.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.green)
                        Text("样本笔记")
                        Spacer()
                        Text("\(sampleData.notes.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "circle.grid.3x3.fill")
                            .foregroundColor(.orange)
                        Text("样本圈子")
                        Spacer()
                        Text("\(sampleData.circles.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("用户数据 (type != 0)") {
                    let userData = getUserData()
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                        Text("用户联系人")
                        Spacer()
                        Text("\(userData.contacts.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.green)
                        Text("用户笔记")
                        Spacer()
                        Text("\(userData.notes.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "circle.grid.3x3.fill")
                            .foregroundColor(.orange)
                        Text("用户圈子")
                        Spacer()
                        Text("\(userData.circles.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("操作") {
                    Button("刷新数据") {
                        Task {
                            await loadData()
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button("切换到跳槽场景") {
                        Task {
                            await switchToScenario(.changedJob)
                        }
                    }
                    .foregroundColor(.green)
                    
                    Button("切换到独立开发者场景") {
                        Task {
                            await switchToScenario(.indie)
                        }
                    }
                    .foregroundColor(.orange)
                    
                    Button("移除样本数据") {
                        Task {
                            await removeSampleData()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("数据管理")
            .refreshable {
                await loadData()
            }
            .onAppear {
                Task {
                    await loadData()
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("加载中...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            .alert("错误", isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("确定") {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load all data (both sample and user)
            allContacts = try SeedDataManager.shared.fetchAllContacts(in: viewContext)
            allNotes = try SeedDataManager.shared.fetchAllNotes(in: viewContext)
            allCircles = try SeedDataManager.shared.fetchAllCircles(in: viewContext)
        } catch {
            errorMessage = "加载数据失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func getSampleData() -> (contacts: [Contact], notes: [Note], circles: [Circle]) {
        do {
            return try SeedDataManager.shared.fetchSampleData(in: viewContext)
        } catch {
            return ([], [], [])
        }
    }
    
    private func getUserData() -> (contacts: [Contact], notes: [Note], circles: [Circle]) {
        do {
            return try SeedDataManager.shared.fetchUserData(in: viewContext)
        } catch {
            return ([], [], [])
        }
    }
    
    private func switchToScenario(_ scenario: SeedDataScenario) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await SeedDataManager.shared.switchToScenario(scenario, in: viewContext)
            await loadData()
        } catch {
            errorMessage = "切换场景失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func removeSampleData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try SeedDataManager.shared.removeSampleData(from: viewContext)
            await loadData()
        } catch {
            errorMessage = "移除样本数据失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// MARK: - Preview Provider
struct DataDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        DataDisplayView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 