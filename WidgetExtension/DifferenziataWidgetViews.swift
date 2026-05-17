//
//  DifferenziataWidgetViews.swift
//  DifferenziataWidgetExtension
//
//  View del widget: small → un materiale + icona, medium → griglia materiali.
//

import SwiftUI
import WidgetKit

// MARK: - Material helpers (duplicazione minima per il widget)

private struct WidgetMaterialInfo {
    let id: String
    let name: String
    let emoji: String
    let tint: Color
    let usesDarkText: Bool
}

private let widgetMaterials: [String: WidgetMaterialInfo] = {
    let list: [WidgetMaterialInfo] = [
        .init(id: "organico", name: "Organico", emoji: "🟤", tint: Color(red: 0.56, green: 0.36, blue: 0.21), usesDarkText: false),
        .init(id: "secco", name: "Secco", emoji: "⚫", tint: Color(red: 0.29, green: 0.31, blue: 0.34), usesDarkText: false),
        .init(id: "vetro", name: "Vetro", emoji: "🟢", tint: Color(red: 0.11, green: 0.62, blue: 0.34), usesDarkText: false),
        .init(id: "plastica", name: "Plastica", emoji: "🟡", tint: Color(red: 0.93, green: 0.74, blue: 0.12), usesDarkText: true),
        .init(id: "carta", name: "Carta", emoji: "🔵", tint: Color(red: 0.12, green: 0.43, blue: 0.86), usesDarkText: false),
        .init(id: "metallo", name: "Metallo", emoji: "🟢", tint: Color(red: 0.18, green: 0.62, blue: 0.54), usesDarkText: false),
    ]
    var dict: [String: WidgetMaterialInfo] = [:]
    for m in list { dict[m.id] = m }
    return dict
}()

private func info(for id: String) -> WidgetMaterialInfo {
    widgetMaterials[id] ?? .init(id: id, name: id, emoji: "🗑️", tint: .gray, usesDarkText: false)
}

// MARK: - Entry View principale

struct DifferenziataWidgetEntryView: View {
    var entry: DifferenziataEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    let entry: DifferenziataEntry

    var body: some View {
        ZStack {
            AppWidgetBackground()

            if entry.isConfigured {
                VStack(alignment: .center, spacing: 0) {
                    // Titolo "Domani"
                    Text("Domani mattina")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .textCase(.uppercase)

                    Spacer(minLength: 0)

                    if entry.tomorrowMaterialIDs.isEmpty && !entry.includesDiapers {
                        // Nessun ritiro
                        VStack(spacing: 6) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.70))

                            Text("Niente")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text("da esporre")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.80))
                        }
                    } else {
                        // Materiali
                        let primaryID = entry.tomorrowMaterialIDs.first ?? ""
                        let mat = info(for: primaryID)

                        Text(mat.emoji)
                            .font(.system(size: 36))

                        Text(mat.name)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        if entry.includesDiapers {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                Text("+ Pannolini")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.80))
                            .padding(.top, 2)
                        }

                        if entry.tomorrowMaterialIDs.count > 1 {
                            let rest = entry.tomorrowMaterialNames.dropFirst().joined(separator: ", ")
                            Text("+ \(rest)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                                .padding(.top, 1)
                        }
                    }

                    Spacer(minLength: 0)

                    // Comune
                    Text(entry.municipalityName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(14)
            } else {
                // Non configurato
                VStack(spacing: 10) {
                    Spacer(minLength: 0)

                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white.opacity(0.60))

                    Text("Apri l'app")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Configura il\ntuo comune")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                        .multilineTextAlignment(.center)

                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    let entry: DifferenziataEntry

    var body: some View {
        ZStack {
            AppWidgetBackground()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.80))

                    Text("Da esporre domani mattina")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.90))

                    Spacer(minLength: 0)

                    Text(entry.municipalityName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.bottom, 12)

                if entry.tomorrowMaterialIDs.isEmpty && !entry.includesDiapers {
                    HStack(spacing: 10) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.60))

                        Text("Niente da esporre — domani non è previsto alcun ritiro.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.vertical, 8)
                } else {
                    // Griglia materiali
                    let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(entry.tomorrowMaterialIDs, id: \.self) { id in
                            let mat = info(for: id)
                            WidgetMaterialChip(info: mat)
                        }

                        if entry.includesDiapers {
                            WidgetDiapersChip()
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Chip componenti

private struct WidgetMaterialChip: View {
    let info: WidgetMaterialInfo

    var body: some View {
        HStack(spacing: 6) {
            Text(info.emoji)
                .font(.system(size: 14))

            Text(info.name)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(info.usesDarkText ? Color(red: 0.10, green: 0.16, blue: 0.18) : .white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(info.tint)
        )
    }
}

private struct WidgetDiapersChip: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 0.15, green: 0.44, blue: 0.83))

            Text("Pannolini")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.18))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.90, green: 0.95, blue: 1.0))
        )
    }
}

// MARK: - Sfondo

private struct AppWidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.13, green: 0.42, blue: 0.32),
                Color(red: 0.18, green: 0.57, blue: 0.49),
                Color(red: 0.78, green: 0.88, blue: 0.73),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 80, height: 80)
                .blur(radius: 8)
                .offset(x: 20, y: -20)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 100, height: 100)
                .blur(radius: 10)
                .offset(x: -30, y: 30)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    DifferenziataWidget()
} timeline: {
    DifferenziataEntry(
        date: Date(),
        municipalityName: "Acireale",
        tomorrowMaterialIDs: ["plastica", "carta"],
        tomorrowMaterialNames: ["Plastica", "Carta"],
        includesDiapers: true,
        isConfigured: true
    )
}

#Preview(as: .systemMedium) {
    DifferenziataWidget()
} timeline: {
    DifferenziataEntry(
        date: Date(),
        municipalityName: "Acireale",
        tomorrowMaterialIDs: ["organico", "vetro"],
        tomorrowMaterialNames: ["Organico", "Vetro"],
        includesDiapers: false,
        isConfigured: true
    )
}
