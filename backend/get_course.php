<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';

$data = ensure_token_method_argument(['course_id']);
$userId = $data['course_id'];

$query = "SELECT id, name, description, episode_count FROM course_master WHERE id = ?";
[$stmt, $result] = exec_query($query, "i", $userId);
$row = $result->fetch_assoc();
$course = [
    'id' => $row['id'],
    'name' => $row['name'],
    'desc' => $row['description'],
    'episode_count' => $row['episode_count'],
];
$stmt->close();

$query = "SELECT id, name, audio_length_sec, sentence_count FROM episode_master WHERE course_id = ?";
[$stmt, $result] = exec_query($query, "i", $userId);
$favList = [];
while ($row = $result->fetch_assoc()) {
    $favList[] = $row;
}
$stmt->close();

$course['episodes'] = $favList;
header('Content-Type: application/json');
echo json_encode( $course);


