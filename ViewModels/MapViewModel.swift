import Foundation
import MapKit
import CoreLocation
import Combine
import SwiftUI

// SpotCategory

enum SpotCategory: String, CaseIterable, Identifiable {
    case library    = "Library"
    case cafe       = "Cafe"
    case university = "University"
    case park       = "Park"
    case other      = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .library:    return "books.vertical.fill"
        case .cafe:       return "cup.and.saucer.fill"
        case .university: return "building.columns.fill"
        case .park:       return "leaf.fill"
        case .other:      return "mappin.circle.fill"
        }
    }

    var pinColor: Color {
        switch self {
        case .library:    return .blue
        case .cafe:       return .brown
        case .university: return .purple
        case .park:       return .green
        case .other:      return .nestPink
        }
    }

    var searchKeyword: String {
        switch self {
        case .library:    return "library"
        case .cafe:       return "cafe coffee"
        case .university: return "university college"
        case .park:       return "park"
        case .other:      return ""
        }
    }
}

//NearbyPlace

struct NearbyPlace: Identifiable {
    let id       = UUID()
    let item:    MKMapItem
    var name:    String  { item.name ?? "Unknown" }
    var address: String  { item.placemark.title ?? "" }
    var coordinate: CLLocationCoordinate2D { item.placemark.coordinate }
    var category: SpotCategory
}

// MapViewModel

@MainActor
final class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    //Map position
    @Published var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    )

    @Published var visibleCenter: CLLocationCoordinate2D =
        CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612)

    @Published var userLocation: CLLocationCoordinate2D? = nil

    // Saved spots
    @Published var savedSpots: [StudySpot] = []

    // Nearby POIs
    @Published var nearbyPlaces: [NearbyPlace] = []

    // Search
    @Published var searchText:    String        = ""
    @Published var searchResults: [NearbyPlace] = []
    @Published var isSearching:   Bool          = false

    // Selection
    @Published var selectedNearby: NearbyPlace? = nil
    @Published var selectedSaved:  StudySpot?   = nil

    // UI state
    @Published var isLoading:    Bool   = false
    @Published var errorMessage: String = ""
    @Published var activeFilter: SpotCategory? = nil

    // Location state
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocating: Bool = false

    private let firestore        = FirestoreService.shared
    private let locationManager  = CLLocationManager()
    private var userId: String   { AuthService.shared.currentUserId ?? "" }
    private var didCenterOnUser  = false

    override init() {
        super.init()
        locationManager.delegate           = self
        locationManager.desiredAccuracy    = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter     = 50
    }

    func initialLoad() async {
        await loadSavedSpots()
        requestLocation()
    }

    func requestLocation() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            isLocating = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isLocating = true
            locationManager.requestLocation()
        case .denied, .restricted:
            isLocating = false
            Task { await loadNearbyPlaces() }
        @unknown default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            locationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                isLocating = true
                manager.requestLocation()
            case .denied, .restricted:
                isLocating = false
                await loadNearbyPlaces()
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { @MainActor in
            isLocating   = false
            userLocation = loc.coordinate
            visibleCenter = loc.coordinate
            if !didCenterOnUser {
                didCenterOnUser = true
                withAnimation(.easeInOut(duration: 0.8)) {
                    position = .region(MKCoordinateRegion(
                        center: loc.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                    ))
                }
            }
            await loadNearbyPlaces()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in
            isLocating = false
            if nearbyPlaces.isEmpty { await loadNearbyPlaces() }
        }
    }

    // Saved Spots

    func loadSavedSpots() async {
        savedSpots = (try? await firestore.fetchSpots(for: userId)) ?? []
    }

    func saveSpot(from place: NearbyPlace, category: SpotCategory,
                  rating: Int, note: String) async {
        let spot = StudySpot(
            userId: userId,
            name: place.name,
            address: place.address,
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            category: category.rawValue,
            rating: rating,
            personalNote: note,
            savedAt: Date()
        )
        try? await firestore.saveSpot(spot)
        await loadSavedSpots()
    }

    func deleteSpot(_ spot: StudySpot) async {
        guard let id = spot.id else { return }
        try? await firestore.deleteSpot(id: id)
        await loadSavedSpots()
    }

    func isAlreadySaved(_ place: NearbyPlace) -> Bool {
        savedSpots.contains {
            abs($0.latitude  - place.coordinate.latitude)  < 0.0002 &&
            abs($0.longitude - place.coordinate.longitude) < 0.0002
        }
    }

    // Nearby POIs

    func loadNearbyPlaces() async {
        let centre = userLocation ?? visibleCenter
        var results: [NearbyPlace] = []

        let categories: [SpotCategory] = [.library, .cafe, .university, .park]
        await withTaskGroup(of: [NearbyPlace].self) { group in
            for cat in categories {
                group.addTask {
                    await self.searchNearby(keyword: cat.searchKeyword,
                                            center: centre,
                                            category: cat)
                }
            }
            for await places in group { results.append(contentsOf: places) }
        }
        nearbyPlaces = results
    }

    private func searchNearby(keyword: String,
                               center: CLLocationCoordinate2D,
                               category: SpotCategory) async -> [NearbyPlace] {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = keyword
        req.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
        )
        let items = (try? await MKLocalSearch(request: req).start())?.mapItems ?? []
        return items.prefix(8).map { NearbyPlace(item: $0, category: category) }
    }

    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { searchResults = []; return }
        isSearching   = true
        let centre    = userLocation ?? visibleCenter
        let req       = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.region = MKCoordinateRegion(
            center: centre,
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
        let items = (try? await MKLocalSearch(request: req).start())?.mapItems ?? []
        searchResults = items.map { NearbyPlace(item: $0, category: guessCategory($0)) }
        isSearching   = false

        if let first = searchResults.first {
            withAnimation {
                position = .region(MKCoordinateRegion(
                    center: first.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                ))
                visibleCenter = first.coordinate
            }
        }
    }

    func clearSearch() {
        searchText    = ""
        searchResults = []
    }

    func recenterOnUser() {
        guard let loc = userLocation else {
            requestLocation(); return
        }
        withAnimation(.easeInOut(duration: 0.6)) {
            position = .userLocation(fallback: .region(MKCoordinateRegion(
                center: loc,
                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
            )))
        }
    }

    // Directions

    func openDirections(to coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item      = MKMapItem(placemark: placemark)
        item.name     = name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    var displayedNearby: [NearbyPlace] {
        let base = searchResults.isEmpty ? nearbyPlaces : searchResults
        guard let filter = activeFilter else { return base }
        return base.filter { $0.category == filter }
    }

    private func guessCategory(_ item: MKMapItem) -> SpotCategory {
        let name = (item.name ?? "").lowercased()
        if name.contains("library")                              { return .library }
        if name.contains("cafe") || name.contains("coffee")     { return .cafe }
        if name.contains("university") || name.contains("college") { return .university }
        if name.contains("park")                                 { return .park }
        return .other
    }
}
