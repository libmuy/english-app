<?php
require '../common/db_config.php';
require '../common/validation.php';

$data = ensure_method_argument(['user_name']);

$userId = $data['user_name'];

if (!validate_user_name($userId)) {
    http_response_code(400);
    echo json_encode(array("error" => "Invalid user ID format"));
    exit;
}

// Generate a new nonce
$nonce = bin2hex(random_bytes(16));

// Prepare the SQL statement
$updateSql = "UPDATE user SET nonce='$nonce' WHERE name='$userId'";

// Execute the SQL query
if ($conn->query($updateSql) === TRUE) {
    // Check if any rows were actually affected (i.e., if the user exists)
    if ($conn->affected_rows > 0) {
        // If the update was successful and a row was affected
        echo json_encode(array("nonce" => $nonce));
    } else {
        // No rows were affected, meaning the user doesn't exist
        http_response_code(404);
        echo json_encode(array("error" => "User not found"));
    }
} else {
    // SQL execution failed
    http_response_code(500);
    echo json_encode(array("error" => "Failed to generate nonce"));
}