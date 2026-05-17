-- ============================================================
-- Acireale Differenziata — Database Struttura
-- MariaDB 10.11 / MySQL 8+
-- Importa questo file via phpMyAdmin (scheda SQL)
-- ============================================================

CREATE TABLE IF NOT EXISTS comuni_profiles (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    comune_nome     VARCHAR(255) NOT NULL,
    profile_json    JSON NOT NULL,
    version         INT NOT NULL DEFAULT 1,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_comune (comune_nome),
    INDEX idx_comune_nome (comune_nome)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
