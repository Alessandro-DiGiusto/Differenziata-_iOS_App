//
//  WasteProfileStore.swift
//  Acireale Differenziata
//

import Combine
import Foundation

// MARK: - App Group (condivisione con widget)

extension UserDefaults {
    /// UserDefaults condiviso tra app e widget tramite App Group.
    static let appGroup: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: AppGroupIdentifier.suiteName) else {
            return .standard
        }
        return defaults
    }()
}

enum AppGroupIdentifier {
    /// App Group da abilitare in Xcode:
    /// Target → Signing & Capabilities → + → App Groups
    static let suiteName = "group.it.alessandrodigiusto.Differenziata"

    /// Chiave UserDefaults per il profilo serializzato
    static let profileKey = "widget.currentProfile"
}

struct WasteCollectionDay: Codable, Equatable, Hashable, Identifiable {
    let weekday: Int
    var materialIDs: [String]
    var includesSupplementaryDiapers: Bool

    var id: Int { weekday }

    init(weekday: Int, materialIDs: [String] = [], includesSupplementaryDiapers: Bool = false) {
        self.weekday = weekday
        self.materialIDs = materialIDs
        self.includesSupplementaryDiapers = includesSupplementaryDiapers
    }
}

struct MunicipalityProfile: Codable, Equatable {
    static let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1]

    private static let weekdayNamesByID: [Int: String] = [
        1: "Domenica",
        2: "Lunedì",
        3: "Martedì",
        4: "Mercoledì",
        5: "Giovedì",
        6: "Venerdì",
        7: "Sabato"
    ]

    var municipalityName: String
    var collectionDays: [WasteCollectionDay]

    init(municipalityName: String, collectionDays: [WasteCollectionDay]) {
        self.municipalityName = municipalityName
        self.collectionDays = Self.normalizedDays(collectionDays)
    }

    static var acirealeTemplate: MunicipalityProfile {
        MunicipalityProfile(
            municipalityName: "Acireale",
            collectionDays: [
                WasteCollectionDay(weekday: 2, materialIDs: ["organico"], includesSupplementaryDiapers: true),
                WasteCollectionDay(weekday: 3, materialIDs: ["secco"], includesSupplementaryDiapers: true),
                WasteCollectionDay(weekday: 4, materialIDs: ["organico", "vetro"]),
                WasteCollectionDay(weekday: 5, materialIDs: ["plastica"], includesSupplementaryDiapers: true),
                WasteCollectionDay(weekday: 6, materialIDs: ["carta"], includesSupplementaryDiapers: true),
                WasteCollectionDay(weekday: 7, materialIDs: ["organico", "metallo"])
            ]
        )
    }

    func normalized() -> MunicipalityProfile {
        MunicipalityProfile(
            municipalityName: municipalityName.trimmingCharacters(in: .whitespacesAndNewlines),
            collectionDays: collectionDays
        )
    }

    func day(for weekday: Int) -> WasteCollectionDay {
        collectionDays.first(where: { $0.weekday == weekday }) ?? WasteCollectionDay(weekday: weekday)
    }

    func includesMaterial(_ materialID: String, on weekday: Int) -> Bool {
        day(for: weekday).materialIDs.contains(materialID)
    }

    var hasAnyConfiguredPickup: Bool {
        collectionDays.contains { !$0.materialIDs.isEmpty || $0.includesSupplementaryDiapers }
    }

    var configuredDayCount: Int {
        collectionDays.reduce(into: 0) { count, day in
            if !day.materialIDs.isEmpty || day.includesSupplementaryDiapers {
                count += 1
            }
        }
    }

    mutating func toggleMaterial(_ materialID: String, for weekday: Int) {
        updateDay(weekday) { day in
            if let index = day.materialIDs.firstIndex(of: materialID) {
                day.materialIDs.remove(at: index)
            } else {
                day.materialIDs.append(materialID)
            }
        }
    }

    mutating func setSupplementaryDiapers(_ enabled: Bool, for weekday: Int) {
        updateDay(weekday) { day in
            day.includesSupplementaryDiapers = enabled
        }
    }

    @MainActor
    func pickupSummary(for weekday: Int, fallback: String = "Nessun ritiro") -> String {
        let day = day(for: weekday)
        var pieces = day.materialIDs.compactMap { WasteCatalog.material(for: $0)?.name }
        if day.includesSupplementaryDiapers {
            pieces.append("Pannolini")
        }

        guard !pieces.isEmpty else {
            return fallback
        }

        return pieces.joined(separator: ", ")
    }

    static func dayName(for weekday: Int) -> String {
        weekdayNamesByID[weekday] ?? "Giorno"
    }

    private mutating func updateDay(_ weekday: Int, transform: (inout WasteCollectionDay) -> Void) {
        var updatedDays = collectionDays
        let index = updatedDays.firstIndex(where: { $0.weekday == weekday }) ?? updatedDays.endIndex

        if index == updatedDays.endIndex {
            var newDay = WasteCollectionDay(weekday: weekday)
            transform(&newDay)
            updatedDays.append(newDay)
        } else {
            transform(&updatedDays[index])
        }

        collectionDays = Self.normalizedDays(updatedDays)
    }

    private static func normalizedDays(_ days: [WasteCollectionDay]) -> [WasteCollectionDay] {
        var mergedDays = Dictionary(uniqueKeysWithValues: orderedWeekdays.map { ($0, WasteCollectionDay(weekday: $0)) })

        for day in days {
            mergedDays[day.weekday] = WasteCollectionDay(
                weekday: day.weekday,
                materialIDs: uniquePreservingOrder(day.materialIDs),
                includesSupplementaryDiapers: day.includesSupplementaryDiapers
            )
        }

        return orderedWeekdays.map { mergedDays[$0] ?? WasteCollectionDay(weekday: $0) }
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { value in
            seen.insert(value).inserted
        }
    }
}

final class WasteProfileStore: ObservableObject {
    static let shared = WasteProfileStore()

    @Published private(set) var currentProfile: MunicipalityProfile
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published var isEditingProfile = false

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()

    private static let profileKey = "waste.profile.v1"
    private static let onboardingKey = "waste.profile.onboarding.completed"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let decoder = JSONDecoder()
        self.currentProfile = Self.loadProfile(from: defaults, decoder: decoder) ?? .acirealeTemplate
        self.hasCompletedOnboarding = defaults.bool(forKey: Self.onboardingKey)
    }

    func save(profile: MunicipalityProfile) {
        let normalizedProfile = profile.normalized()
        currentProfile = normalizedProfile
        hasCompletedOnboarding = true
        isEditingProfile = false

        do {
            let data = try encoder.encode(normalizedProfile)
            defaults.set(data, forKey: Self.profileKey)
            // Condivisione con widget via App Group
            UserDefaults.appGroup.set(data, forKey: AppGroupIdentifier.profileKey)
        } catch {
            print("[WasteProfileStore] Errore codifica profilo: \(error)")
        }

        defaults.set(true, forKey: Self.onboardingKey)
    }

    func startEditing() {
        isEditingProfile = true
    }

    func dismissEditor() {
        isEditingProfile = false
    }

    private static func loadProfile(from defaults: UserDefaults, decoder: JSONDecoder) -> MunicipalityProfile? {
        guard let data = defaults.data(forKey: Self.profileKey) else {
            return nil
        }

        return try? decoder.decode(MunicipalityProfile.self, from: data)
    }
}
