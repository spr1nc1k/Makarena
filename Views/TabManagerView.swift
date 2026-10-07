import SwiftUI

struct TabManagerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tabs: [WebTab]
    @Binding var activeTabId: UUID

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(tabs) { tab in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(tab.title.isEmpty ? "Nowa karta" : tab.title)
                                    .font(.caption)
                                    .bold()
                                    .lineLimit(1)
                                Spacer()
                                Button(action: {
                                    closeTab(tab)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Rectangle()
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(height: 100)
                                .cornerRadius(8)
                                .overlay(
                                    VStack {
                                        Image(systemName: "safari.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray.opacity(0.4))
                                        Text(tab.urlString)
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                            .padding(.horizontal, 4)
                                    }
                                )
                        }
                        .padding(8)
                        .background(tab.id == activeTabId ? Color.blue.opacity(0.15) : Color(UIColor.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(tab.id == activeTabId ? Color.blue : Color.gray.opacity(0.2), lineWidth: tab.id == activeTabId ? 2 : 1)
                        )
                        .onTapGesture {
                            activeTabId = tab.id
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Karty (\(tabs.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        addNewTab()
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Nowa karta")
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") {
                        dismiss()
                    }
                }
            }
        }
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
