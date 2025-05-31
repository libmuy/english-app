<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';

$data = ensure_token_method_argument(['favorite_list_id', 'sentence_id', 'fav']);
$userId = $data['user_id'];
$favoriteListId = $data['favorite_list_id'];
$sentenceId = $data['sentence_id'];
$fav = $data['fav'];

function addFav($userId, $favoriteListId, $sentenceId) {
    $query = "INSERT INTO favorite_sentence (user_id, list_id, sentence_id) VALUES (?, ?, ?)";
    [$stmt, $affectedRows] = exec_query($query, "iii", $userId, $favoriteListId, $sentenceId);
    $stmt->close();

    return $affectedRows > 0;
}

function removeFav($userId, $sentenceId) {
    $query = "DELETE FROM favorite_sentence WHERE user_id = ? AND sentence_id = ?";
    [$stmt, $affectedRows] = exec_query($query, "ii", $userId, $sentenceId);
    $stmt->close();

    return $affectedRows > 0;
}

function favExist($userId, $sentenceId) {
    $query = "SELECT sentence_id FROM favorite_sentence WHERE user_id = ? AND sentence_id = ?";
    [$stmt, $result] = exec_query($query, "ii", $userId, $sentenceId);
    $num_rows = $result->num_rows();
    $stmt->close();

    return $num_rows > 0;
}

// Add favorite
if ($fav) {
    if (!addFav($userId, $favoriteListId, $sentenceId)) {
        if (!favExist($userId, $sentenceId)) {
            send_error_response(500, 'Add favorite sentence failed');
        }
    }
// Remove favorite
} else {
    if (!removeFav($userId, $sentenceId)) {
        if (favExist($userId, $sentenceId)) {
            send_error_response(500, 'Remove favorite sentence failed');
        }
    }
}


