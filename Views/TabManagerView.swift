import SwiftUI

private extension Color {
    static let mkNavy = Color(red: 0.039, green: 0.055, blue: 0.102)
    static let mkSurface = Color(red: 0.067, green: 0.082, blue: 0.141)
    static let mkAccent = Color(red: 0.310, green: 0.557, blue: 1.0)
    static let mkTextPrimary = Color.white
    static let mkTextSecondary = Color(white: 0.55)
}

struct TabManagerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tabs: [WebTab]
    @Binding var activeTabId: UUID

    var body: some View {
        NavigationView {
            ZStack {
                Color.mkNavy.ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(tabs) { tab in
                            tabCard(tab)
                                .onTapGesture {
                                    activeTabId = tab.id
                                    dismiss()
                                }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Karty (\(tabs.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        addNewTab()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Nowa karta")
                        }
                        .foregroundColor(.mkAccent)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") {
                        dismiss()
                    }
                    .foregroundColor(.mkAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Tab Card
    
    private func tabCard(_ tab: WebTab) -> some View {
        let isActive = tab.id == activeTabId
        
        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                    .foregroundColor(.mkAccent)
                Text(tab.title.isEmpty ? "Nowa karta" : tab.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.mkTextPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    closeTab(tab)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.mkTextSecondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // Thumbnail placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.mkNavy)
                
                VStack(spacing: 6) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.mkTextSecondary.opacity(0.25))
                    
                    Text(hostFrom(tab.urlString))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.mkTextSecondary.opacity(0.6))
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                }
            }
            .frame(height: 100)
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .background(isActive ? Color.mkAccent.opacity(0.12) : Color.mkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isActive ? Color.mkAccent.opacity(0.6) : Color.white.opacity(0.06), lineWidth: isActive ? 1.5 : 0.5)
        )
    }
    
    private func hostFrom(_ urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }

    private func addNewTab() {
        let newTab = WebTab(urlString: "https://www.google.com")
        tabs.append(newTab)
        activeTabId = newTab.id
        dismiss()
    }

    private func closeTab(_ tab: WebTab) {
        if tabs.count > 1 {
            tabs.removeAll { $0.id == tab.id }
            if activeTabId == tab.id, let first = tabs.first {
                activeTabId = first.id
            }
        }
    }
}
