//
//  AppGroupUserDefaults.swift
//  Differenziata
//
//  Condivisione dati tra app principale e widget via App Group.
//

import Foundation

extension UserDefaults {
    /// UserDefaults condiviso tra app e widget tramite App Group.
    /// Abilita App Group nelle Capabilities di entrambi i target.
    static let appGroup: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: AppGroupIdentifier.suiteName) else {
            return .standard
        }
        return defaults
    }()
}

enum AppGroupIdentifier {
    /// App Group da abilitare in Xcode:
    /// Target → Signing & Capabilities → + → App Groups → group.it.alessandrodigiusto.Differenziata
    static let suiteName = "group.it.alessandrodigiusto.Differenziata"

    /// Chiave UserDefaults per il profilo serializzato
    static let profileKey = "widget.currentProfile"
}
