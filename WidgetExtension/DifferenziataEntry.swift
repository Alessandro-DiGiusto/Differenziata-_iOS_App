//
//  DifferenziataEntry.swift
//  DifferenziataWidgetExtension
//

import WidgetKit

struct DifferenziataEntry: TimelineEntry {
    let date: Date
    let municipalityName: String
    let tomorrowMaterialIDs: [String]
    let tomorrowMaterialNames: [String]
    let includesDiapers: Bool
    let isConfigured: Bool
}

// MARK: - Default placeholder

extension DifferenziataEntry {
    static let placeholder = DifferenziataEntry(
        date: Date(),
        municipalityName: "—",
        tomorrowMaterialIDs: [],
        tomorrowMaterialNames: [],
        includesDiapers: false,
        isConfigured: false
    )
}
