//
//  NotificationSupport.swift
//  Acireale Differenziata
//

import Combine
import Foundation
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        WasteNotificationManager.shared.registerNotificationCategories()
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            WasteNotificationManager.shared.handleNotificationResponse(response)
        }
    }
}

@MainActor
final class WasteNotificationManager: ObservableObject {
    static let shared = WasteNotificationManager()

    @Published private(set) var confettiBurstID: UUID?
    @Published private(set) var reminderTime: Date

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    private let categoryIdentifier = "waste.pickup.category"
    private let confirmActionIdentifier = "waste.pickup.confirmed"
    private let remindActionIdentifier = "waste.pickup.remindLater"
    private let pendingConfettiKey = "waste.pickup.pendingConfetti"
    private let reminderPrefix = "waste.pickup.reminder."
    private let reminderDelay: TimeInterval = 30 * 60
    private let reminderHourKey = "waste.pickup.reminder.hour"
    private let reminderMinuteKey = "waste.pickup.reminder.minute"

    private var weeklyNotificationIDs: [String] {
        (1...7).map { "waste.pickup.weekly.\($0)" }
    }

    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// Ultimo orario per cui abbiamo schedulato le notifiche (evita di rischedulare a ogni onAppear)
    private var lastScheduledHour: Int {
        get { defaults.integer(forKey: "waste.pickup.lastScheduledHour") }
        set { defaults.set(newValue, forKey: "waste.pickup.lastScheduledHour") }
    }
    private var lastScheduledMinute: Int {
        get { defaults.integer(forKey: "waste.pickup.lastScheduledMinute") }
        set { defaults.set(newValue, forKey: "waste.pickup.lastScheduledMinute") }
    }

    private init() {
        let hour = defaults.object(forKey: reminderHourKey) as? Int ?? 22
        let minute = defaults.object(forKey: reminderMinuteKey) as? Int ?? 0
        reminderTime = Self.dateFor(hour: hour, minute: minute)
    }

    func updateReminderTime(_ date: Date) {
        reminderTime = date

        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 22
        let minute = components.minute ?? 0

        defaults.set(hour, forKey: reminderHourKey)
        defaults.set(minute, forKey: reminderMinuteKey)

        guard !isRunningInPreview else {
            return
        }

        Task { @MainActor in
            await requestAccessAndScheduleNotifications()
        }
    }

    func activate() {
        guard !isRunningInPreview else {
            return
        }

        consumePendingConfettiIfNeeded()

        let hour = Calendar.autoupdatingCurrent.component(.hour, from: reminderTime)
        let minute = Calendar.autoupdatingCurrent.component(.minute, from: reminderTime)

        // Se l'orario non è cambiato, le notifiche sono già schedulatie — saltiamo
        guard hour != lastScheduledHour || minute != lastScheduledMinute else {
            return
        }

        Task { @MainActor in
            await requestAccessAndScheduleNotifications()
        }
    }

    func registerNotificationCategories() {
        let confirmAction = UNNotificationAction(
            identifier: confirmActionIdentifier,
            title: "Ho buttato",
            options: [.foreground]
        )

        let remindAction = UNNotificationAction(
            identifier: remindActionIdentifier,
            title: "Ricordamelo dopo",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [confirmAction, remindAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        switch response.actionIdentifier {
        case confirmActionIdentifier:
            Task { @MainActor in
                await clearReminderNotifications()
                storePendingConfetti()
            }

        case remindActionIdentifier:
            let content = response.notification.request.content

            Task { @MainActor in
                await scheduleReminder(from: content)
            }

        default:
            break
        }
    }

    private func requestAccessAndScheduleNotifications() async {
        let settings = await currentNotificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            await scheduleWeeklyNotifications()

        case .notDetermined:
            let granted = await requestAuthorization()
            guard granted else {
                return
            }

            await scheduleWeeklyNotifications()

        default:
            break
        }
    }

    private func scheduleWeeklyNotifications() async {
        center.removePendingNotificationRequests(withIdentifiers: weeklyNotificationIDs)

        // Salva l'orario per cui abbiamo schedulato (evita rischedule a ogni onAppear)
        lastScheduledHour = reminderHour
        lastScheduledMinute = reminderMinute

        for weekday in 1...7 {
            let payload = notificationPayload(forScheduledWeekday: weekday)
            let content = UNMutableNotificationContent()
            content.title = payload.title
            content.body = payload.body
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier
            content.userInfo = [
                "title": payload.title,
                "body": payload.body
            ]

            var components = DateComponents()
            components.weekday = weekday
            components.hour = reminderHour
            components.minute = reminderMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "waste.pickup.weekly.\(weekday)",
                content: content,
                trigger: trigger
            )

            await addNotificationRequest(request)
        }
    }

    private func scheduleReminder(from content: UNNotificationContent) async {
        let reminder = UNMutableNotificationContent()
        reminder.title = content.userInfo["title"] as? String ?? content.title
        reminder.body = content.userInfo["body"] as? String ?? content.body
        reminder.sound = .default
        reminder.categoryIdentifier = categoryIdentifier
        reminder.userInfo = content.userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminderDelay, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminderPrefix + UUID().uuidString,
            content: reminder,
            trigger: trigger
        )

        await addNotificationRequest(request)
    }

    private func clearReminderNotifications() async {
        let requests = await pendingNotificationRequests()
        let reminderIDs = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(reminderPrefix) }

        guard !reminderIDs.isEmpty else {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: reminderIDs)
    }

    private func storePendingConfetti() {
        let currentValue = defaults.integer(forKey: pendingConfettiKey)
        defaults.set(currentValue + 1, forKey: pendingConfettiKey)
    }

    private func consumePendingConfettiIfNeeded() {
        let pendingValue = defaults.integer(forKey: pendingConfettiKey)
        guard pendingValue > 0 else {
            return
        }

        defaults.set(0, forKey: pendingConfettiKey)
        confettiBurstID = UUID()
    }

    private func notificationPayload(forScheduledWeekday weekday: Int) -> NotificationPayload {
        let tomorrowWeekday = weekday == 7 ? 1 : weekday + 1
        let materialNames = WasteSchedule.materials(for: tomorrowWeekday).map(\.name)
        let includesDiapers = WasteSchedule.supplementaryDiapersWeekdays.contains(tomorrowWeekday)

        if materialNames.isEmpty && !includesDiapers {
            return NotificationPayload(
                title: "Stasera non devi esporre nulla",
                body: "Domani mattina non è previsto alcun ritiro."
            )
        }

        let itemsToPutOut = materialNames + (includesDiapers ? ["Pannolini"] : [])
        let title = "Metti fuori \(naturalJoin(itemsToPutOut))"

        if materialNames.isEmpty && includesDiapers {
            return NotificationPayload(
                title: title,
                body: "Domani mattina è attivo il servizio pannolini."
            )
        }

        if includesDiapers {
            return NotificationPayload(
                title: title,
                body: "Domani mattina ritirano \(naturalJoin(materialNames)). È attivo anche il servizio pannolini."
            )
        }

        return NotificationPayload(
            title: title,
            body: "Domani mattina ritirano \(naturalJoin(materialNames))."
        )
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

    private func currentNotificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func addNotificationRequest(_ request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume(returning: ())
            }
        }
    }

    private var reminderHour: Int {
        Calendar.autoupdatingCurrent.component(.hour, from: reminderTime)
    }

    private var reminderMinute: Int {
        Calendar.autoupdatingCurrent.component(.minute, from: reminderTime)
    }

    private static func dateFor(hour: Int, minute: Int) -> Date {
        var components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: .now)
        components.hour = hour
        components.minute = minute
        return Calendar.autoupdatingCurrent.date(from: components) ?? .now
    }
}

private struct NotificationPayload {
    let title: String
    let body: String
}

struct ConfettiOverlay: View {
    let trigger: UUID?

    @State private var isActive = false
    @State private var lastHandledTrigger: UUID?
    @StateObject private var simulation = ConfettiSimulation()

    var body: some View {
        GeometryReader { proxy in
            Group {
                if isActive {
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                            simulation.draw(in: &context, size: size)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            tick(size: proxy.size)
                        }
                        .onChange(of: timeline.date) { _, _ in
                            tick(size: proxy.size)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                handleTrigger(trigger, size: proxy.size)
            }
            .onChange(of: trigger) { _, newValue in
                handleTrigger(newValue, size: proxy.size)
            }
        }
        .allowsHitTesting(false)
        .zIndex(999)
    }

    private func handleTrigger(_ newTrigger: UUID?, size: CGSize) {
        guard let newTrigger, lastHandledTrigger != newTrigger else {
            return
        }

        lastHandledTrigger = newTrigger
        simulation.start(size: size, now: CACurrentMediaTime())
        isActive = true
    }

    private func tick(size: CGSize) {
        simulation.update(now: CACurrentMediaTime(), size: size)

        if isActive && !simulation.isActive {
            isActive = false
        }
    }
}

@MainActor
private final class ConfettiSimulation: ObservableObject {
    static let gravity: CGFloat = 420
    static let exitOffset: CGFloat = 60
    static let fadeDuration: Double = 0.3
    static let pieceCount = 80

    private(set) var particles: [ConfettiParticle] = []
    private(set) var isActive = false

    private var lastUpdateTime: CFTimeInterval?

    func start(size: CGSize, now: CFTimeInterval) {
        particles = (0..<Self.pieceCount).map { _ in ConfettiParticle.random(in: size) }
        lastUpdateTime = now
        isActive = true
    }

    func update(now: CFTimeInterval, size: CGSize) {
        guard isActive else {
            return
        }

        let previousTime = lastUpdateTime ?? now
        lastUpdateTime = now

        let deltaTime = min(max(now - previousTime, 1.0 / 240.0), 1.0 / 24.0)
        guard deltaTime > 0 else {
            return
        }

        var unfinishedParticles = 0

        for index in particles.indices {
            particles[index].advance(by: deltaTime, canvasHeight: size.height)

            if !particles[index].isDone {
                unfinishedParticles += 1
            }
        }

        if unfinishedParticles == 0 {
            isActive = false
        }
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        guard isActive else {
            return
        }

        for particle in particles {
            guard let state = particle.renderState(screenHeight: size.height) else {
                continue
            }

            var layer = context
            layer.opacity = state.opacity
            layer.translateBy(x: state.position.x, y: state.position.y)
            layer.rotate(by: .degrees(state.rotationDegrees))
            layer.scaleBy(x: CGFloat(state.flipScaleX), y: 1)
            layer.fill(path(for: state.shape), with: .color(state.color))
        }
    }

    private func path(for shape: ConfettiShape) -> Path {
        switch shape {
        case .rectangle:
            return Path(CGRect(x: -4, y: -8, width: 8, height: 16))

        case .circle:
            return Path(ellipseIn: CGRect(x: -4.5, y: -4.5, width: 9, height: 9))

        case .strip:
            return Path(CGRect(x: -2, y: -9, width: 4, height: 18))
        }
    }
}

private struct ConfettiParticle {
    let shape: ConfettiShape
    let color: Color
    let delay: Double
    let wobbleAmplitude: CGFloat
    let wobbleFrequency: Double
    let wobblePhase: Double
    let angularVelocity: Double
    let initialAngle: Double
    let flipFrequency: Double
    let flipPhase: Double

    var position: CGPoint
    var velocity: CGVector
    var elapsed: Double = 0
    var isDone = false

    static func random(in size: CGSize) -> ConfettiParticle {
        let width = max(size.width, 1)
        let shapeRoll = Double.random(in: 0...1)
        let shape: ConfettiShape

        switch shapeRoll {
        case ..<0.60:
            shape = .rectangle
        case ..<0.85:
            shape = .circle
        default:
            shape = .strip
        }

        let palette: [Color] = [
            Color(red: 33.0 / 255.0, green: 104.0 / 255.0, blue: 59.0 / 255.0),
            Color(red: 1.0, green: 215.0 / 255.0, blue: 0),
            Color(red: 1.0, green: 107.0 / 255.0, blue: 53.0 / 255.0),
            Color(red: 30.0 / 255.0, green: 111.0 / 255.0, blue: 220.0 / 255.0),
            .white,
            Color(red: 232.0 / 255.0, green: 93.0 / 255.0, blue: 154.0 / 255.0)
        ]

        return ConfettiParticle(
            shape: shape,
            color: palette.randomElement() ?? .white,
            delay: Double.random(in: 0...0.5),
            wobbleAmplitude: CGFloat.random(in: 8...22),
            wobbleFrequency: Double.random(in: 1.5...3.5),
            wobblePhase: Double.random(in: 0...(2 * .pi)),
            angularVelocity: Double.random(in: 180...540),
            initialAngle: Double.random(in: 0...360),
            flipFrequency: Double.random(in: 4.5...8.5),
            flipPhase: Double.random(in: 0...(2 * .pi)),
            position: CGPoint(x: CGFloat.random(in: 0...width), y: -30),
            velocity: CGVector(
                dx: CGFloat.random(in: -80...80),
                dy: CGFloat.random(in: 300...520)
            )
        )
    }

    mutating func advance(by deltaTime: Double, canvasHeight: CGFloat) {
        guard !isDone else {
            return
        }

        let previousElapsed = elapsed
        elapsed += deltaTime

        let previousActiveTime = max(0, previousElapsed - delay)
        let currentActiveTime = max(0, elapsed - delay)
        let activeDelta = currentActiveTime - previousActiveTime

        guard activeDelta > 0 else {
            return
        }

        let step = CGFloat(activeDelta)
        position.x += velocity.dx * step
        velocity.dx *= CGFloat(pow(0.97, Double(step * 60)))

        position.y += velocity.dy * step + (0.5 * ConfettiSimulation.gravity * step * step)
        velocity.dy += ConfettiSimulation.gravity * step

        if position.y > canvasHeight + ConfettiSimulation.exitOffset {
            isDone = true
        }
    }

    func renderState(screenHeight: CGFloat) -> ConfettiRenderState? {
        guard !isDone, elapsed >= delay else {
            return nil
        }

        let age = elapsed - delay
        let wobbleOffset = CGFloat(sin((age * wobbleFrequency * 2 * .pi) + wobblePhase)) * wobbleAmplitude
        let flipScaleX = 0.15 + (0.85 * abs(sin((age * flipFrequency * 2 * .pi) + flipPhase)))
        let opacity = opacity(screenHeight: screenHeight)

        guard opacity > 0 else {
            return nil
        }

        return ConfettiRenderState(
            shape: shape,
            color: color,
            position: CGPoint(x: position.x + wobbleOffset, y: position.y),
            rotationDegrees: initialAngle + (angularVelocity * age),
            flipScaleX: flipScaleX,
            opacity: opacity
        )
    }

    private func opacity(screenHeight: CGFloat) -> Double {
        let timeToExit = timeToExit(screenHeight: screenHeight)

        if timeToExit >= ConfettiSimulation.fadeDuration {
            return 1
        }

        return max(0, timeToExit / ConfettiSimulation.fadeDuration)
    }

    private func timeToExit(screenHeight: CGFloat) -> Double {
        let exitY = screenHeight + ConfettiSimulation.exitOffset
        let a = 0.5 * Double(ConfettiSimulation.gravity)
        let b = Double(velocity.dy)
        let c = Double(position.y - exitY)
        let discriminant = (b * b) - (4 * a * c)

        guard discriminant >= 0 else {
            return 0
        }

        return max(0, (-b + sqrt(discriminant)) / (2 * a))
    }
}

private struct ConfettiRenderState {
    let shape: ConfettiShape
    let color: Color
    let position: CGPoint
    let rotationDegrees: Double
    let flipScaleX: Double
    let opacity: Double
}

private enum ConfettiShape {
    case rectangle
    case circle
    case strip
}
