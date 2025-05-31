<?php
require 'cors_header.php';
require 'vendor/autoload.php';
require 'user/token.php';

// Validate the token
validateToken();

try {
    $data = json_decode(file_get_contents('php://input'), true);
    if (!isset($data['msg'])) {
        throw new Exception('Invalid input data');
    }

    $msg = $data['msg'];
    error_log('Log From App: ' . $msg);
    echo json_encode(['message' => 'Log to server OK']);
} catch (Exception $e) {
    http_response_code(400); // Bad Request
    echo json_encode(['error' => $e->getMessage()]);
}
?>
