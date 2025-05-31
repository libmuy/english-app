<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';

$data = ensure_token_method_argument();
$userId = $data['user_id'];
// reduces the number of database queries from 3 to 1, 
// potentially improving performance by minimizing round trips to the database
$query = "
SELECT 
    fr.type,
    COALESCE(cm.id, cr.id, em.id) AS id,
    COALESCE(cm.name, cr.name, em.name) AS name,
    COALESCE(cm.description, cr.description) AS description,
    em.audio_length_sec,
    COALESCE(cr.episode_count, em.sentence_count) AS sub_count
FROM 
    favorite_resource fr
LEFT JOIN 
    category_master cm ON fr.id = cm.id AND fr.type = 'category'
LEFT JOIN 
    course_master cr ON fr.id = cr.id AND fr.type = 'course'
LEFT JOIN 
    episode_master em ON fr.id = em.id AND fr.type = 'episod'
WHERE 
    fr.user_id = ?
";

[$stmt, $result] = exec_query($query, "s", $userId);

// Initialize empty arrays for categories, courses, and episodes
$history = [];
$courses = [];
$favList = [];

while ($row = $result->fetch_assoc()) {
    switch ($row['type']) {
        case 'category':
            $history[] = [
                'id' => $row['id'],
                'name' => $row['name'],
                'desc' => $row['description']
            ];
            break;
        case 'course':
            $courses[] = [
                'id' => $row['id'],
                'name' => $row['name'],
                'desc' => $row['description'],
                'episode_count' => $row['sub_count']
            ];
            break;
        case 'episod':
            $favList[] = [
                'id' => $row['id'],
                'name' => $row['name'],
                'audio_length_sec' => $row['audio_length_sec'],
                'sentence_count' => $row['sub_count']
            ];
            break;
    }
}

$stmt->close();

// Return the JSON response
header('Content-Type: application/json');
echo json_encode([
    'category' => $history,
    'course' => $courses,
    'episode' => $favList
]);
?>
