import SwiftUI
import SwiftData

struct ServerGroupsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ServerGroup.sortOrder) private var groups: [ServerGroup]
    
    @State private var isEditing = false
    @State private var showAddSheet = false
    @State private var newGroupName = ""
    @State private var newGroupIcon = "folder"
    @State private var newGroupColor = Color.blue
    
    let availableIcons = ["folder", "server.rack", "gamecontroller", "star", "tag", "bookmark", "flag"]
    let availableColors: [Color] = [.blue, .red, .green, .orange, .purple, .pink, .yellow, .gray]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    HStack {
                        Image(systemName: group.icon)
                            .foregroundStyle(group.colorHex.asColor)
                        Text(group.name)
                        Spacer()
                        Text("\(group.serverIds.count) servers")
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteGroups)
                .onMove(perform: moveGroups)
            }
            .navigationTitle("Server Groups")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    Form {
                        Section("Group Details") {
                            TextField("Name", text: $newGroupName)
                            
                            Picker("Icon", selection: $newGroupIcon) {
                                ForEach(availableIcons, id: \.self) { icon in
                                    Image(systemName: icon).tag(icon)
                                }
                            }
                            
                            ColorPicker("Color", selection: $newGroupColor)
                        }
                    }
                    .navigationTitle("New Group")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                createGroup()
                                showAddSheet = false
                            }
                            .disabled(newGroupName.isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    private func createGroup() {
        let group = ServerGroup(name: newGroupName, colorHex: newGroupColor.toHex() ?? "#0000FF", icon: newGroupIcon)
        group.sortOrder = groups.count
        modelContext.insert(group)
        newGroupName = ""
    }
    
    private func deleteGroups(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(groups[index])
        }
    }
    
    private func moveGroups(from source: IndexSet, to destination: Int) {
        var reordered = groups
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, group) in reordered.enumerated() {
            group.sortOrder = index
        }
    }
}

struct ServerCustomizationSheet: View {
    let server: ServerAttributes
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var customizations: [ServerCustomization]
    
    @State private var customName: String = ""
    @State private var isPinned: Bool = false
    @State private var isFavorite: Bool = false
    
    private var customization: ServerCustomization? {
        customizations.first { $0.serverId == server.identifier }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    TextField("Custom Name", text: $customName)
                    Toggle("Pinned", isOn: $isPinned)
                    Toggle("Favorite", isOn: $isFavorite)
                }
                
                Section {
                    Button("Reset Customization", role: .destructive) {
                        if let custom = customization {
                            modelContext.delete(custom)
                        }
                        dismiss()
                    }
                }
            }
            .navigationTitle("Customize Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let custom = customization {
                    customName = custom.customName ?? server.name
                    isPinned = custom.isPinned
                    isFavorite = custom.isFavorite
                } else {
                    customName = server.name
                }
            }
        }
    }
    
    private func save() {
        if let custom = customization {
            custom.customName = customName.isEmpty ? nil : customName
            custom.isPinned = isPinned
            custom.isFavorite = isFavorite
        } else {
            let newCustom = ServerCustomization(serverId: server.identifier)
            newCustom.customName = customName.isEmpty ? nil : customName
            newCustom.isPinned = isPinned
            newCustom.isFavorite = isFavorite
            modelContext.insert(newCustom)
        }
    }
}

// Helpers for Color Hex
extension Color {
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}


