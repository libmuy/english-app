<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';

$data = ensure_token_method_argument();
$userId = $data['user_id'];

$query = "SELECT course_id, episode_id, favorite_list_id, audio_length_sec, sentence_count, title, last_sentence_id, last_learned
    FROM history 
    WHERE user_id = ? 
    ORDER BY last_learned";

[$stmt, $result] = exec_query($query, "i", $userId);
$history = [];
while ($row = $result->fetch_assoc()) {
    $history[] = $row;
}

$stmt->close();
header('Content-Type: application/json');
if (empty($history)) {
    echo json_encode( []);
} else {
    echo json_encode( $history);
}
