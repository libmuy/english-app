<?php
#require '../vendor/autoload.php'; // Adjust the path to point to the correct location
require __DIR__ . '/../vendor/autoload.php';

use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;
use Dotenv\Dotenv;

// Load environment variables from tmpfs
$dotenv = Dotenv::createImmutable('/tmpfs');
$dotenv->load();

// Generate a token
function generateToken($userId) {
    $currentVersion = $_ENV['JWT_CURRENT_VERSION'] ?? null;
    $key = $_ENV["JWT_SECRET_KEY_$currentVersion"] ?? null;

    if (!$key) {
        throw new Exception('Secret key not set');
    }

    $payload = [
        "iss" => "libmuy.com", // Issuer
        "aud" => "libmuy.com", // Audience
        "iat" => time(), // Issued at
        "nbf" => time(), // Not before
        "exp" => time() + (60 * 60 * 24 * 60), // Expiration: 1 week
        "data" => [
            "userId" => $userId
        ],
        "version" => $currentVersion // Include version in the token
    ];

    return JWT::encode($payload, $key, 'HS256');
}

// Validate a token
function validateToken() {
    global $dotenv;
    $dotenv->load();

    $headers = apache_request_headers();
    if (!isset($headers['Authorization'])) {
        http_response_code(401);
        echo json_encode(['message' => 'No authorization header found']);
        exit();
    }

    $authToken = str_replace('Bearer ', '', $headers['Authorization']);

    // Split the JWT token to extract the payload
    $tokenParts = explode('.', $authToken);
    if (count($tokenParts) !== 3) {
        http_response_code(401);
        echo json_encode(['message' => 'Invalid token']);
        exit();
    }

    $payload = json_decode(base64_decode($tokenParts[1]), true);
    if (!$payload || !isset($payload['version'])) {
        http_response_code(401);
        echo json_encode(['message' => 'Invalid token: missing version']);
        exit();
    }

    $version = $payload['version'];
    $key = $_ENV["JWT_SECRET_KEY_$version"] ?? null;

    if (!$key) {
        http_response_code(401);
        echo json_encode(['message' => 'Secret key not set']);
        exit();
    }

    try {
        // Decode the token with the correct key
        $decoded = JWT::decode($authToken, new Key($key, 'HS256'));
        $decodedData = (array) $decoded->data; // Convert the data object to an array

        // Check if 'userId' is in the decoded payload
        if (!isset($decodedData['userId'])) {
            http_response_code(401);
            echo json_encode(['message' => 'Invalid token: missing userId']);
            exit();
        }

        // Return the userId
        return $decodedData['userId'];
    } catch (\Firebase\JWT\ExpiredException $e) {
        http_response_code(401);
        echo json_encode(['message' => 'Token expired']);
        exit();
    } catch (Exception $e) {
        http_response_code(401);
        echo json_encode(['message' => 'Invalid authorization token']);
        exit();
    }
}
