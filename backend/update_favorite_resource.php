<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';

$data = ensure_token_method_argument(['resource_type', 'resource_id', 'fav']);
$userId = $data['user_id'];
$resourceType = $data['resource_type'];
$resourceId = $data['resource_id'];
$fav = $data['fav'];

function addFav($userId, $resourceType, $resourceId) {
    $query = "INSERT INTO favorite_resource (user_id, type, id) VALUES (?, ?, ?)";
    [$stmt, $affectedRows] = exec_query($query, "isi", $userId, $resourceType, $resourceId);
    $stmt->close();

    return $affectedRows > 0;
}

function removeFav($userId, $resourceType, $resourceId) {
    $query = "DELETE FROM favorite_resource WHERE user_id = ? AND type = ? AND id = ?";
    [$stmt, $affectedRows] = exec_query($query, "isi", $userId, $resourceType, $resourceId);
    $stmt->close();

    return $affectedRows > 0;
}

function favExist($userId, $resourceType, $resourceId) {
    $query = "SELECT sentence_id FROM favorite_resource WHERE user_id = ? AND type = ? AND id = ?";
    [$stmt, $result] = exec_query($query, "isi", $userId, $resourceType, $resourceId);
    $num_rows = $result->num_rows();
    $stmt->close();

    return $num_rows > 0;
}

// Add favorite
if ($fav) {
    if (!addFav($userId, $resourceType, $resourceId)) {
        if (!favExist($userId, $resourceType, $resourceId)) {
            send_error_response(500, 'Add favorite resource failed');
        }
    }
// Remove favorite
} else {
    if (!removeFav($userId, $resourceType, $resourceId)) {
        if (favExist($userId, $resourceType, $resourceId)) {
            send_error_response(500, 'Remove favorite resource failed');
        }
    }
}


