import SwiftUI
import MapKit

struct SpotDetailSheet: View {
    let place: NearbyPlace
    @ObservedObject var vm: MapViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name:        String       = ""
    @State private var category:    SpotCategory = .other
    @State private var rating:      Int          = 3
    @State private var note:        String       = ""
    @State private var isSaving:    Bool         = false
    @State private var showSuccess: Bool         = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {

                    // Location preview
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [.nestPink, .nestPurple],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 100).cornerRadius(18)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? place.name : name)
                                .font(.title3).bold().foregroundColor(.white)
                            Text(place.address)
                                .font(.caption).foregroundColor(.white.opacity(0.8)).lineLimit(2)
                        }
                        .padding(16)
                    }
                    .padding(.horizontal)

                    // Name
                    SheetField(title: "Place Name", icon: "mappin.circle") {
                        TextField("e.g. Colombo Public Library", text: $name)
                            .padding().background(Color.nestLightPurple).cornerRadius(12)
                    }

                    // Category
                    SheetField(title: "Category", icon: "tag.fill") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(SpotCategory.allCases) { cat in
                                    Button { category = cat } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: cat.icon)
                                            Text(cat.rawValue)
                                        }
                                        .font(.caption).fontWeight(.medium)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(category == cat
                                            ? AnyView(LinearGradient(colors: [.nestPink, .nestPurple],
                                                                      startPoint: .leading, endPoint: .trailing))
                                            : AnyView(Color.nestLightPurple))
                                        .foregroundColor(category == cat ? .white : .nestPurple)
                                        .cornerRadius(20)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }

                    // Rating
                    SheetField(title: "Your Rating", icon: "star.fill") {
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { i in
                                Button { rating = i } label: {
                                    Image(systemName: i <= rating ? "star.fill" : "star")
                                        .font(.title2)
                                        .foregroundColor(i <= rating ? .nestPink : .gray.opacity(0.35))
                                }
                            }
                            Spacer()
                            Text("\(rating) / 5").font(.caption).foregroundColor(.gray)
                        }
                    }

                    // Note
                    SheetField(title: "Personal Note (optional)", icon: "note.text") {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $note)
                                .frame(minHeight: 80).padding(8)
                                .background(Color.nestLightPurple).cornerRadius(12)
                            if note.isEmpty {
                                Text("Add a note about this spot…")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(14).allowsHitTesting(false)
                            }
                        }
                    }

                    // Save button
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity).padding()
                        } else {
                            Label("Save Spot", systemImage: "bookmark.fill")
                                .frame(maxWidth: .infinity).padding()
                                .background(
                                    LinearGradient(colors: [.nestPink, .nestPurple],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundColor(.white).cornerRadius(16).bold()
                        }
                    }
                    .disabled(isSaving || name.isEmpty)
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Save Study Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.nestPurple)
                }
            }
            .overlay(alignment: .bottom) {
                if showSuccess {
                    Label("Spot saved!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Color.green).cornerRadius(20).shadow(radius: 8)
                        .padding(.bottom, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(), value: showSuccess)
        }
        .onAppear {
            name     = place.name
            category = place.category
        }
    }

    private func save() async {
        isSaving = true
        await vm.saveSpot(from: place, category: category, rating: rating, note: note)
        isSaving    = false
        showSuccess = true
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        dismiss()
    }
}

private struct SheetField<Content: View>: View {
    let title: String; let icon: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption).fontWeight(.semibold).foregroundColor(.nestPurple)
            content()
        }
        .padding(.horizontal)
    }
}
