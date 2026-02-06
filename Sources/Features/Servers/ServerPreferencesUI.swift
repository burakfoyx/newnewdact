import SwiftUI
import SwiftData

// MARK: - Quick Actions Bar

struct QuickActionsBar: View {
    let serverId: String
    let currentState: String
    var onAction: ((QuickAction) -> Void)?
    
    @State private var isPerformingAction = false
    @State private var activeAction: QuickAction?
    
    private var availableActions: [QuickAction] {
        switch currentState {
        case "running":
            return [.stop, .restart, .kill]
        case "starting":
            return [.kill]
        case "stopping":
            return [.kill]
        case "offline", "stopped":
            return [.start]
        default:
            return QuickAction.allCases
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(availableActions) { action in
                QuickActionButton(
                    action: action,
                    isLoading: activeAction == action && isPerformingAction
                ) {
                    performAction(action)
                }
            }
        }
    }
    
    private func performAction(_ action: QuickAction) {
        guard !isPerformingAction else { return }
        
        activeAction = action
        isPerformingAction = true
        
        Task {
            do {
                try await PterodactylClient.shared.sendPowerAction(
                    serverId: serverId,
                    action: action.signal
                )
                
                // Haptic feedback on success
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
                
                onAction?(action)
            } catch {
                // Haptic feedback on error
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
                print("Quick action failed: \(error)")
            }
            
            await MainActor.run {
                isPerformingAction = false
                activeAction = nil
            }
        }
    }
}

struct QuickActionButton: View {
    let action: QuickAction
    let isLoading: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: action.icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Text(action.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(action.color.asColor.opacity(isLoading ? 0.5 : 1))
            .clipShape(Capsule())
        }
        .disabled(isLoading)
    }
}

// MARK: - Server Customization Sheet

struct ServerCustomizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let server: ServerAttributes
    @State private var customName: String = ""
    @State private var selectedColor: String = "#007AFF"
    @State private var selectedIcon: String = "server.rack"
    @State private var isFavorite: Bool = false
    @State private var notes: String = ""
    @State private var tags: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Preview Card
                        previewCard
                        
                        // Custom Name
                        customNameSection
                        
                        // Favorite Toggle
                        favoriteSection
                        
                        // Color Selection
                        colorSection
                        
                        // Icon Selection
                        iconSection
                        
                        // Notes
                        notesSection
                        
                        // Tags
                        tagsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Customize Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCustomization() }
                        .fontWeight(.bold)
                }
            }
        }
        .onAppear { loadExisting() }
    }
    
    private var previewCard: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(selectedColor.asColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: selectedIcon)
                    .font(.title2)
                    .foregroundStyle(selectedColor.asColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(customName.isEmpty ? server.name : customName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                
                Text(server.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding()
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var customNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Name")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            
            TextField("Override display name", text: $customName)
                .padding()
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var favoriteSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Favorite")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text("Pin to top of server list")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            Toggle("", isOn: $isFavorite)
                .tint(.yellow)
        }
        .padding()
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(ColorPreset.presets) { preset in
                    Button {
                        withAnimation { selectedColor = preset.hex }
                    } label: {
                        Circle()
                            .fill(preset.hex.asColor)
                            .frame(width: 44, height: 44)
                            .overlay {
                                if selectedColor == preset.hex {
                                    Image(systemName: "checkmark")
                                        .font(.headline.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
            .padding()
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(IconPreset.presets) { preset in
                    Button {
                        withAnimation { selectedIcon = preset.symbol }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedIcon == preset.symbol ? selectedColor.asColor.opacity(0.3) : Color.white.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: preset.symbol)
                                .font(.title3)
                                .foregroundStyle(selectedIcon == preset.symbol ? selectedColor.asColor : .white.opacity(0.7))
                        }
                    }
                }
            }
            .padding()
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            
            TextEditor(text: $notes)
                .frame(height: 80)
                .scrollContentBackground(.hidden)
                .padding(8)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            
            TextField("Comma separated tags", text: $tags)
                .padding()
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func loadExisting() {
        let descriptor = FetchDescriptor<ServerCustomization>(
            predicate: #Predicate { $0.serverId == server.identifier }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            customName = existing.customName ?? ""
            selectedColor = existing.colorHex ?? "#007AFF"
            selectedIcon = existing.icon ?? "server.rack"
            isFavorite = existing.isFavorite
            notes = existing.notes ?? ""
            tags = existing.tags.joined(separator: ", ")
        }
    }
    
    private func saveCustomization() {
        let descriptor = FetchDescriptor<ServerCustomization>(
            predicate: #Predicate { $0.serverId == server.identifier }
        )
        
        let customization: ServerCustomization
        if let existing = try? modelContext.fetch(descriptor).first {
            customization = existing
        } else {
            customization = ServerCustomization(serverId: server.identifier)
            modelContext.insert(customization)
        }
        
        customization.customName = customName.isEmpty ? nil : customName
        customization.colorHex = selectedColor
        customization.icon = selectedIcon
        customization.isFavorite = isFavorite
        customization.notes = notes.isEmpty ? nil : notes
        customization.tags = tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        customization.updatedAt = Date()
        
        dismiss()
    }
}

// MARK: - Server Groups Manager View

struct ServerGroupsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ServerGroup.sortOrder) private var groups: [ServerGroup]
    
    @State private var showCreateGroup = false
    @State private var editingGroup: ServerGroup?
    
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    private var canCreateMore: Bool {
        if subscriptionManager.currentTier == .host { return true }
        if subscriptionManager.currentTier == .pro { return groups.count < 5 }
        return groups.count < 2 // Free tier: 2 groups
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                if groups.isEmpty {
                    emptyState
                } else {
                    groupsList
                }
            }
            .navigationTitle("Server Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if canCreateMore {
                            showCreateGroup = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!canCreateMore)
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                GroupEditorSheet(group: nil)
            }
            .sheet(item: $editingGroup) { group in
                GroupEditorSheet(group: group)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.4))
            
            Text("No Groups")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            Text("Create groups to organize your servers")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            
            Button("Create Group") {
                showCreateGroup = true
            }
            .buttonStyle(LiquidButtonStyle())
        }
    }
    
    private var groupsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groups) { group in
                    GroupRowItem(group: group) {
                        editingGroup = group
                    } onDelete: {
                        modelContext.delete(group)
                    }
                }
                
                // Limit info
                if !canCreateMore {
                    HStack {
                        Image(systemName: "info.circle")
                        Text(subscriptionManager.currentTier == .pro ? "Pro limit: 5 groups" : "Free limit: 2 groups")
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding()
                }
            }
            .padding()
        }
    }
}

struct GroupRowItem: View {
    let group: ServerGroup
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(group.colorHex.asColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: group.icon)
                    .font(.title3)
                    .foregroundStyle(group.colorHex.asColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("\(group.serverIds.count) servers")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding()
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button("Edit", systemImage: "pencil") { onEdit() }
            Button("Delete", systemImage: "trash", role: .destructive) { onDelete() }
        }
    }
}

struct GroupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let group: ServerGroup?
    
    @State private var name: String = ""
    @State private var selectedColor: String = "#007AFF"
    @State private var selectedIcon: String = "folder.fill"
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Group Name")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            
                            TextField("Enter name", text: $name)
                                .padding()
                                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Color
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                                ForEach(ColorPreset.presets) { preset in
                                    Button {
                                        withAnimation { selectedColor = preset.hex }
                                    } label: {
                                        Circle()
                                            .fill(preset.hex.asColor)
                                            .frame(width: 44, height: 44)
                                            .overlay {
                                                if selectedColor == preset.hex {
                                                    Image(systemName: "checkmark")
                                                        .font(.headline.bold())
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                    }
                                }
                            }
                            .padding()
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Icon
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Icon")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                ForEach(IconPreset.presets) { preset in
                                    Button {
                                        withAnimation { selectedIcon = preset.symbol }
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedIcon == preset.symbol ? selectedColor.asColor.opacity(0.3) : Color.white.opacity(0.1))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: preset.symbol)
                                                .font(.title3)
                                                .foregroundStyle(selectedIcon == preset.symbol ? selectedColor.asColor : .white.opacity(0.7))
                                        }
                                    }
                                }
                            }
                            .padding()
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(group == nil ? "New Group" : "Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let group = group {
                    name = group.name
                    selectedColor = group.colorHex
                    selectedIcon = group.icon
                }
            }
        }
    }
    
    private func save() {
        if let group = group {
            group.name = name
            group.colorHex = selectedColor
            group.icon = selectedIcon
        } else {
            let newGroup = ServerGroup(
                name: name,
                colorHex: selectedColor,
                icon: selectedIcon
            )
            modelContext.insert(newGroup)
        }
        dismiss()
    }
}

// MARK: - Refresh Interval Picker

struct RefreshIntervalPicker: View {
    @Binding var selection: RefreshInterval
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Refresh Interval")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            
            VStack(spacing: 8) {
                ForEach(RefreshInterval.allCases) { interval in
                    Button {
                        if !interval.requiresPro || subscriptionManager.currentTier != .free {
                            selection = interval
                        }
                    } label: {
                        HStack {
                            Text(interval.displayName)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            if interval.requiresPro && subscriptionManager.currentTier == .free {
                                Text("PRO")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.purple)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            
                            if selection == interval {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(interval.requiresPro && subscriptionManager.currentTier == .free)
                }
            }
        }
    }
}
