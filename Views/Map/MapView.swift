import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var vm       = MapViewModel()
    @State private var showSavedList  = false
    @State private var pendingPlace: NearbyPlace? = nil
    @State private var showSaveSheet  = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                Map(position: $vm.position) {
               
                    UserAnnotation()

                    ForEach(combinedAnnotations) { ann in
                        Annotation("", coordinate: ann.coordinate, anchor: .bottom) {
                            switch ann.kind {
                            case .nearby(let place):
                                NearbyPin(place: place, isSaved: vm.isAlreadySaved(place))
                                    .onTapGesture { vm.selectedNearby = place }
                            case .saved(let spot):
                                SavedPin(spot: spot)
                                    .onTapGesture { vm.selectedSaved = spot }
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .ignoresSafeArea()

                VStack(spacing: 8) {
                   
                    HStack(spacing: 10) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.gray)
                            TextField("Search libraries, cafes, spots…", text: $vm.searchText)
                                .submitLabel(.search)
                                .onSubmit { Task { await vm.search() } }
                            if !vm.searchText.isEmpty {
                                Button { vm.clearSearch() } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)

                        Button { Task { await vm.search() } } label: {
                            Group {
                                if vm.isSearching {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Search").fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(
                                LinearGradient(colors: [.nestPink, .nestPurple],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChipMap(label: "All", icon: "mappin.and.ellipse",
                                          isSelected: vm.activeFilter == nil) {
                                vm.activeFilter = nil
                            }
                            ForEach(SpotCategory.allCases.filter { $0 != .other }) { cat in
                                FilterChipMap(label: cat.rawValue, icon: cat.icon,
                                              isSelected: vm.activeFilter == cat) {
                                    vm.activeFilter = (vm.activeFilter == cat) ? nil : cat
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    if !vm.searchResults.isEmpty {
                        SearchDropdown(results: vm.searchResults,
                                       isSaved: vm.isAlreadySaved) { place in
                            withAnimation { vm.position = .region(MKCoordinateRegion(
                                center: place.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                            )) }
                            vm.searchResults = []
                            vm.searchText    = ""
                            pendingPlace     = place
                            showSaveSheet    = true
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Button { vm.recenterOnUser() } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(.systemBackground))
                                        .frame(width: 46, height: 46)
                                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                                    if vm.isLocating {
                                        ProgressView().tint(.nestPurple)
                                    } else {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.nestPurple)
                                            .font(.system(size: 18))
                                    }
                                }
                            }
                            Button { showSavedList = true } label: {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.nestPink, .nestPurple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing))
                                        .frame(width: 52, height: 52)
                                        .shadow(color: .nestPurple.opacity(0.4), radius: 8, y: 4)
                                    VStack(spacing: 1) {
                                        Image(systemName: "bookmark.fill")
                                            .foregroundColor(.white).font(.system(size: 16))
                                        Text("\(vm.savedSpots.count)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
                if vm.locationStatus == .denied || vm.locationStatus == .restricted {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "location.slash.fill")
                                .foregroundColor(.nestPink)
                            Text("Location access denied — showing default area.")
                                .font(.caption)
                                .foregroundColor(.nestDark)
                            Spacer()
                            Button("Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption.bold())
                            .foregroundColor(.nestPurple)
                        }
                        .padding(12)
                        .background(Color(.systemBackground).opacity(0.95))
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Study Spots")
            .navigationBarTitleDisplayMode(.inline)
            .task { await vm.initialLoad() }

            // Nearby place detail
            .sheet(item: $vm.selectedNearby) { place in
                NearbyPlaceDetailView(place: place,
                                      isSaved: vm.isAlreadySaved(place),
                                      vm: vm)
            }
            // Saved spot detail
            .sheet(item: $vm.selectedSaved) { spot in
                SavedSpotDetailView(spot: spot, vm: vm)
            }
            // Save sheet from search result
            .sheet(isPresented: $showSaveSheet, onDismiss: { pendingPlace = nil }) {
                if let place = pendingPlace {
                    SpotDetailSheet(place: place, vm: vm)
                }
            }
            // Saved list
            .sheet(isPresented: $showSavedList) {
                SavedSpotsListView(vm: vm)
            }
        }
    }


    private var combinedAnnotations: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = vm.displayedNearby.map {
            MapAnnotationItem(id: $0.id.uuidString, coordinate: $0.coordinate, kind: .nearby($0))
        }
        for spot in vm.savedSpots {
            let alreadyShown = vm.displayedNearby.contains {
                abs($0.coordinate.latitude  - spot.latitude)  < 0.0002 &&
                abs($0.coordinate.longitude - spot.longitude) < 0.0002
            }
            if !alreadyShown {
                items.append(MapAnnotationItem(
                    id: spot.id ?? UUID().uuidString,
                    coordinate: CLLocationCoordinate2D(latitude: spot.latitude,
                                                       longitude: spot.longitude),
                    kind: .saved(spot)
                ))
            }
        }
        return items
    }
}


struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    enum Kind { case nearby(NearbyPlace); case saved(StudySpot) }
    let kind: Kind
}

// NearbyPin

struct NearbyPin: View {
    let place:   NearbyPlace
    let isSaved: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isSaved ? Color.nestPurple : place.category.pinColor)
                    .frame(width: 36, height: 36)
                    .shadow(color: place.category.pinColor.opacity(0.4), radius: 4)
                Image(systemName: isSaved ? "bookmark.fill" : place.category.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            PinTriangle().fill(isSaved ? Color.nestPurple : place.category.pinColor)
                .frame(width: 10, height: 6)
            Text(place.name)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.white.opacity(0.9))
                .cornerRadius(4)
        }
    }
}

// SavedPin

struct SavedPin: View {
    let spot: StudySpot
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.nestPink, .nestPurple],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.nestPurple.opacity(0.4), radius: 4)
                Image(systemName: SpotCategory(rawValue: spot.category)?.icon ?? "mappin.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            PinTriangle()
                .fill(LinearGradient(colors: [.nestPink, .nestPurple],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 10, height: 6)
            Text(spot.name)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.white.opacity(0.9))
                .cornerRadius(4)
        }
    }
}

struct PinTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}


struct FilterChipMap: View {
    let label: String; let icon: String
    let isSelected: Bool; let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isSelected
                ? AnyView(LinearGradient(colors: [.nestPink, .nestPurple],
                                          startPoint: .leading, endPoint: .trailing))
                : AnyView(Color(.systemBackground)))
            .foregroundColor(isSelected ? .white : .nestDark)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.07), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// SearchDropdown

struct SearchDropdown: View {
    let results: [NearbyPlace]
    let isSaved: (NearbyPlace) -> Bool
    let onTap:   (NearbyPlace) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(results.prefix(6)) { place in
                Button { onTap(place) } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(place.category.pinColor.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: place.category.icon)
                                .foregroundColor(place.category.pinColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name).font(.subheadline).fontWeight(.medium)
                                .foregroundColor(.nestDark).lineLimit(1)
                            Text(place.address).font(.caption).foregroundColor(.gray).lineLimit(1)
                        }
                        Spacer()
                        if isSaved(place) {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.nestPurple).font(.caption)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if place.id != results.prefix(6).last?.id {
                    Divider().padding(.leading, 58)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
    }
}

// NearbyPlaceDetailView

struct NearbyPlaceDetailView: View {
    let place:   NearbyPlace
    let isSaved: Bool
    @ObservedObject var vm: MapViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showSaveSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [place.category.pinColor,
                                                place.category.pinColor.opacity(0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 140)
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack {
                                Circle().fill(Color.white.opacity(0.25)).frame(width: 46, height: 46)
                                Image(systemName: place.category.icon)
                                    .font(.title2).foregroundColor(.white)
                            }
                            Text(place.name).font(.title3).bold().foregroundColor(.white)
                            Text(place.category.rawValue)
                                .font(.caption).foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.white.opacity(0.2)).cornerRadius(8)
                        }
                        .padding(16)
                    }

                    VStack(spacing: 16) {
                        InfoRowMap(icon: "mappin.and.ellipse", label: "Address", value: place.address)
                        Divider()
                        HStack(spacing: 12) {
                            ActionButton(icon: "arrow.triangle.turn.up.right.circle.fill",
                                         label: "Directions", color: .blue) {
                                vm.openDirections(to: place.coordinate, name: place.name)
                            }
                            if isSaved {
                                ActionButton(icon: "bookmark.fill", label: "Saved",
                                             color: .nestPurple) { }.opacity(0.6)
                            } else {
                                ActionButton(icon: "bookmark", label: "Save Spot",
                                             color: .nestPink) {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showSaveSheet = true
                                    }
                                }
                            }
                            ActionButton(icon: "map.fill", label: "Open Maps", color: .green) {
                                place.item.openInMaps()
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.nestPurple)
                }
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            SpotDetailSheet(place: place, vm: vm)
        }
    }
}

// SavedSpotDetailView

struct SavedSpotDetailView: View {
    let spot: StudySpot
    @ObservedObject var vm: MapViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [.nestPink, .nestPurple],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 140)
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack {
                                Circle().fill(Color.white.opacity(0.25)).frame(width: 46, height: 46)
                                Image(systemName: SpotCategory(rawValue: spot.category)?.icon
                                      ?? "mappin.circle.fill")
                                    .font(.title2).foregroundColor(.white)
                            }
                            Text(spot.name).font(.title3).bold().foregroundColor(.white)
                            Text(spot.category)
                                .font(.caption).foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.white.opacity(0.2)).cornerRadius(8)
                        }
                        .padding(16)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        InfoRowMap(icon: "mappin.and.ellipse", label: "Address", value: spot.address)
                        Divider()
                        HStack {
                            Image(systemName: "star.fill").foregroundColor(.nestPink)
                            Text("Rating").font(.subheadline).foregroundColor(.gray)
                            Spacer()
                            HStack(spacing: 3) {
                                ForEach(1...5, id: \.self) { i in
                                    Image(systemName: i <= spot.rating ? "star.fill" : "star")
                                        .font(.system(size: 13))
                                        .foregroundColor(i <= spot.rating ? .nestPink : .gray.opacity(0.3))
                                }
                            }
                        }
                        .padding(.horizontal)

                        if !spot.personalNote.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Personal Note", systemImage: "note.text")
                                    .font(.caption).foregroundColor(.gray)
                                Text(spot.personalNote)
                                    .font(.body).foregroundColor(.nestDark)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.nestLightPurple.opacity(0.5))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }

                        Divider()
                        HStack(spacing: 12) {
                            ActionButton(icon: "arrow.triangle.turn.up.right.circle.fill",
                                         label: "Directions", color: .blue) {
                                vm.openDirections(
                                    to: CLLocationCoordinate2D(latitude: spot.latitude,
                                                               longitude: spot.longitude),
                                    name: spot.name)
                            }
                            ActionButton(icon: "map.fill", label: "Open Maps", color: .green) {
                                let pl = MKPlacemark(coordinate:
                                    CLLocationCoordinate2D(latitude: spot.latitude,
                                                           longitude: spot.longitude))
                                MKMapItem(placemark: pl).openInMaps()
                            }
                        }
                        .padding(.horizontal)

                        Button(role: .destructive) {
                            Task { await vm.deleteSpot(spot); dismiss() }
                        } label: {
                            Label("Remove from Saved", systemImage: "trash")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.red.opacity(0.08))
                                .foregroundColor(.red).cornerRadius(14)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.nestPurple)
                }
            }
        }
    }
}

// SavedSpotsListView

struct SavedSpotsListView: View {
    @ObservedObject var vm: MapViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.savedSpots.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 50)).foregroundColor(.nestLightPurple)
                        Text("No saved spots yet").font(.headline).foregroundColor(.gray)
                        Text("Search for a location and save it as a favourite.")
                            .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(vm.savedSpots) { spot in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Color.nestLightPurple).frame(width: 40, height: 40)
                                    Image(systemName: SpotCategory(rawValue: spot.category)?.icon
                                          ?? "mappin.circle.fill")
                                        .foregroundColor(.nestPurple)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(spot.name).font(.subheadline).fontWeight(.semibold)
                                    Text(spot.address).font(.caption).foregroundColor(.gray).lineLimit(1)
                                    HStack(spacing: 2) {
                                        ForEach(1...5, id: \.self) { i in
                                            Image(systemName: i <= spot.rating ? "star.fill" : "star")
                                                .font(.system(size: 10))
                                                .foregroundColor(i <= spot.rating ? .nestPink : .gray.opacity(0.4))
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete { idx in
                            idx.forEach { i in Task { await vm.deleteSpot(vm.savedSpots[i]) } }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved Spots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.nestPurple)
                }
            }
        }
    }
}


struct InfoRowMap: View {
    let icon: String; let label: String; let value: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundColor(.nestPurple).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundColor(.gray)
                Text(value).font(.subheadline).foregroundColor(.nestDark)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct ActionButton: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 46, height: 46)
                    Image(systemName: icon).font(.title3).foregroundColor(color)
                }
                Text(label).font(.caption).fontWeight(.medium).foregroundColor(.nestDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}
