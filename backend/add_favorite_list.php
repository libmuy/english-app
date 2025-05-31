<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';

$data = ensure_token_method_argument(['name']);
$userId = $data['user_id'];
$name = trim($data['name']);

function maxId($userId) {
    $query = "SELECT MAX(id) as max FROM favorite_list_master WHERE user_id = ?";
    [$stmt, $result] = exec_query($query, "i", $userId);
    $row = $result->fetch_assoc();
    $stmt->close();

    return $row['max'];
}

function addFavList($userId, $name, $id) {
    $query = "INSERT INTO favorite_list_master (user_id, name, id) VALUES (?, ?, ?)";
    [$stmt, $affectedRows] = exec_query($query, "isi", $userId, $name, $id);
    $stmt->close();

    return $affectedRows > 0;
}

$newId = maxId($userId) + 1;
if (!addFavList($userId, $name, $newId)) {
    send_error_response(500, 'Add favorite list failed');
}

echo json_encode(['id' => $newId]);




