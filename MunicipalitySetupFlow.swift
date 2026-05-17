//
//  MunicipalitySetupFlow.swift
//  Acireale Differenziata
//

import CoreLocation
import SwiftUI
import UIKit

struct AppRootView: View {
    @EnvironmentObject private var wasteProfileStore: WasteProfileStore
    @EnvironmentObject private var notificationManager: WasteNotificationManager

    private var isEditingProfile: Binding<Bool> {
        Binding(
            get: { wasteProfileStore.isEditingProfile },
            set: { isPresented in
                if !isPresented {
                    wasteProfileStore.dismissEditor()
                }
            }
        )
    }

    var body: some View {
        Group {
            if wasteProfileStore.hasCompletedOnboarding {
                ContentView()
                    .fullScreenCover(isPresented: isEditingProfile) {
                        MunicipalitySetupView(
                            initialProfile: wasteProfileStore.currentProfile,
                            initialReminderTime: notificationManager.reminderTime,
                            isInitialSetup: false
                        )
                    }
            } else {
                MunicipalitySetupView(
                    initialProfile: wasteProfileStore.currentProfile,
                    initialReminderTime: notificationManager.reminderTime,
                    isInitialSetup: true
                )
            }
        }
    }
}

struct MunicipalitySetupView: View {
    private enum SetupStep: Int, CaseIterable, Identifiable {
        case municipality
        case weeklySchedule
        case review

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .municipality:
                return "Configura il tuo Comune"
            case .weeklySchedule:
                return "Imposta i ritiri settimanali"
            case .review:
                return "Controlla e salva"
            }
        }

        var subtitle: String {
            switch self {
            case .municipality:
                return "Il nome comparirà nella home e nei promemoria serali."
            case .weeklySchedule:
                return "Per ogni giorno scegli i materiali ritirati e, se serve, attiva il servizio pannolini."
            case .review:
                return "Quando salvi, calendario, ricerca e notifiche useranno subito questa configurazione."
            }
        }

        var primaryButtonTitle: String {
            switch self {
            case .review:
                return "Salva profilo"
            default:
                return "Continua"
            }
        }
    }

    let isInitialSetup: Bool

    @EnvironmentObject private var wasteProfileStore: WasteProfileStore
    @EnvironmentObject private var notificationManager: WasteNotificationManager
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: SetupStep = .municipality
    @State private var draftProfile: MunicipalityProfile
    @State private var draftReminderTime: Date

    @State private var comuneSuggestions: [(nome: String, provincia: String)] = []
    @State private var configuredComuni: [String] = []
    @State private var isLoadingSuggestions = false
    @State private var isLoadingConfigured = false
    @State private var isLocating = false
    @State private var selectedFromList = false
    @State private var showConfiguredList = true

    init(initialProfile: MunicipalityProfile, initialReminderTime: Date, isInitialSetup: Bool) {
        self.isInitialSetup = isInitialSetup
        _draftProfile = State(initialValue: initialProfile)
        _draftReminderTime = State(initialValue: initialReminderTime)
    }

    private var trimmedMunicipalityName: String {
        draftProfile.municipalityName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        switch currentStep {
        case .municipality:
            return !trimmedMunicipalityName.isEmpty
        case .weeklySchedule, .review:
            return !trimmedMunicipalityName.isEmpty && draftProfile.hasAnyConfiguredPickup
        }
    }

    var body: some View {
        ZStack {
            SetupBackground()

            VStack(spacing: 18) {
                topBar
                stepHeader

                ScrollView(showsIndicators: false) {
                    Group {
                        switch currentStep {
                        case .municipality:
                            MunicipalityNameStep(
                                profile: $draftProfile,
                                comuneSuggestions: comuneSuggestions,
                                configuredComuni: configuredComuni,
                                isLoadingSuggestions: isLoadingSuggestions,
                                isLoadingConfigured: isLoadingConfigured,
                                isLocating: isLocating,
                                showConfiguredList: showConfiguredList,
                                onSearch: { query in
                                    Task {
                                        await searchComuni(query: query)
                                    }
                                },
                                onLocate: {
                                    Task {
                                        await locateComune()
                                    }
                                },
                                onSelectConfigured: { nome in
                                    Task {
                                        await loadConfiguredComune(nome)
                                    }
                                },
                                onSelectSuggestion: { _ in
                                    comuneSuggestions = []
                                }
                            )
                        case .weeklySchedule:
                            WeeklyConfigurationStep(profile: $draftProfile)
                        case .review:
                            SetupReviewStep(
                                profile: draftProfile,
                                reminderTime: $draftReminderTime
                            )
                        }
                    }
                    .padding(.bottom, 12)
                }

                footer
            }
            .padding(20)
        }
        .interactiveDismissDisabled(true)
        .task {
            await loadConfiguredComuni()
        }
        .onChange(of: draftProfile.municipalityName) { _, newValue in
            selectedFromList = false
            guard newValue.count >= 2 else {
                comuneSuggestions = []
                return
            }
            Task {
                await searchComuni(query: newValue)
            }
        }
    }

    private var topBar: some View {
        HStack {
            if !isInitialSetup {
                Button(action: cancelEditing) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color(red: 0.13, green: 0.21, blue: 0.23))
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.86), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Text(isInitialSetup ? "Prima configurazione" : "Modifica profilo")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.14), in: Capsule())
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(SetupStep.allCases) { step in
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue ? .white : .white.opacity(0.24))
                        .frame(height: 6)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(currentStep.title)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(currentStep.subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if currentStep != .municipality {
                Button(action: goBack) {
                    Text("Indietro")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.16, green: 0.21, blue: 0.23))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.white.opacity(0.88))
                        )
                }
                .buttonStyle(.plain)
            }

            Button(action: advance) {
                Text(currentStep.primaryButtonTitle)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(canContinue ? .white : .white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(canContinue ? Color(red: 0.08, green: 0.22, blue: 0.17) : Color.white.opacity(0.20))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)
        }
    }

    private func goBack() {
        guard let previousStep = SetupStep(rawValue: currentStep.rawValue - 1) else {
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            currentStep = previousStep
        }
    }

    private func advance() {
        if currentStep == .review {
            saveProfile()
            return
        }

        guard let nextStep = SetupStep(rawValue: currentStep.rawValue + 1) else {
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            currentStep = nextStep
        }
    }

    private func saveProfile() {
        draftProfile.municipalityName = trimmedMunicipalityName
        wasteProfileStore.save(profile: draftProfile)
        notificationManager.updateReminderTime(draftReminderTime)

        // Salva anche sul DB remoto (best-effort)
        if !draftProfile.municipalityName.isEmpty {
            Task {
                do {
                    try await DatabaseService.salva(profilo: draftProfile)
                    print("[DB] Profilo salvato per \(draftProfile.municipalityName)")
                } catch {
                    print("[DB] Salvataggio remoto fallito (riprova dopo): \(error.localizedDescription)")
                }
            }
        }

        if !isInitialSetup {
            dismiss()
        }
    }

    private func cancelEditing() {
        wasteProfileStore.dismissEditor()
        dismiss()
    }

    // MARK: - API / GPS

    private func searchComuni(query: String) async {
        guard query.count >= 2, !selectedFromList else { return }

        isLoadingSuggestions = true
        do {
            let risultati = try await DatabaseService.cercaComuni(query: query)
            comuneSuggestions = risultati
        } catch {
            comuneSuggestions = []
        }
        isLoadingSuggestions = false
    }

    private func locateComune() async {
        isLocating = true

        do {
            let location = try await LocationHelper.requestOneTimeLocation()
            let comune = try await DatabaseService.comuneDaCoordinate(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            draftProfile.municipalityName = comune.nome
            comuneSuggestions = []
        } catch {
            print("[GPS] Posizione non disponibile: \(error.localizedDescription)")
        }

        isLocating = false
    }

    private func loadConfiguredComuni() async {
        isLoadingConfigured = true
        do {
            let nomi = try await DatabaseService.profili()
            configuredComuni = nomi.filter { $0 != draftProfile.municipalityName }
        } catch {
            configuredComuni = []
        }
        isLoadingConfigured = false
    }

    private func loadConfiguredComune(_ nome: String) async {
        isLoadingConfigured = true
        do {
            let profilo = try await DatabaseService.profilo(comune: nome)
            draftProfile = profilo
            selectedFromList = true
            comuneSuggestions = []

            // Vai direttamente alla review
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                currentStep = .review
            }
        } catch {
            print("[DB] Impossibile caricare il profilo di \(nome): \(error.localizedDescription)")
        }
        isLoadingConfigured = false
    }
}

private struct MunicipalityNameStep: View {
    @Binding var profile: MunicipalityProfile
    let comuneSuggestions: [(nome: String, provincia: String)]
    let configuredComuni: [String]
    let isLoadingSuggestions: Bool
    let isLoadingConfigured: Bool
    let isLocating: Bool
    let showConfiguredList: Bool
    let onSearch: (String) -> Void
    let onLocate: () -> Void
    let onSelectConfigured: (String) -> Void
    let onSelectSuggestion: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // ── Card: Nome comune + GPS ───────────────────────
            SetupCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text("Nome del Comune")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))

                        Spacer(minLength: 0)

                        Button(action: onLocate) {
                            HStack(spacing: 4) {
                                if isLocating {
                                    ProgressView()
                                        .tint(Color(red: 0.13, green: 0.42, blue: 0.32))
                                } else {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Posizione")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundStyle(Color(red: 0.13, green: 0.42, blue: 0.32))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.91, green: 0.97, blue: 0.92))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isLocating)
                    }

                    HStack(spacing: 10) {
                        TextField("Cerca un comune (es. Acireale)", text: $profile.municipalityName)
                            .textInputAutocapitalization(.words)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 0.95, green: 0.96, blue: 0.95))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                    }

                    // ── Suggerimenti autocomplete ────────────────
                    if !comuneSuggestions.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(comuneSuggestions, id: \.nome) { suggestion in
                                Button {
                                    profile.municipalityName = suggestion.nome
                                    onSelectSuggestion(suggestion.nome)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "mappin")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color(red: 0.13, green: 0.42, blue: 0.32))

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(suggestion.nome)
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))

                                            if !suggestion.provincia.isEmpty {
                                                Text(suggestion.provincia)
                                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                                    .foregroundStyle(Color(red: 0.35, green: 0.41, blue: 0.44))
                                            }
                                        }

                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color(red: 0.97, green: 0.98, blue: 0.97))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if isLoadingSuggestions {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Color(red: 0.13, green: 0.42, blue: 0.32))
                            Text("Cerco comuni...")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.43))
                        }
                    }

                    Text("Scrivi il nome o usa il pulsante posizione per trovarlo automaticamente.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.43))
                }
            }

            // ── Comuni già configurati (dal DB remoto) ───────
            if showConfiguredList && !configuredComuni.isEmpty {
                SetupCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comuni già configurati")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))

                        Text("Seleziona un comune per usarne la configurazione.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.43))

                        if isLoadingConfigured {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(Color(red: 0.13, green: 0.42, blue: 0.32))
                                Text("Caricamento...")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.43))
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(configuredComuni, id: \.self) { nome in
                                        Button {
                                            onSelectConfigured(nome)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "building.2.fill")
                                                    .font(.system(size: 11))
                                                Text(nome)
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                            }
                                            .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.18))
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
                        }
                    }
                }
            }

            // ── Stats pill ───────────────────────────────────
            SetupCard {
                HStack(spacing: 14) {
                    SetupStatPill(title: "Comune", value: profile.municipalityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Da inserire" : profile.municipalityName)
                    SetupStatPill(title: "Giorni", value: "\(profile.configuredDayCount) configurati")
                }
            }
        }
    }
}

private struct WeeklyConfigurationStep: View {
    @Binding var profile: MunicipalityProfile

    private let columns = [
        GridItem(.adaptive(minimum: 108), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(MunicipalityProfile.orderedWeekdays, id: \.self) { weekday in
                let day = profile.day(for: weekday)

                SetupCard {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(MunicipalityProfile.dayName(for: weekday))
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))

                            Text(summary(for: day))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(red: 0.35, green: 0.41, blue: 0.44))
                        }

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(WasteCatalog.allMaterials) { material in
                                Button {
                                    profile.toggleMaterial(material.id, for: weekday)
                                } label: {
                                    MaterialSelectionChip(
                                        title: material.name,
                                        tint: material.tint,
                                        isSelected: profile.includesMaterial(material.id, on: weekday)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            profile.setSupplementaryDiapers(!day.includesSupplementaryDiapers, for: weekday)
                        } label: {
                            SupplementarySelectionRow(isEnabled: day.includesSupplementaryDiapers)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func summary(for day: WasteCollectionDay) -> String {
        var parts = day.materialIDs.compactMap { WasteCatalog.material(for: $0)?.name }

        if day.includesSupplementaryDiapers {
            parts.append("Pannolini")
        }

        return parts.isEmpty ? "Nessun ritiro" : parts.joined(separator: " • ")
    }
}

private struct SetupReviewStep: View {
    let profile: MunicipalityProfile
    @Binding var reminderTime: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SetupCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Riepilogo")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))

                    HStack(spacing: 12) {
                        SetupStatPill(title: "Comune", value: profile.municipalityName)
                        SetupStatPill(title: "Giorni", value: "\(profile.configuredDayCount) attivi")
                    }
                }
            }

            // ── Disclaimer calendario ────────────────────────
            SetupCard {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 0.85, green: 0.50, blue: 0.10))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verifica prima di salvare")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))

                        Text("Controlla che i giorni e i materiali qui sotto corrispondano al calendario ufficiale del tuo Comune.\n\nOgni Comune ha il proprio calendario di raccolta che può variare nel tempo (festività, cambi di gestione, modifiche stagionali).\n\nSe non sei sicuro, confronta con il sito web o l'app del tuo Comune prima di confermare.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 0.30, green: 0.38, blue: 0.41))
                            .lineSpacing(3)
                    }
                }
            }

            SetupCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Promemoria serale")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))

                    DatePicker(
                        "Orario",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Text("L'app invierà un avviso la sera prima del ritiro.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.35, green: 0.41, blue: 0.44))
                }
            }

            SetupCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Calendario settimanale")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))

                    VStack(spacing: 10) {
                        ForEach(MunicipalityProfile.orderedWeekdays, id: \.self) { weekday in
                            HStack(alignment: .top, spacing: 12) {
                                Text(MunicipalityProfile.dayName(for: weekday))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.22, green: 0.28, blue: 0.31))
                                    .frame(width: 92, alignment: .leading)

                                Text(profile.pickupSummary(for: weekday))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.11, green: 0.17, blue: 0.18))
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct SetupCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct SetupStatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.35, green: 0.41, blue: 0.44))

            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.95, green: 0.96, blue: 0.95))
        )
    }
}

private struct MaterialSelectionChip: View {
    let title: String
    let tint: Color
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(isSelected ? selectionTextColor : Color(red: 0.21, green: 0.27, blue: 0.30))
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? tint : Color(red: 0.95, green: 0.96, blue: 0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.15) : Color.black.opacity(0.05), lineWidth: 1)
            )
    }

    private var selectionTextColor: Color {
        tint.isLightColor ? Color(red: 0.11, green: 0.16, blue: 0.18) : .white
    }
}

private struct SupplementarySelectionRow: View {
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Servizio pannolini")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.17))

                Text(isEnabled ? "Attivo in questa giornata" : "Non attivo")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isEnabled ? Color(red: 0.13, green: 0.42, blue: 0.32) : Color(red: 0.36, green: 0.42, blue: 0.45))
            }

            Spacer(minLength: 0)

            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isEnabled ? Color(red: 0.13, green: 0.42, blue: 0.32) : Color(red: 0.70, green: 0.73, blue: 0.75))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isEnabled ? Color(red: 0.91, green: 0.97, blue: 0.92) : Color(red: 0.96, green: 0.97, blue: 0.97))
        )
    }
}

private struct SetupBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.29, blue: 0.23),
                Color(red: 0.17, green: 0.50, blue: 0.38),
                Color(red: 0.74, green: 0.86, blue: 0.70)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 18)
                .offset(x: -70, y: -60)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 18)
                .offset(x: 90, y: 100)
        }
    }
}

// MARK: - Location Helper

@MainActor
private enum LocationHelper {
    static func requestOneTimeLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            let manager = LocationManagerBridge()
            manager.start { result in
                switch result {
                case .success(let location):
                    continuation.resume(returning: location)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

@MainActor
private final class LocationManagerBridge: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Result<CLLocation, Error>) -> Void)?

    func start(completion: @escaping (Result<CLLocation, Error>) -> Void) {
        self.completion = completion
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            completion(.failure(LocationError.denied))
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        @unknown default:
            completion(.failure(LocationError.unknown))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            guard let location = locations.last else { return }
            completion?(.success(location))
            completion = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            completion?(.failure(error))
            completion = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                completion?(.failure(LocationError.denied))
                completion = nil
            default:
                break
            }
        }
    }
}

private enum LocationError: LocalizedError {
    case denied
    case unknown

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Posizione non consentita. Abilitala dalle Impostazioni."
        case .unknown:
            return "Errore sconosciuto nella lettura della posizione."
        }
    }
}

private extension Color {
    var isLightColor: Bool {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let perceivedBrightness = ((red * 299) + (green * 587) + (blue * 114)) / 1000
        return perceivedBrightness > 0.62
        #else
        return false
        #endif
    }
}
