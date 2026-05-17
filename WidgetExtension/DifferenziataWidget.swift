//
//  DifferenziataWidget.swift
//  DifferenziataWidgetExtension
//

import SwiftUI
import WidgetKit

@main
struct DifferenziataWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "it.alessandrodigiusto.Differenziata.widget",
            provider: DifferenziataProvider()
        ) { entry in
            DifferenziataWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Differenziata")
        .description("Mostra cosa devi esporre domani mattina.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
