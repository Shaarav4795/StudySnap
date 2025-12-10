import SwiftUI
import SwiftData

struct ShopView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @StateObject private var gamificationManager = GamificationManager.shared
    
    @State private var selectedTab: ShopTab = .avatars
    @State private var showPurchaseAlert = false
    @State private var purchaseMessage = ""
    @State private var pendingPurchase: (() -> Void)?
    @State private var selectedItemName = ""
    @State private var selectedItemCost = 0
    
    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        return gamificationManager.getOrCreateProfile(context: modelContext)
    }
    
    enum ShopTab: String, CaseIterable {
        case avatars = "Avatars"
        case themes = "Themes"
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Coin Balance Header
                coinBalanceHeader
                
                // Tab Picker
                tabPicker
                
                // Content
                ScrollView {
                    switch selectedTab {
                    case .avatars:
                        avatarsGrid
                    case .themes:
                        themesGrid
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            
            if showPurchaseAlert {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showPurchaseAlert = false
                        }
                    }
                    .zIndex(1)
                
                PurchaseConfirmationView(
                    itemName: selectedItemName,
                    itemCost: selectedItemCost,
                    onConfirm: {
                        pendingPurchase?()
                        withAnimation {
                            showPurchaseAlert = false
                        }
                    },
                    onCancel: {
                        withAnimation {
                            showPurchaseAlert = false
                        }
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
            }
        }
    }
    
    // MARK: - Coin Balance Header
    
    private var coinBalanceHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Balance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                    
                    Text("\(profile.coins)")
                        .font(.title.bold())
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Level \(profile.level)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("\(profile.totalXP) XP")
                        .font(.subheadline.bold())
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
    
    // MARK: - Tab Picker
    
    private var tabPicker: some View {
        Picker("Shop Category", selection: $selectedTab) {
            ForEach(ShopTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    // MARK: - Avatars Grid
    
    private var avatarsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(AvatarItem.allAvatars) { avatar in
                AvatarShopCard(
                    avatar: avatar,
                    isOwned: gamificationManager.isItemOwned(avatar.id, itemType: "avatar", profile: profile),
                    isSelected: profile.selectedAvatarId == avatar.id,
                    isLocked: profile.level < avatar.requiredLevel,
                    canAfford: profile.coins >= avatar.cost,
                    onSelect: {
                        _ = gamificationManager.selectAvatar(avatar.id, for: profile, context: modelContext)
                    },
                    onPurchase: {
                        selectedItemName = avatar.name
                        selectedItemCost = avatar.cost
                        pendingPurchase = {
                            if gamificationManager.purchaseAvatar(avatar, for: profile, context: modelContext) {
                                _ = gamificationManager.selectAvatar(avatar.id, for: profile, context: modelContext)
                            }
                        }
                        withAnimation {
                            showPurchaseAlert = true
                        }
                    }
                )
            }
        }
        .padding()
    }
    
    // MARK: - Themes Grid
    
    private var themesGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(ThemeItem.allThemes) { theme in
                ThemeShopCard(
                    theme: theme,
                    isOwned: gamificationManager.isItemOwned(theme.id, itemType: "theme", profile: profile),
                    isSelected: profile.selectedThemeId == theme.id,
                    isLocked: profile.level < theme.requiredLevel,
                    canAfford: profile.coins >= theme.cost,
                    onSelect: {
                        _ = gamificationManager.selectTheme(theme.id, for: profile, context: modelContext)
                    },
                    onPurchase: {
                        selectedItemName = theme.name
                        selectedItemCost = theme.cost
                        pendingPurchase = {
                            if gamificationManager.purchaseTheme(theme, for: profile, context: modelContext) {
                                _ = gamificationManager.selectTheme(theme.id, for: profile, context: modelContext)
                            }
                        }
                        withAnimation {
                            showPurchaseAlert = true
                        }
                    }
                )
            }
        }
        .padding()
    }
}

// MARK: - Avatar Shop Card

struct AvatarShopCard: View {
    let avatar: AvatarItem
    let isOwned: Bool
    let isSelected: Bool
    let isLocked: Bool
    let canAfford: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            // Avatar Image
            ZStack {
                Circle()
                    .fill(
                        isSelected ?
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 70, height: 70)
                
                if isLocked && !isOwned {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                } else {
                    Image(avatar.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .opacity(isOwned || !isLocked ? 1 : 0.5)
                }
                
                if isSelected {
                    Circle()
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 76, height: 76)
                }
            }
            
            // Name
            Text(avatar.name)
                .font(.caption.bold())
                .foregroundColor(isLocked && !isOwned ? .secondary : .primary)
                .lineLimit(1)
            
            // Status / Price
            if isOwned {
                if isSelected {
                    Text("Equipped")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                } else {
                    Button("Select") {
                        onSelect()
                    }
                    .font(.caption2.bold())
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                }
            } else if isLocked {
                Text("Lvl \(avatar.requiredLevel)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            } else {
                Button(action: onPurchase) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption2)
                        Text("\(avatar.cost)")
                            .font(.caption2.bold())
                    }
                    .foregroundColor(canAfford ? .yellow : .gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(canAfford ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                .disabled(!canAfford)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Theme Shop Card

struct ThemeShopCard: View {
    let theme: ThemeItem
    let isOwned: Bool
    let isSelected: Bool
    let isLocked: Bool
    let canAfford: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            themePreview
            themeNameLabel
            themeDescriptionLabel
            statusOrPriceView
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var themePreview: some View {
        Group {
            if theme.id == "rainbow" {
                rainbowPreview
            } else {
                standardPreview
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .opacity(isLocked && !isOwned ? 0.5 : 1)
        .overlay {
            if isLocked && !isOwned {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var rainbowPreview: some View {
        HStack(spacing: 4) {
            ForEach([Color.red, Color.orange, Color.yellow, Color.green, Color.blue, Color.purple], id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
            }
        }
    }
    
    private var standardPreview: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(colorFromString(theme.primaryColor))
                .frame(width: 40, height: 40)
            
            Circle()
                .fill(colorFromString(theme.secondaryColor))
                .frame(width: 40, height: 40)
        }
    }
    
    private var themeNameLabel: some View {
        Text(theme.name)
            .font(.subheadline.bold())
            .foregroundColor(isLocked && !isOwned ? .secondary : .primary)
    }
    
    private var themeDescriptionLabel: some View {
        Text(theme.description)
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
    }
    
    @ViewBuilder
    private var statusOrPriceView: some View {
        if isOwned {
            ownedStatusView
        } else if isLocked {
            lockedStatusView
        } else {
            purchaseButton
        }
    }
    
    @ViewBuilder
    private var ownedStatusView: some View {
        if isSelected {
            Text("Active")
                .font(.caption.bold())
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)
        } else {
            Button("Apply") {
                onSelect()
            }
            .font(.caption.bold())
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    private var lockedStatusView: some View {
        Text("Requires Level \(theme.requiredLevel)")
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
    }
    
    private var purchaseButton: some View {
        Button(action: onPurchase) {
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.caption)
                Text("\(theme.cost)")
                    .font(.caption.bold())
            }
            .foregroundColor(canAfford ? .yellow : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(canAfford ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
        .disabled(!canAfford)
    }
    
    // MARK: - Helpers
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "cyan": return .cyan
        case "teal": return .teal
        case "orange": return .orange
        case "pink": return .pink
        case "green": return .green
        case "mint": return .mint
        case "purple": return .purple
        case "indigo": return .indigo
        case "red": return .red
        case "yellow": return .yellow
        case "rainbow": return .purple
        case "navy": return Color(red: 0.0, green: 0.0, blue: 0.5)
        case "charcoal": return Color(red: 0.2, green: 0.2, blue: 0.25)
        case "slate": return Color(red: 0.4, green: 0.45, blue: 0.5)
        case "magenta": return Color(red: 1.0, green: 0.0, blue: 0.5)
        case "violet": return Color(red: 0.5, green: 0.0, blue: 1.0)
        default: return .blue
        }
    }
}

#Preview {
    NavigationStack {
        ShopView()
    }
    .modelContainer(for: [StudySet.self, UserProfile.self], inMemory: true)
}

// MARK: - Purchase Confirmation View

struct PurchaseConfirmationView: View {
    let itemName: String
    let itemCost: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon/Image
            Circle()
                .fill(themeManager.primaryGradient)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "cart.fill")
                        .font(.title)
                        .foregroundColor(.white)
                )
                .shadow(color: themeManager.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                Text("Confirm Purchase")
                    .font(.title3.bold())
                
                Text("Are you sure you want to buy")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Text(itemName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text("for")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.yellow)
                    
                    Text("\(itemCost)")
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
                .padding(.top, 4)
            }
            
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                }
                
                Button(action: onConfirm) {
                    Text("Buy Now")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.primaryGradient)
                        .cornerRadius(12)
                        .shadow(color: themeManager.primaryColor.opacity(0.3), radius: 5, x: 0, y: 3)
                }
            }
            .padding(.top, 10)
        }
        .padding(24)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 40)
    }
}
