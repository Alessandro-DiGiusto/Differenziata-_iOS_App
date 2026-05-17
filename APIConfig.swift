//
//  APIConfig.swift
//  Acireale Differenziata
//
//  Configurazione per il backend.
//

import Foundation

enum APIConfig {
    static let apiBaseURL = "https://alessandrodigiusto.it/assets/differenziata.php"

    /// Timeout per le richieste HTTP (secondi)
    static let timeout: TimeInterval = 10
}
