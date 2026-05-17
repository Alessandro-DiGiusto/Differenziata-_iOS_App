//
//  DifferenziataProvider.swift
//  DifferenziataWidgetExtension
//
//  Timeline provider: legge il profilo dall'App Group e calcola
//  cosa esporre domani mattina. Self-contained (nessuna dipendenza dall'app).
//

import WidgetKit

// MARK: - Modello minimale per decodificare il JSON salvato dall'app

private struct WidgetProfile: Codable {
    let municipalityName: String
    let collectionDays: [WidgetCollectionDay]

    func day(for weekday: Int) -> WidgetCollectionDay {
        collectionDays.first { $0.weekday == weekday } ?? WidgetCollectionDay(weekday: weekday)
    }
}

private struct WidgetCollectionDay: Codable {
    let weekday: Int
    let materialIDs: [String]
    let includesSupplementaryDiapers: Bool

    init(weekday: Int, materialIDs: [String] = [], includesSupplementaryDiapers: Bool = false) {
        self.weekday = weekday
        self.materialIDs = materialIDs
        self.includesSupplementaryDiapers = includesSupplementaryDiapers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weekday = try container.decode(Int.self, forKey: .weekday)
        materialIDs = try container.decodeIfPresent([String].self, forKey: .materialIDs) ?? []
        includesSupplementaryDiapers = try container.decodeIfPresent(Bool.self, forKey: .includesSupplementaryDiapers) ?? false
    }
}

// MARK: - Provider

struct DifferenziataProvider: TimelineProvider {

    // MARK: - Placeholder
    func placeholder(in context: Context) -> DifferenziataEntry {
        .placeholder
    }

    // MARK: - Snapshot
    func getSnapshot(in context: Context, completion: @escaping (DifferenziataEntry) -> Void) {
        let entry = loadEntry() ?? .placeholder
        completion(entry)
    }

    // MARK: - Timeline
    func getTimeline(in context: Context, completion: @escaping (Timeline<DifferenziataEntry>) -> Void) {
        let entry = loadEntry() ?? DifferenziataEntry(
            date: Date(),
            municipalityName: "Apri l'app",
            tomorrowMaterialIDs: [],
            tomorrowMaterialNames: ["Configura il tuo comune"],
            includesDiapers: false,
            isConfigured: false
        )

        // Prossimo refresh: tra 2 ore o a mezzanotte (quello che arriva prima)
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let nextMidnight = calendar.startOfDay(for: now).addingTimeInterval(86_400)
        let nextRefresh = min(
            now.addingTimeInterval(7200),
            nextMidnight
        )

        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    // MARK: - Helper

    private func loadEntry() -> DifferenziataEntry? {
        guard let data = UserDefaults.appGroup.data(forKey: AppGroupIdentifier.profileKey),
              let profile = try? JSONDecoder().decode(WidgetProfile.self, from: data)
        else {
            return nil
        }

        let calendar = Calendar.autoupdatingCurrent
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let weekday = calendar.component(.weekday, from: tomorrow)

        let day = profile.day(for: weekday)
        let names = day.materialIDs.compactMap { Self.materialName(for: $0) }

        return DifferenziataEntry(
            date: Date(),
            municipalityName: profile.municipalityName,
            tomorrowMaterialIDs: day.materialIDs,
            tomorrowMaterialNames: names,
            includesDiapers: day.includesSupplementaryDiapers,
            isConfigured: true
        )
    }

    private static func materialName(for id: String) -> String? {
        switch id {
        case "organico": return "Organico"
        case "secco":    return "Secco"
        case "vetro":    return "Vetro"
        case "plastica": return "Plastica"
        case "carta":    return "Carta"
        case "metallo":  return "Metallo"
        default:         return nil
        }
    }
}
