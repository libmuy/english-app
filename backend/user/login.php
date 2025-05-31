<?php
require '../common/db_config.php';
require '../vendor/autoload.php';
require '../common/validation.php';
require 'token.php';

$data = ensure_method_argument(['user_name', 'password']);

$userId = $data['user_name'];
$password = $data['password'];

if (!validate_user_name($userId)) {
    http_response_code(400);
    echo json_encode(array("error" => "Invalid user ID format"));
    exit;
}

// Fetch the stored nonce and hashed password
$sql = "SELECT id, name, email, password, nonce FROM user WHERE name='$userId'";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
    $user = $result->fetch_assoc();
    $storedNonce = $user['nonce'];
    $storedHashedPassword = $user['password'];

    // Verify the response (nonce + password)
    $expectedResponse = hash('sha256', $storedHashedPassword . $storedNonce);

    if ($expectedResponse === $password) {
        // Generate JWT token
        $jwt = generateToken($user['id']);
        echo json_encode(array("token" => $jwt, "user_name" => $user['name'], "user_id" => (int)$user['id'], "email" => $user['email']));
    } else {
        http_response_code(401);
        echo json_encode(array("error" => "Invalid user ID or password" . "     front:" . $password . "   backend: " . $expectedResponse));
    }
} else {
    http_response_code(401);
    echo json_encode(array("error" => "User not exists"));
}
?>
