import SwiftUI

private extension Color {
    static let oledBlack = Color(red: 0.02, green: 0.02, blue: 0.04)
    static let glassSurface = Color(red: 0.07, green: 0.09, blue: 0.16).opacity(0.85)
    static let neonCyan = Color(red: 0.15, green: 0.78, blue: 1.0)
    static let textBright = Color.white
    static let textMuted = Color(white: 0.60)
}

struct TabManagerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tabs: [WebTab]
    @Binding var activeTabId: UUID

    var body: some View {
        NavigationView {
            ZStack {
                Color.oledBlack.ignoresSafeArea()
                
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
            .navigationTitle("Otwarte Karty (\(tabs.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        addNewTab()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Nowa")
                        }
                        .foregroundColor(.neonCyan)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") {
                        dismiss()
                    }
                    .foregroundColor(.neonCyan)
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
                    .foregroundColor(.neonCyan)
                Text(tab.title.isEmpty ? "Nowa karta" : tab.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    closeTab(tab)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textMuted.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)
            
            // Preview box
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                
                VStack(spacing: 6) {
                    Image(systemName: "shield.checkerboard")
                        .font(.system(size: 26))
                        .foregroundColor(.textMuted.opacity(0.3))
                    
                    Text(hostFrom(tab.urlString))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textMuted.opacity(0.7))
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                }
            }
            .frame(height: 95)
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .background(Color.glassSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isActive ? Color.neonCyan : Color.white.opacity(0.08), lineWidth: isActive ? 1.5 : 0.8)
        )
        .shadow(color: isActive ? Color.neonCyan.opacity(0.2) : Color.clear, radius: 10)
    }
    
    private func hostFrom(_ urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
    
    private func addNewTab() {
        let newTab = WebTab(urlString: "https://www.testportal.pl")
        tabs.append(newTab)
        activeTabId = newTab.id
        dismiss()
    }
    
    private func closeTab(_ tab: WebTab) {
        if tabs.count > 1 {
            tabs.removeAll { $0.id == tab.id }
            if activeTabId == tab.id {
                activeTabId = tabs.first?.id ?? UUID()
            }
        }
    }
}
