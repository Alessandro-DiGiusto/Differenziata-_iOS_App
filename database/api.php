<?php
/**
 * Acireale Differenziata — API REST
 * 
 * Carica questo file nella root del tuo hosting.
 * Esempio: https://tuodominio.it/api.php
 *
 * Endpoint disponibili:
 * 
 *   GET  api.php?action=profili
 *     → Lista di tutti i comuni con profilo salvato
 *     → Formato: { "success": true, "data": ["Acireale", ...] }
 * 
 *   GET  api.php?action=profilo&comune=Acireale
 *     → Dettaglio profilo di un comune specifico
 *     → Formato: { "success": true, "data": { "comune_nome": "...", "profile_json": {...} } }
 * 
 *   POST api.php?action=salva
 *     → Crea o aggiorna il profilo di un comune
 *     → Body (JSON): { "comune_nome": "Acireale", "profile_json": {...} }
 *     → Formato: { "success": true, "message": "Profilo salvato" }
 *
 *   GET  api.php?action=comuni&q=acir
 *     → Cerca comuni italiani (tramite Nominatim/OSM, gratis, senza API key)
 *     → Formato: { "success": true, "data": [ { "nome": "...", "provincia": "...", "lat": ..., "lon": ... } ] }
 *
 *   GET  api.php?action=comune_vicino&lat=37.612&lon=15.166
 *     → Trova il comune più vicino alle coordinate GPS
 *     → Formato: { "success": true, "data": { "nome": "...", "provincia": "...", "distanza_km": ... } }
 */

// ── Configurazione Database ──────────────────────────────────
// Queste credenziali le inserisci tu
$DB_HOST = 'db5020472909.hosting-data.io';
$DB_PORT = 3306;
$DB_NAME = 'dbs15681565';
$DB_USER = 'dbu803965';
$DB_PASS = '';            // ← INSERISCI QUI LA PASSWORD DEL DATABASE

// ── Setup ─────────────────────────────────────────────────────
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// ── Connessione MySQL (PDO) ───────────────────────────────────
try {
    $pdo = new PDO(
        "mysql:host=$DB_HOST;port=$DB_PORT;dbname=$DB_NAME;charset=utf8mb4",
        $DB_USER,
        $DB_PASS,
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]
    );
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Connessione DB fallita']);
    exit;
}

// ── Route ─────────────────────────────────────────────────────
$action = $_GET['action'] ?? '';

switch ($action) {

    // ── Lista comuni con profilo ──────────────────────────────
    case 'profili':
        $stmt = $pdo->query("SELECT comune_nome FROM comuni_profiles ORDER BY comune_nome ASC");
        $rows = $stmt->fetchAll();
        $nomi = array_map(fn($r) => $r['comune_nome'], $rows);
        echo json_encode(['success' => true, 'data' => $nomi]);
        break;

    // ── Dettaglio profilo di un comune ────────────────────────
    case 'profilo':
        $comune = trim($_GET['comune'] ?? '');
        if ($comune === '') {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Parametro "comune" mancante']);
            break;
        }
        $stmt = $pdo->prepare("SELECT comune_nome, profile_json, updated_at FROM comuni_profiles WHERE comune_nome = :comune LIMIT 1");
        $stmt->execute([':comune' => $comune]);
        $row = $stmt->fetch();
        if (!$row) {
            http_response_code(404);
            echo json_encode(['success' => false, 'error' => 'Comune non trovato']);
            break;
        }
        $row['profile_json'] = json_decode($row['profile_json'], true);
        echo json_encode(['success' => true, 'data' => $row]);
        break;

    // ── Salva / aggiorna profilo ──────────────────────────────
    case 'salva':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            http_response_code(405);
            echo json_encode(['success' => false, 'error' => 'Usa POST']);
            break;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        $comune = trim($input['comune_nome'] ?? '');
        $profileJson = $input['profile_json'] ?? null;

        if ($comune === '' || $profileJson === null) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Campi "comune_nome" e "profile_json" obbligatori']);
            break;
        }

        $encoded = json_encode($profileJson, JSON_UNESCAPED_UNICODE);
        if ($encoded === false) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'profile_json non valido']);
            break;
        }

        $stmt = $pdo->prepare("
            INSERT INTO comuni_profiles (comune_nome, profile_json, version)
            VALUES (:comune, :json, 1)
            ON DUPLICATE KEY UPDATE
                profile_json = VALUES(profile_json),
                version = version + 1
        ");
        $stmt->execute([':comune' => $comune, ':json' => $encoded]);

        echo json_encode(['success' => true, 'message' => 'Profilo salvato']);
        break;

    // ── Cerca comuni via Nominatim (OSM) ──────────────────────
    case 'comuni':
        $q = trim($_GET['q'] ?? '');
        if ($q === '') {
            echo json_encode(['success' => true, 'data' => []]);
            break;
        }

        $url = 'https://nominatim.openstreetmap.org/search?'
             . http_build_query([
                 'q'            => $q . ', Italia',
                 'format'       => 'json',
                 'limit'        => 10,
                 'countrycodes' => 'IT',
                 'featuretype'  => 'city',
             ]);

        $context = stream_context_create([
            'http' => [
                'header' => "User-Agent: AcirealeDifferenziata/1.0 (ios)\r\n",
                'timeout' => 5,
            ]
        ]);

        $response = @file_get_contents($url, false, $context);
        if ($response === false) {
            echo json_encode(['success' => true, 'data' => []]);
            break;
        }

        $results = json_decode($response, true) ?? [];
        $comuni = [];

        foreach ($results as $r) {
            $parti = explode(',', $r['display_name']);
            $comune = trim($parti[0] ?? '');
            $provincia = '';

            // Estrai provincia dal display_name (es: "Acireale, Catania, Sicilia, Italia")
            foreach ($parti as $p) {
                $p = trim($p);
                // Le province italiane sono 2 lettere maiuscole oppure "Città Metropolitana di ..."
                if (preg_match('/^\p{Lu}{2}$/u', $p)) {
                    $provincia = $p;
                    break;
                }
                if (stripos($p, 'metropolitana') !== false) {
                    $provincia = trim(str_ireplace(['Città Metropolitana di ', 'Città metropolitana di '], '', $p));
                    break;
                }
            }

            if ($comune !== '' && $comune !== 'Italia') {
                $comuni[] = [
                    'nome'      => $comune,
                    'provincia' => $provincia ?: ($parti[1] ?? ''),
                    'lat'       => (float)$r['lat'],
                    'lon'       => (float)$r['lon'],
                ];
            }
        }

        echo json_encode(['success' => true, 'data' => $comuni]);
        break;

    // ── Trova comune da coordinate GPS ─────────────────────────
    case 'comune_vicino':
        $lat = (float)($_GET['lat'] ?? 0);
        $lon = (float)($_GET['lon'] ?? 0);

        if ($lat == 0 || $lon == 0) {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Parametri "lat" e "lon" obbligatori']);
            break;
        }

        $url = 'https://nominatim.openstreetmap.org/reverse?'
             . http_build_query([
                 'lat'      => $lat,
                 'lon'      => $lon,
                 'format'   => 'json',
                 'zoom'     => 14,
                 'language' => 'it',
             ]);

        $context = stream_context_create([
            'http' => [
                'header' => "User-Agent: AcirealeDifferenziata/1.0 (ios)\r\n",
                'timeout' => 5,
            ]
        ]);

        $response = @file_get_contents($url, false, $context);
        if ($response === false) {
            http_response_code(502);
            echo json_encode(['success' => false, 'error' => 'Nominatim non raggiungibile']);
            break;
        }

        $data = json_decode($response, true);
        $address = $data['address'] ?? [];

        $comune = $address['city']
               ?? $address['town']
               ?? $address['village']
               ?? $address['municipality']
               ?? null;

        $provincia = $address['province']
                  ?? $address['state_district']
                  ?? '';

        if (!$comune) {
            echo json_encode(['success' => false, 'error' => 'Comune non trovato per queste coordinate']);
            break;
        }

        echo json_encode(['success' => true, 'data' => [
            'nome'      => $comune,
            'provincia' => $provincia,
            'lat'       => $data['lat'] ?? $lat,
            'lon'       => $data['lon'] ?? $lon,
        ]]);
        break;

    // ── 404 ────────────────────────────────────────────────────
    default:
        http_response_code(404);
        echo json_encode(['success' => false, 'error' => 'Azione sconosciuta. Azioni: profili, profilo, salva, comuni, comune_vicino']);
        break;
}
