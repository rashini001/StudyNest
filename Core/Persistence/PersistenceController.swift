//
//  PersistenceController.swift
//  StudyNest
//
//  Core Data stack — fully code-based, no .xcdatamodeld file needed.
//  NSManagedObject subclasses are declared explicitly here so Xcode
//  never needs to generate them (fixes "Cannot find type in scope").
//

import CoreData
import Foundation

// MARK: - NSManagedObject Subclasses
// These MUST be declared before NSEntityDescription references them.

@objc(CDSession)
final class CDSession: NSManagedObject {
    @NSManaged var id: String?
    @NSManaged var userId: String?
    @NSManaged var subject: String?
    @NSManaged var startTime: Date?
    @NSManaged var endTime: Date?
    @NSManaged var notes: String?
    @NSManaged var isCompleted: Bool
    @NSManaged var calendarEventId: String?
    @NSManaged var createdAt: Date?
    @NSManaged var needsSync: Bool
    @NSManaged var pendingDelete: Bool

    static func fetchRequest() -> NSFetchRequest<CDSession> {
        NSFetchRequest<CDSession>(entityName: "CDSession")
    }
}

@objc(CDSpot)
final class CDSpot: NSManagedObject {
    @NSManaged var id: String?
    @NSManaged var userId: String?
    @NSManaged var name: String?
    @NSManaged var address: String?
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var category: String?
    @NSManaged var rating: Int16
    @NSManaged var personalNote: String?
    @NSManaged var savedAt: Date?
    @NSManaged var needsSync: Bool
    @NSManaged var pendingDelete: Bool

    static func fetchRequest() -> NSFetchRequest<CDSpot> {
        NSFetchRequest<CDSpot>(entityName: "CDSpot")
    }
}

@objc(CDNote)
final class CDNote: NSManagedObject {
    @NSManaged var id: String?
    @NSManaged var userId: String?
    @NSManaged var title: String?
    @NSManaged var subject: String?
    @NSManaged var localFileName: String?
    @NSManaged var pageCount: Int16
    @NSManaged var isScanned: Bool
    @NSManaged var uploadedAt: Date?
    @NSManaged var needsSync: Bool
    @NSManaged var pendingDelete: Bool

    static func fetchRequest() -> NSFetchRequest<CDNote> {
        NSFetchRequest<CDNote>(entityName: "CDNote")
    }
}

// MARK: - Persistence Controller

final class PersistenceController {

    static let shared = PersistenceController()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    // MARK: - Init

    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "StudyNest",
            managedObjectModel: Self.makeModel()
        )

        if inMemory {
            container.persistentStoreDescriptions.first?.url =
                URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error { fatalError("Core Data failed to load: \(error)") }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    static let preview = PersistenceController(inMemory: true)

    // MARK: - Save

    func save(context: NSManagedObjectContext? = nil) {
        let ctx = context ?? viewContext
        guard ctx.hasChanges else { return }
        do { try ctx.save() }
        catch { print("⚠️ Core Data save error: \(error)") }
    }

    // MARK: - Programmatic Model

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // ── CDSession ─────────────────────────────────────────────
        let sessionEntity = NSEntityDescription()
        sessionEntity.name = "CDSession"
        sessionEntity.managedObjectClassName = "CDSession"
        sessionEntity.properties = [
            strAttr("id"),
            strAttr("userId"),
            strAttr("subject"),
            dateAttr("startTime"),
            dateAttr("endTime"),
            strAttr("notes"),
            boolAttr("isCompleted"),
            strAttr("calendarEventId", optional: true),
            dateAttr("createdAt"),
            boolAttr("needsSync"),
            boolAttr("pendingDelete"),
        ]

        // ── CDSpot ────────────────────────────────────────────────
        let spotEntity = NSEntityDescription()
        spotEntity.name = "CDSpot"
        spotEntity.managedObjectClassName = "CDSpot"
        spotEntity.properties = [
            strAttr("id"),
            strAttr("userId"),
            strAttr("name"),
            strAttr("address"),
            doubleAttr("latitude"),
            doubleAttr("longitude"),
            strAttr("category"),
            int16Attr("rating"),
            strAttr("personalNote"),
            dateAttr("savedAt"),
            boolAttr("needsSync"),
            boolAttr("pendingDelete"),
        ]

        // ── CDNote ────────────────────────────────────────────────
        let noteEntity = NSEntityDescription()
        noteEntity.name = "CDNote"
        noteEntity.managedObjectClassName = "CDNote"
        noteEntity.properties = [
            strAttr("id"),
            strAttr("userId"),
            strAttr("title"),
            strAttr("subject"),
            strAttr("localFileName"),
            int16Attr("pageCount"),
            boolAttr("isScanned"),
            dateAttr("uploadedAt"),
            boolAttr("needsSync"),
            boolAttr("pendingDelete"),
        ]

        model.entities = [sessionEntity, spotEntity, noteEntity]
        return model
    }

    // MARK: - Attribute builders

    private static func strAttr(_ name: String, optional: Bool = false) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name; a.attributeType = .stringAttributeType; a.isOptional = optional
        return a
    }
    private static func dateAttr(_ name: String) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name; a.attributeType = .dateAttributeType; a.isOptional = true
        return a
    }
    private static func boolAttr(_ name: String) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name; a.attributeType = .booleanAttributeType
        a.defaultValue = false; a.isOptional = false
        return a
    }
    private static func doubleAttr(_ name: String) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name; a.attributeType = .doubleAttributeType
        a.defaultValue = 0.0; a.isOptional = false
        return a
    }
    private static func int16Attr(_ name: String) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name; a.attributeType = .integer16AttributeType
        a.defaultValue = 0; a.isOptional = false
        return a
    }
}

// MARK: - CDSession model helpers

extension CDSession {
    func toModel() -> StudySession {
        StudySession(
            id:              id,
            userId:          userId          ?? "",
            subject:         subject         ?? "",
            startTime:       startTime       ?? Date(),
            endTime:         endTime         ?? Date(),
            notes:           notes           ?? "",
            isCompleted:     isCompleted,
            calendarEventId: calendarEventId,
            createdAt:       createdAt       ?? Date()
        )
    }

    func populate(from s: StudySession) {
        id              = s.id ?? UUID().uuidString
        userId          = s.userId
        subject         = s.subject
        startTime       = s.startTime
        endTime         = s.endTime
        notes           = s.notes
        isCompleted     = s.isCompleted
        calendarEventId = s.calendarEventId
        createdAt       = s.createdAt
    }
}

// MARK: - CDSpot model helpers

extension CDSpot {
    func toModel() -> StudySpot {
        StudySpot(
            id:           id,
            userId:       userId       ?? "",
            name:         name         ?? "",
            address:      address      ?? "",
            latitude:     latitude,
            longitude:    longitude,
            category:     category     ?? "other",
            rating:       Int(rating),
            personalNote: personalNote ?? "",
            savedAt:      savedAt      ?? Date()
        )
    }

    func populate(from s: StudySpot) {
        id           = s.id ?? UUID().uuidString
        userId       = s.userId
        name         = s.name
        address      = s.address
        latitude     = s.latitude
        longitude    = s.longitude
        category     = s.category
        rating       = Int16(s.rating)
        personalNote = s.personalNote
        savedAt      = s.savedAt
    }
}

// MARK: - CDNote model helpers

extension CDNote {
    func toModel() -> PDFNote {
        PDFNote(
            id:            id,
            userId:        userId        ?? "",
            title:         title         ?? "",
            subject:       subject       ?? "",
            localFileName: localFileName ?? "",
            pageCount:     Int(pageCount),
            isScanned:     isScanned,
            uploadedAt:    uploadedAt    ?? Date()
        )
    }

    func populate(from n: PDFNote) {
        id            = n.id ?? UUID().uuidString
        userId        = n.userId
        title         = n.title
        subject       = n.subject
        localFileName = n.localFileName
        pageCount     = Int16(n.pageCount)
        isScanned     = n.isScanned
        uploadedAt    = n.uploadedAt
    }
}
