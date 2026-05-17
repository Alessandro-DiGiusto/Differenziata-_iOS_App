//
//  ContentView.swift
//  Acireale Differenziata
//
//  Created by Alessandro Di Giusto on 24/04/2026.
//

import Combine
import SwiftUI

struct ContentView: View {
    private let locale = Locale(identifier: "it_IT")
    @EnvironmentObject private var notificationManager: WasteNotificationManager
    @EnvironmentObject private var wasteProfileStore: WasteProfileStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedMaterial: WasteMaterial?
    @State private var isReminderPickerVisible = false
    @State private var isTrashReminderBannerVisible = false
    @State private var bannerShown = false
    @State private var bannerConfettiBurstID: UUID?
    @State private var objectSearchQuery = ""
    @State private var snapshot = HomeSnapshot(now: Date())

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    HeaderView(
                        locale: locale,
                        municipalityName: wasteProfileStore.currentProfile.municipalityName,
                        isReminderPickerVisible: isReminderPickerVisible,
                        onClockTap: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                isReminderPickerVisible.toggle()
                            }
                        }
                    )

                    ObjectSearchCard(
                        query: $objectSearchQuery,
                        now: snapshot.now
                    ) { material in
                        selectedMaterial = material
                    }

                    ActionCard(snapshot: snapshot) { material in
                        selectedMaterial = material
                    }

                    if snapshot.supplementaryDiapersTomorrow {
                        SupplementaryDiapersCard()
                    }

                    WeeklyScheduleCard()
                }
                .padding(20)
                .padding(.bottom, 32)
            }

            if isReminderPickerVisible {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .padding(.top, 112)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            isReminderPickerVisible = false
                        }
                    }
            }

            if isReminderPickerVisible {
                ReminderSettingsCard(
                    reminderTime: notificationManager.reminderTime,
                    onChange: { notificationManager.updateReminderTime($0) }
                )
                .padding(.top, 102)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(2)
            }

            if isTrashReminderBannerVisible {
                TrashReminderBanner(
                    onDismiss: hideTrashReminderBanner,
                    onConfirm: confirmTrashReminder
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .environment(\.locale, locale)
        .onAppear {
            snapshot = HomeSnapshot(now: Date())
            notificationManager.activate()
            scheduleTrashReminderBannerIfNeeded()
        }
        .onChange(of: wasteProfileStore.currentProfile) { _, _ in
            snapshot = HomeSnapshot(now: Date())
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                notificationManager.activate()
                let today = Calendar.autoupdatingCurrent.component(.day, from: Date())
                let snapshotDay = Calendar.autoupdatingCurrent.component(.day, from: snapshot.now)
                if today != snapshotDay {
                    snapshot = HomeSnapshot(now: Date())
                }
            }
        }
        .overlay {
            ZStack {
                ConfettiOverlay(trigger: notificationManager.confettiBurstID)
                ConfettiOverlay(trigger: bannerConfettiBurstID)
            }
        }
        .sheet(item: $selectedMaterial) { material in
            MaterialDetailSheet(material: material)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func scheduleTrashReminderBannerIfNeeded() {
        guard !bannerShown else {
            return
        }

        bannerShown = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                isTrashReminderBannerVisible = true
            }
        }
    }

    private func hideTrashReminderBanner() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            isTrashReminderBannerVisible = false
        }
    }

    private func confirmTrashReminder() {
        hideTrashReminderBanner()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            bannerConfettiBurstID = UUID()
        }
    }
}

// MARK: - Header

private struct TrashReminderBanner: View {
    let onDismiss: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("🗑️")
                    .font(.system(size: 32))

                Text("Hai già buttato la spazzatura?")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button(action: onDismiss) {
                    Text("Non ancora")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.20, green: 0.26, blue: 0.29))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 0.93, green: 0.94, blue: 0.95))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text("Sì ✅")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 0.13, green: 0.42, blue: 0.32))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.13), radius: 24, x: 0, y: 16)
    }
}

// MARK: - Object Search

private struct ObjectSearchCard: View {
    @Binding var query: String
    let now: Date
    let onMaterialTap: (WasteMaterial) -> Void

    private let suggestions = [
        "Penna bic",
        "Cicche di sigaretta",
        "Carta igienica",
        "Cartone pizza"
    ]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [WasteSearchResult] {
        WasteSearchIndex.search(query: trimmedQuery, now: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Dove lo butto?")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))

                Text("Cerca un oggetto e ti dico contenitore e prossimo giorno utile di ritiro.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.30, green: 0.37, blue: 0.40))
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.36, green: 0.42, blue: 0.45))

                TextField("Es. penna bic, lattina, cartone pizza", text: $query)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.18))
                    .submitLabel(.search)

                if !trimmedQuery.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(red: 0.60, green: 0.64, blue: 0.67))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.95, green: 0.96, blue: 0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )

            if trimmedQuery.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                query = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.18, green: 0.23, blue: 0.26))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(Color(red: 0.93, green: 0.96, blue: 0.92))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else if results.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Non l'ho trovato nel calendario attuale.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.17, blue: 0.18))

                    Text("Prova con un nome piu` specifico, ad esempio “rotolo carta igienica” oppure “bottiglia di vetro”.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.37, green: 0.43, blue: 0.46))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.97, green: 0.97, blue: 0.95))
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(results) { result in
                        ObjectSearchResultRow(result: result) {
                            onMaterialTap(result.material)
                        }
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct ObjectSearchResultRow: View {
    let result: WasteSearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))
                            .multilineTextAlignment(.leading)

                        if let note = result.note {
                            Text(note)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(red: 0.38, green: 0.44, blue: 0.47))
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer(minLength: 0)

                    Text(result.material.name)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(result.material.badgeTitleColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(result.material.tint)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    SearchInfoRow(label: "Contenitore", value: result.material.container)
                    SearchInfoRow(label: "Sacchetto", value: result.material.bagLine.replacingOccurrences(of: "Sacchetto: ", with: ""))
                    SearchInfoRow(label: "Prossimo ritiro", value: result.nextPickupText)
                    SearchInfoRow(label: "Ritiri", value: result.pickupDaysText)
                }

                HStack(spacing: 6) {
                    Text("Apri dettagli")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.28, green: 0.35, blue: 0.39))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.28, green: 0.35, blue: 0.39))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(result.material.tint.opacity(result.material.usesDarkText ? 0.26 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.38), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SearchInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.34, green: 0.40, blue: 0.43))
                .frame(width: 108, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.17, blue: 0.18))
                .multilineTextAlignment(.leading)
        }
    }
}

// FIX 1: Titolo compatto su 2 righe ("Raccolta / Acireale"), clock pill snella, niente sottotitolo fisso
// ENERGY FIX: TimelineView aggiornato ogni 60 secondi invece di ogni 1 secondo (−98% refresh)
private struct HeaderView: View {
    let locale: Locale
    let municipalityName: String
    let isReminderPickerVisible: Bool
    let onClockTap: () -> Void

    @State private var now = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Raccolta")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(municipalityName)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)

            Button(action: onClockTap) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(now.formatted(.dateTime.locale(locale).hour().minute()))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text(now.formatted(.dateTime.locale(locale).day().month(.abbreviated).weekday(.abbreviated)))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.80))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(isReminderPickerVisible ? 0.22 : 0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(isReminderPickerVisible ? 0.28 : 0.16), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .onReceive(timer) { date in
            now = date
        }
    }
}

// MARK: - ActionCard

// FIX 2: Rimosso ActionRow duplicato ("Domani mattina ritirano" + "Quindi metti fuori adesso").
//         La card parla già da sola con i badge.
private struct ActionCard: View {
    let snapshot: HomeSnapshot
    let onMaterialTap: (WasteMaterial) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Da esporre adesso")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.18, green: 0.23, blue: 0.26))

            Text(snapshot.actionTitle)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))

            if !snapshot.actionSubtitle.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(snapshot.actionSubtitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.29, green: 0.36, blue: 0.39))
            }

            if snapshot.tomorrowMaterials.isEmpty {
                if let upcomingPickup = snapshot.nextPickup {
                    NextPickupCard(pickup: upcomingPickup)
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(snapshot.tomorrowMaterials) { material in
                        MaterialBadge(material: material) {
                            onMaterialTap(material)
                        }
                    }
                }
                // FIX 2: Rimosso il blocco con le due ActionRow identiche
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

// MARK: - MaterialBadge

// FIX 3: badge con altezza fissa per mantenere tutte le card identiche nella griglia.
// FIX 4: MaterialDetailCard eliminato — questo badge è l'unico componente tap→sheet.
private struct MaterialBadge: View {
    let material: WasteMaterial
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Text(material.name)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(material.badgeTitleColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(material.container)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(material.badgeSubtitleColor)

                    Text(material.bagLine)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(material.badgeSubtitleColor)
                }

                Spacer(minLength: 0)

                HStack {
                    Text("Dettagli")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(material.badgeSubtitleColor)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(material.badgeSubtitleColor)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(material.tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(material.usesDarkText ? 0.14 : 0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MaterialDetailSheet

private struct MaterialDetailSheet: View {
    let material: WasteMaterial
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(material.name)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(material.badgeTitleColor)

                        Text("\(material.container) • Sacchetto: \(material.bag)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(material.badgeSubtitleColor)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(material.tint)
                    )

                    if !material.accepted.isEmpty {
                        MaterialListCard(
                            title: "Cosa inserire",
                            items: material.accepted,
                            tint: Color(red: 0.14, green: 0.53, blue: 0.34),
                            disclaimer: material.id == "organico" ? "Lista indicativa — verifica sempre le istruzioni del tuo Comune." : nil
                        )
                    }

                    if !material.rejected.isEmpty {
                        MaterialListCard(
                            title: "Cosa non inserire",
                            items: material.rejected,
                            tint: Color(red: 0.78, green: 0.25, blue: 0.25),
                            disclaimer: nil
                        )
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Color(red: 0.96, green: 0.97, blue: 0.95))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
        }
    }
}

// MARK: - MaterialList & MaterialListCard

private struct MaterialList: View {
    let title: String
    let items: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(tint)
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)

                        Text(item)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 0.20, green: 0.25, blue: 0.27))
                    }
                }
            }
        }
    }
}

private struct MaterialListCard: View {
    let title: String
    let items: [String]
    let tint: Color
    let disclaimer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MaterialList(title: title, items: items, tint: tint)

            // FIX 7: disclaimer per la lista organico (indicativa, non dal .md)
            if let disclaimer {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.50))

                    Text(disclaimer)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.50))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - NextPickupCard

private struct NextPickupCard: View {
    let pickup: UpcomingPickup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prossimo ritiro utile")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.40, green: 0.46, blue: 0.48))

            Text("\(pickup.dayLabel) mattina")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.11, green: 0.15, blue: 0.18))

            Text(pickup.description)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.28, green: 0.35, blue: 0.39))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.94, green: 0.98, blue: 0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - ReminderSettingsCard

private struct ReminderSettingsCard: View {
    let reminderTime: Date
    let onChange: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Promemoria")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.50))
                .textCase(.uppercase)

            Text("Scegli l'orario in cui vuoi ricevere il reminder quotidiano.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.30, green: 0.37, blue: 0.40))

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Orario attuale")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.50))

                    Text(reminderTime.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))
                }

                Spacer(minLength: 0)

                DatePicker(
                    "",
                    selection: Binding(
                        get: { reminderTime },
                        set: { onChange($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }
        }
        .padding(18)
        .frame(width: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: 14)
    }
}

// MARK: - SupplementaryDiapersCard

// FIX 5: Sostituito gradient blu rumoroso con una pill compatta icon + testo inline
private struct SupplementaryDiapersCard: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 0.15, green: 0.44, blue: 0.83))

            VStack(alignment: .leading, spacing: 1) {
                Text("Ritiro pannolini attivo domani")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.18))

                Text("Contenitore bianco • Sacchetto trasparente")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.30, green: 0.37, blue: 0.40))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.90, green: 0.95, blue: 1.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.15, green: 0.44, blue: 0.83).opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - WeeklyScheduleCard

// FIX 6: Righe leggere — nessun background di default, solo la riga corrente evidenziata.
//         Padding ridotto, niente shadow.
private struct WeeklyScheduleCard: View {
    @EnvironmentObject private var wasteProfileStore: WasteProfileStore

    private var todayWeekday: Int {
        Calendar.autoupdatingCurrent.component(.weekday, from: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                SectionTitle("Calendario settimanale")

                Spacer(minLength: 0)

                Button {
                    wasteProfileStore.startEditing()
                } label: {
                    Text("Configura")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.18, blue: 0.20))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.86))
                        )
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(WasteSchedule.weeklyRows) { row in
                    let isToday = row.id == todayWeekday

                    HStack(alignment: .center, spacing: 14) {
                        Text(row.day)
                            .font(.system(size: 15, weight: isToday ? .black : .semibold, design: .rounded))
                            .foregroundStyle(isToday ? Color(red: 0.10, green: 0.16, blue: 0.17) : Color(red: 0.25, green: 0.32, blue: 0.35))
                            .frame(width: 88, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.materialsText)
                                .font(.system(size: 14, weight: isToday ? .bold : .medium, design: .rounded))
                                .foregroundStyle(isToday ? Color(red: 0.12, green: 0.16, blue: 0.18) : Color(red: 0.30, green: 0.38, blue: 0.41))

                            if row.hasSupplementaryDiapers {
                                Text("+ Pannolini")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.16, green: 0.44, blue: 0.82))
                            }
                        }

                        Spacer(minLength: 0)

                        if isToday {
                            Text("Oggi")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(.white.opacity(0.85))
                                )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isToday
                            ? Color.white.opacity(0.80)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
            }
        }
    }
}

// MARK: - SectionTitle

private struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.86))
            .textCase(.uppercase)
    }
}

// MARK: - AppBackground

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.13, green: 0.42, blue: 0.32),
                Color(red: 0.18, green: 0.57, blue: 0.49),
                Color(red: 0.78, green: 0.88, blue: 0.73)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 10)
                .offset(x: 70, y: -40)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 18)
                .offset(x: -90, y: 80)
        }
    }
}

// MARK: - HomeSnapshot

@MainActor
private struct HomeSnapshot {
    let now: Date
    let tomorrow: Date
    let tomorrowMaterials: [WasteMaterial]
    let supplementaryDiapersTomorrow: Bool
    let nextPickup: UpcomingPickup?

    init(now: Date, calendar: Calendar = .autoupdatingCurrent) {
        self.now = now
        self.tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now

        let tomorrowWeekday = calendar.component(.weekday, from: tomorrow)
        self.tomorrowMaterials = WasteSchedule.materials(for: tomorrowWeekday)
        self.supplementaryDiapersTomorrow = WasteSchedule.supplementaryDiapersWeekdays.contains(tomorrowWeekday)
        self.nextPickup = WasteSchedule.nextPickup(after: now, calendar: calendar)
    }

    var actionTitle: String {
        if tomorrowMaterials.isEmpty && !supplementaryDiapersTomorrow {
            return "Niente da esporre stasera"
        }

        if tomorrowMaterials.isEmpty && supplementaryDiapersTomorrow {
            return "Metti fuori pannolini"
        }

        if tomorrowMaterials.count == 1 && supplementaryDiapersTomorrow {
            return "Metti fuori \(tomorrowMaterials[0].name.lowercased()) e pannolini"
        }

        if tomorrowMaterials.count == 1 {
            return "Metti fuori \(tomorrowMaterials[0].name.lowercased())"
        }

        return "Metti fuori tutto quello che vedi qui"
    }

    var actionSubtitle: String {
        if tomorrowMaterials.isEmpty && !supplementaryDiapersTomorrow {
            return "Domani mattina non è previsto alcun ritiro nel calendario."
        }

        if tomorrowMaterials.isEmpty && supplementaryDiapersTomorrow {
            return "Domani mattina è attivo il servizio pannolini."
        }

        return supplementaryDiapersTomorrow ? "Domani mattina è attivo anche il servizio pannolini." : ""
    }
}

// MARK: - UpcomingPickup

struct UpcomingPickup {
    let date: Date
    let materials: [WasteMaterial]
    let includesSupplementaryDiapers: Bool

    private let locale = Locale(identifier: "it_IT")

    var dayLabel: String {
        date.formatted(.dateTime.locale(locale).weekday(.wide).day().month(.wide))
    }

    var description: String {
        var parts = materials.map(\.name)

        if includesSupplementaryDiapers {
            parts.append("pannolini")
        }

        guard !parts.isEmpty else {
            return "Nessun ritiro configurato."
        }

        return "Il prossimo ritiro sarà per \(naturalJoin(parts))."
    }

    private func naturalJoin(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) e \(items[1])"
        default:
            let head = items.dropLast().joined(separator: ", ")
            return "\(head) e \(items.last ?? "")"
        }
    }
}

// MARK: - WeeklyRow

struct WeeklyRow: Identifiable {
    let id: Int
    let day: String
    let materialsText: String
    let hasSupplementaryDiapers: Bool
}

// MARK: - WasteMaterial

struct WasteMaterial: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let tint: Color
    let usesDarkText: Bool
    let container: String
    let bag: String
    let accepted: [String]
    let rejected: [String]

    var badgeTitleColor: Color {
        usesDarkText ? Color(red: 0.10, green: 0.15, blue: 0.17) : .white
    }

    var badgeSubtitleColor: Color {
        usesDarkText ? Color(red: 0.17, green: 0.22, blue: 0.24).opacity(0.76) : .white.opacity(0.82)
    }

    var bagLine: String {
        bag == "Nessuno" ? "Sacchetto: nessuno" : "Sacchetto: \(bag)"
    }
}

// MARK: - WasteCatalog

// FIX 7: Lista "accepted" dell'organico marcata come indicativa (non specificata nel .md).
//         Il disclaimer viene mostrato nella sheet via MaterialListCard.
enum WasteCatalog {
    static let organico = WasteMaterial(
        id: "organico",
        name: "Organico",
        emoji: "🟤",
        tint: Color(red: 0.56, green: 0.36, blue: 0.21),
        usesDarkText: false,
        container: "Contenitore marrone",
        bag: "Biodegradabile",
        accepted: [
            "Scarti di frutta e verdura",
            "Carta assorbente da cucina unta",
            "Cartoni per la pizza unti",
            "Avanzi dei pasti",
            "Pane vecchio",
            "Resti di carne e ossa",
            "Fondi di caffè e filtri di tè"
        ],
        rejected: [
            "Tutti gli altri materiali oggetto di raccolta differenziata",
            "Materiali non biodegradabili e non compostabili",
            "Pannolini e pannoloni"
        ]
    )

    static let secco = WasteMaterial(
        id: "secco",
        name: "Secco residuale",
        emoji: "⚫",
        tint: Color(red: 0.29, green: 0.31, blue: 0.34),
        usesDarkText: false,
        container: "Contenitore grigio",
        bag: "Trasparente",
        accepted: [
            "Materiali misti o non riciclabili",
            "Posate in plastica, giocattoli, gomma",
            "Pannolini e pannoloni",
            "CD/DVD, videocassette",
            "Stracci",
            "Ceramica e porcellana (cocci)",
            "Rasoi usa e getta, spazzolini, penne",
            "Guanti in gomma o lattice",
            "Sacchetti per freezer",
            "Cannucce, sottovasi"
        ],
        rejected: [
            "Rifiuti differenziabili",
            "Liquidi",
            "Rifiuti pericolosi o infiammabili",
            "Inerti e rifiuti ingombranti"
        ]
    )

    static let vetro = WasteMaterial(
        id: "vetro",
        name: "Vetro",
        emoji: "🟢",
        tint: Color(red: 0.11, green: 0.62, blue: 0.34),
        usesDarkText: false,
        container: "Contenitore verde",
        bag: "Nessuno",
        accepted: [
            "Bottiglie e vasetti in vetro"
        ],
        rejected: [
            "Vetri da finestra",
            "Bicchieri, cristallo",
            "Ceramica, porcellana",
            "Lampadine, neon",
            "Specchi e lastre"
        ]
    )

    static let plastica = WasteMaterial(
        id: "plastica",
        name: "Plastica",
        emoji: "🟡",
        tint: Color(red: 0.93, green: 0.74, blue: 0.12),
        usesDarkText: true,
        container: "Contenitore giallo",
        bag: "Trasparente",
        accepted: [
            "Bottiglie e flaconi in plastica",
            "Reti per frutta",
            "Vasetti yogurt",
            "Piatti e bicchieri monouso (puliti)",
            "Confezioni rigide",
            "Sacchetti plastica",
            "Vaschette polistirolo",
            "Tutti gli imballaggi in plastica"
        ],
        rejected: [
            "Posate in plastica",
            "Giocattoli",
            "Tubi edilizia",
            "Guanti, spazzolini, rasoi",
            "Penne, cannucce",
            "Sacchetti freezer",
            "Sottovasi",
            "Sacchi biodegradabili"
        ]
    )

    static let carta = WasteMaterial(
        id: "carta",
        name: "Carta e cartone",
        emoji: "🔵",
        tint: Color(red: 0.12, green: 0.43, blue: 0.86),
        usesDarkText: false,
        container: "Contenitore blu",
        bag: "Nessuno",
        accepted: [
            "Cartone",
            "Giornali, riviste",
            "Depliant",
            "Fogli carta",
            "Tetra Pak",
            "Cartoni pizza puliti"
        ],
        rejected: [
            "Carta oleata",
            "Carta carbone",
            "Carta plastificata",
            "Scontrini",
            "Gratta e vinci"
        ]
    )

    static let metallo = WasteMaterial(
        id: "metallo",
        name: "Metallo",
        emoji: "🟢",
        tint: Color(red: 0.18, green: 0.62, blue: 0.54),
        usesDarkText: false,
        container: "Contenitore verde",
        bag: "Nessuno",
        accepted: [
            "Lattine",
            "Scatole metalliche",
            "Tappi a corona",
            "Alluminio"
        ],
        rejected: [
            "Non metallo",
            "Rifiuti pericolosi",
            "Pentole e padelle"
        ]
    )

    static let allMaterials: [WasteMaterial] = [
        organico,
        secco,
        vetro,
        plastica,
        carta,
        metallo
    ]

    static func material(for id: String) -> WasteMaterial? {
        allMaterials.first { $0.id == id }
    }
}

// MARK: - Waste Search

private struct WasteSearchResult: Identifiable {
    let id: String
    let title: String
    let material: WasteMaterial
    let note: String?
    let pickupDaysText: String
    let nextPickupText: String
}

private struct WasteSearchEntry {
    let id: String
    let title: String
    let aliases: [String]
    let material: WasteMaterial
    let note: String?

    @MainActor
    func score(for normalizedQuery: String) -> Int {
        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)
        var bestScore = 0

        for alias in aliases.map(WasteSearchIndex.normalize) {
            if alias == normalizedQuery {
                bestScore = max(bestScore, 500)
                continue
            }

            if alias.hasPrefix(normalizedQuery) {
                bestScore = max(bestScore, 420 - max(0, alias.count - normalizedQuery.count))
                continue
            }

            if alias.contains(normalizedQuery) {
                bestScore = max(bestScore, 360 - max(0, alias.count - normalizedQuery.count))
                continue
            }

            if normalizedQuery.contains(alias), alias.count >= 4 {
                bestScore = max(bestScore, 260)
                continue
            }

            if !queryTokens.isEmpty && queryTokens.allSatisfy(alias.contains) {
                bestScore = max(bestScore, 240)
            }
        }

        return bestScore
    }
}

private struct WasteSearchJSONEntry: Decodable {
    let id: String
    let title: String
    let aliases: [String]
    let material_id: String
    let note: String?
}

@MainActor
private enum WasteSearchIndex {
    static let curatedEntries: [WasteSearchEntry] = [
        WasteSearchEntry(
            id: "search-penna-bic",
            title: "Penna Bic",
            aliases: ["penna bic", "penna", "biro", "penne"],
            material: WasteCatalog.secco,
            note: "Oggetto non riciclabile nel calendario ordinario."
        ),
        WasteSearchEntry(
            id: "search-cicche",
            title: "Cicche di sigaretta",
            aliases: ["cicche di sigaretta", "cicca di sigaretta", "mozzicone", "mozziconi", "filtro sigaretta"],
            material: WasteCatalog.secco,
            note: "Residuo piccolo e non riciclabile."
        ),
        WasteSearchEntry(
            id: "search-carta-igienica-usata",
            title: "Carta igienica usata",
            aliases: ["carta igienica", "carta igenica", "carta igienica usata", "carta igenica usata"],
            material: WasteCatalog.organico,
            note: "Se e` usata o sporca. Il rotolo interno va nella carta."
        ),
        WasteSearchEntry(
            id: "search-rotolo-carta-igienica",
            title: "Rotolo interno carta igienica",
            aliases: ["rotolo carta igienica", "rotolo carta igenica", "tubo carta igienica", "anima carta igienica"],
            material: WasteCatalog.carta,
            note: "Solo il cilindro di cartone."
        ),
        WasteSearchEntry(
            id: "search-lattina",
            title: "Lattina",
            aliases: ["lattina", "lattine", "barattolo metallo", "alluminio"],
            material: WasteCatalog.metallo,
            note: nil
        ),
        WasteSearchEntry(
            id: "search-bottiglia-vetro",
            title: "Bottiglia di vetro",
            aliases: ["bottiglia vetro", "bottiglia di vetro", "vasetto vetro", "barattolo vetro"],
            material: WasteCatalog.vetro,
            note: nil
        ),
        WasteSearchEntry(
            id: "search-bottiglia-plastica",
            title: "Bottiglia di plastica",
            aliases: ["bottiglia plastica", "bottiglia di plastica", "flacone plastica", "vasetto yogurt"],
            material: WasteCatalog.plastica,
            note: nil
        ),
        WasteSearchEntry(
            id: "search-cartone-pizza-pulito",
            title: "Cartone pizza pulito",
            aliases: ["cartone pizza pulito", "scatola pizza pulita", "cartone pizza"],
            material: WasteCatalog.carta,
            note: "Se non e` unto."
        ),
        WasteSearchEntry(
            id: "search-cartone-pizza-unto",
            title: "Cartone pizza unto",
            aliases: ["cartone pizza unto", "scatola pizza unta", "pizza unto"],
            material: WasteCatalog.organico,
            note: "Se e` sporco di cibo o unto."
        )
    ]

    static let catalogEntries: [WasteSearchEntry] = {
        WasteCatalog.allMaterials.flatMap { material in
            material.accepted.map { item in
                let normalizedItem = normalize(item)

                return WasteSearchEntry(
                    id: "catalog-\(material.id)-\(normalizedItem)",
                    title: item,
                    aliases: [item],
                    material: material,
                    note: nil
                )
            }
        }
    }()

    static var jsonEntries: [WasteSearchEntry] = {
        guard let url = Bundle.main.url(forResource: "waste_search_index", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let jsonEntries = try? JSONDecoder().decode([WasteSearchJSONEntry].self, from: data)
        else {
            print("[WasteSearchIndex] Impossibile caricare waste_search_index.json")
            return []
        }

        print("[WasteSearchIndex] Caricati \(jsonEntries.count) oggetti dal database JSON")

        return jsonEntries.compactMap { entry in
            guard let material = WasteCatalog.material(for: entry.material_id) else {
                print("[WasteSearchIndex] Materiale sconosciuto: \(entry.material_id) per \(entry.title)")
                return nil
            }

            return WasteSearchEntry(
                id: "json-\(entry.id)",
                title: entry.title,
                aliases: entry.aliases,
                material: material,
                note: entry.note
            )
        }
    }()

    static func search(query: String, now: Date, calendar: Calendar = .autoupdatingCurrent) -> [WasteSearchResult] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        let rankedEntries = (curatedEntries + catalogEntries + jsonEntries)
            .compactMap { entry -> (WasteSearchEntry, Int)? in
                let score = entry.score(for: normalizedQuery)
                guard score > 0 else {
                    return nil
                }

                return (entry, score)
            }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.title.count < $1.0.title.count
                }

                return $0.1 > $1.1
            }

        var seenIDs = Set<String>()
        var results: [WasteSearchResult] = []

        for (entry, _) in rankedEntries {
            guard seenIDs.insert(entry.id).inserted else {
                continue
            }

            let pickupDays = WasteSchedule.pickupDayNames(for: entry.material)
            let pickupDaysText = pickupDays.isEmpty ? "Non configurato" : pickupDays.joined(separator: " • ")
            let nextPickupText = WasteSchedule.nextPickupDescription(for: entry.material, after: now, calendar: calendar)

            results.append(
                WasteSearchResult(
                    id: entry.id,
                    title: entry.title,
                    material: entry.material,
                    note: entry.note,
                    pickupDaysText: pickupDaysText,
                    nextPickupText: nextPickupText
                )
            )

            if results.count == 4 {
                break
            }
        }

        return results
    }

    static func normalize(_ text: String) -> String {
        let lowered = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
        let components = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return components
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - WasteSchedule

@MainActor
enum WasteSchedule {
    private static var cachedProfile: MunicipalityProfile?
    private static var _supplementaryDiapersWeekdays: Set<Int> = []
    private static var _weeklyRows: [WeeklyRow] = []

    static var supplementaryDiapersWeekdays: Set<Int> {
        ensureCache()
        return _supplementaryDiapersWeekdays
    }

    static var weeklyRows: [WeeklyRow] {
        ensureCache()
        return _weeklyRows
    }

    private static func ensureCache() {
        let profile = WasteProfileStore.shared.currentProfile
        guard cachedProfile != profile else { return }
        cachedProfile = profile
        _supplementaryDiapersWeekdays = Set(
            profile.collectionDays
                .filter(\.includesSupplementaryDiapers)
                .map(\.weekday)
        )
        _weeklyRows = weeklyRows(for: profile)
    }

    static func materials(for weekday: Int, profile: MunicipalityProfile? = nil) -> [WasteMaterial] {
        let profile = profile ?? WasteProfileStore.shared.currentProfile
        return profile.day(for: weekday).materialIDs.compactMap(WasteCatalog.material(for:))
    }

    static func includesSupplementaryDiapers(on weekday: Int, profile: MunicipalityProfile? = nil) -> Bool {
        let profile = profile ?? WasteProfileStore.shared.currentProfile
        return profile.day(for: weekday).includesSupplementaryDiapers
    }

    static func weeklyRows(for profile: MunicipalityProfile) -> [WeeklyRow] {
        MunicipalityProfile.orderedWeekdays.map { weekday in
            let materialsText = materials(for: weekday, profile: profile)
                .map(\.name)
                .joined(separator: ", ")

            return WeeklyRow(
                id: weekday,
                day: MunicipalityProfile.dayName(for: weekday),
                materialsText: materialsText.isEmpty ? "Nessun ritiro" : materialsText,
                hasSupplementaryDiapers: includesSupplementaryDiapers(on: weekday, profile: profile)
            )
        }
    }

    static func weekdays(for material: WasteMaterial, profile: MunicipalityProfile? = nil) -> [Int] {
        let profile = profile ?? WasteProfileStore.shared.currentProfile
        return MunicipalityProfile.orderedWeekdays.filter { weekday in
            materials(for: weekday, profile: profile).contains { $0.id == material.id }
        }
    }

    static func pickupDayNames(for material: WasteMaterial) -> [String] {
        weekdays(for: material).compactMap { dayName(for: $0) }
    }

    static func dayName(for weekday: Int) -> String? {
        MunicipalityProfile.dayName(for: weekday)
    }

    static func nextPickupDate(for material: WasteMaterial, after now: Date, calendar: Calendar) -> Date? {
        for offset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: date)
            let materialsForDay = materials(for: weekday)

            if materialsForDay.contains(where: { $0.id == material.id }) {
                return date
            }
        }

        return nil
    }

    static func nextPickupDescription(for material: WasteMaterial, after now: Date, calendar: Calendar) -> String {
        guard let nextPickupDate = nextPickupDate(for: material, after: now, calendar: calendar) else {
            return "Non configurato in questo Comune"
        }

        let locale = Locale(identifier: "it_IT")
        return nextPickupDate.formatted(.dateTime.locale(locale).weekday(.wide).day().month(.abbreviated)) + " mattina"
    }

    static func nextPickup(after now: Date, calendar: Calendar) -> UpcomingPickup? {
        for offset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: date)
            let materials = materials(for: weekday)
            let diapers = supplementaryDiapersWeekdays.contains(weekday)

            if !materials.isEmpty || diapers {
                return UpcomingPickup(date: date, materials: materials, includesSupplementaryDiapers: diapers)
            }
        }

        return nil
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(WasteNotificationManager.shared)
        .environmentObject(WasteProfileStore.shared)
}
