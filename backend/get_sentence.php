<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';
require 'common/learning_data.php';

$data = ensure_token_method_argument(['type']);

$type = $data['type'];
$userId = $data['user_id'];
$courseId = $data['course_id'] ?? null;
$episodeId = $data['episode_id'] ?? null;
$favoriteListId = $data['favorite_list_id'] ?? null;
$pageSize = $data['page_size'] ?? null;
$offset = $data['offset'] ?? null;


function returnCompressed($data) {
    $acceptEncoding = $_SERVER['HTTP_ACCEPT_ENCODING'] ?? '';
    $canCompress = strpos($acceptEncoding, 'gzip') !== false;
    
    if ($canCompress) {
        $compressedContent = gzencode($data, 9);

        if ($compressedContent === false) {
            error_log("Failed to compress content");
            send_error_response(500, "Internal Server Error: Unable to compress file.");
        }
    
        header('Content-Encoding: gzip');
        header('Vary: Accept-Encoding');
        header('Content-Length: ' . strlen($compressedContent));
    
        echo $compressedContent;
    } else {
        echo $data;
    }
    exit();
}

function queryRecordCount($query, $paramType, ...$params) {
    [$stmt, $result] = exec_query($query, $paramType, ...$params);
    $count = $result->fetch_row()[0];
    $stmt->close();

    return $count;
}

function querySentences($query, $paramType, ...$params) {
    [$stmt, $result] = exec_query($query, $paramType, ...$params);

    $sentences = [];
    while ($row = $result->fetch_assoc()) {
        $sentences[] = $row;
    }

    $stmt->close();

    return $sentences;
}


function getSentencesByEpisode($userId, $episodeId) {
    $query = "
        SELECT sm.id, sm.episode_id, sm.sentence_idx, sm.start_time, sm.end_time, sm.english, sm.chinese,
        IF(fs.sentence_id IS NOT NULL, 1, 0) AS is_fav, sm.has_description
        FROM sentence_master sm
        LEFT JOIN favorite_sentence fs ON fs.sentence_id = sm.id AND fs.user_id = ?
        WHERE sm.episode_id = ?";

    $sentences = querySentences($query, "ii", $userId, $episodeId);

    return [
        'total_count' => count($sentences),
        'offset' => 0,
        'sentences' => $sentences
    ];
}


function getReviewSentences($userId) {
    $currentDate = get_learn_date();
    $query = "
        SELECT sm.id, sm.episode_id, sm.sentence_idx, sm.start_time, sm.end_time, sm.english, sm.chinese,
        IF(fs.sentence_id IS NOT NULL, 1, 0) AS is_fav, sm.has_description
        FROM sentence_master sm
        LEFT JOIN favorite_sentence fs ON fs.sentence_id = sm.id AND fs.user_id = ?
        LEFT JOIN learning_data ld ON ld.sentence_id = sm.id AND ld.user_id = ? AND ld.flags & 2 = 0
        WHERE ld.learned_date + ld.interval_days <= ?
        ORDER BY sm.episode_id, ld.learned_date ASC";

    $sentences = querySentences($query, "iii", $userId, $userId, $currentDate);

    return [
        'total_count' => count($sentences),
        'offset' => 0,
        'sentences' => $sentences
    ];
}

function getFavoriteSentencesByEpisode($userId, $favoriteListId, $episodeId) {
    global $conn;

    $baseQuery = "SELECT sm.id, sm.episode_id, sm.sentence_idx, sm.start_time, sm.end_time, sm.english, sm.chinese,
                1 AS is_fav, sm.has_description
                FROM favorite_sentence fs
                INNER JOIN sentence_master sm ON fs.sentence_id = sm.id";
    if ($favoriteListId == -1) {
        $query = "$baseQuery WHERE sm.episode_id = ? AND fs.user_id = ?";
        $sentences = querySentences($query, "ii", $episodeId, $userId);
    } else {
        $query = "$baseQuery WHERE fs.list_id = ? AND fs.user_id = ? AND sm.episode_id = ?";
        $sentences = querySentences($query, "iii", $favoriteListId, $userId, $episodeId);
    }

    return [
        'total_count' => count($sentences),
        'offset' => 0,
        'sentences' => $sentences
    ];
}

function getFavoriteSentencesByCourse($userId, $favoriteListId, $courseId, $pageSize, $offset) {
    global $conn;

    $baseQuery = "FROM favorite_sentence fs
                    INNER JOIN sentence_master sm ON fs.sentence_id = sm.id
                    INNER JOIN episode_master em ON sm.episode_id = em.id";
    if ($favoriteListId == -1) {
        $countQuery = "SELECT COUNT(*) as total $baseQuery WHERE em.course_id = ?";
        $totalCount = queryRecordCount($countQuery, "i", $courseId);
        $query = "SELECT sm.id, sm.episode_id, sm.sentence_idx, sm.start_time, sm.end_time, sm.english, sm.chinese,
                  1 AS is_fav, sm.has_description
                  $baseQuery
                  WHERE em.course_id = ? AND fs.user_id = ? 
                  LIMIT ? OFFSET ?";
        $sentences = querySentences($query, "iiii", $courseId, $userId, $pageSize, $offset);
    } else {
        $countQuery = "SELECT COUNT(*) as total 
                        $baseQuery 
                        WHERE fs.list_id = ? AND em.course_id = ? AND fs.user_id = ?";
        $totalCount = queryRecordCount($countQuery, "ii", $favoriteListId, $courseId, $userId);
        $query = "SELECT sm.id, sm.episode_id, sm.sentence_idx, sm.start_time, sm.end_time, sm.english, sm.chinese,
                  1 AS is_fav, sm.has_description
                  $baseQuery
                  WHERE fs.list_id = ? AND em.course_id = ? AND fs.user_id = ?
                  LIMIT ? OFFSET ?";
        $sentences = querySentences($query, "iiii", $favoriteListId, $courseId, $userId, $pageSize, $offset);
    }

    return [
        'total_count' => $totalCount,
        'offset' => $offset,
        'sentences' => $sentences
    ];
}

function getFavoriteSentencesWithoutId($userId, $favoriteListId, $pageSize, $offset) {
    $baseQuery = "SELECT sm.id, sm.episode_id, sm.sentence_idx, sm.start_time, sm.end_time, sm.english, sm.chinese,
                  1 AS is_fav, sm.has_description
                  FROM favorite_sentence fs
                  INNER JOIN sentence_master sm ON fs.sentence_id = sm.id";

    if ($favoriteListId == -1) {
        $countQuery = "SELECT COUNT(*) as total FROM favorite_sentence WHERE user_id = ?";
        $totalCount = queryRecordCount($countQuery, "i", $userId);
        $query = "$baseQuery WHERE fs.user_id = ? LIMIT ? OFFSET ?";
        $sentences = querySentences($query, "iii", $userId, $pageSize, $offset);
    } else {
        $countQuery = "SELECT COUNT(*) as total FROM favorite_sentence WHERE list_id = ? AND user_id = ?";
        $totalCount = queryRecordCount($countQuery, "ii", $favoriteListId, $userId);
        $query = "$baseQuery WHERE fs.list_id = ? AND fs.user_id = ? LIMIT ? OFFSET ?";
        $sentences = querySentences($query, "iiii", $favoriteListId, $userId, $pageSize, $offset);
    }

    return [
        'total_count' => $totalCount,
        'offset' => $offset,
        'sentences' => $sentences
    ];
}

# Function to retrieve favorite sentences based on favorite list ID, course ID, and episode ID
function getFavoriteSentences($userId, $favoriteListId, $courseId, $episodeId, $offset, $pageSize) {
    # episod is specified, get all favorite sentences of this episod
    if ($episodeId !== null) {
        return getFavoriteSentencesByEpisode($userId, $favoriteListId, $episodeId);
    # episode is null, get all favorite sentence of whole course
    } elseif ($courseId !== null) {
        return getFavoriteSentencesByCourse($userId, $favoriteListId, $courseId, $pageSize, $offset);
    # get sepcified favorite list
    } else {
        return getFavoriteSentencesWithoutId($userId, $favoriteListId, $pageSize, $offset);
    }
}

// var_dump($favoriteListId);
// var_dump($episodeId);


switch ($type) {
    case 'favorite':
        $sentences = getFavoriteSentences($userId, $favoriteListId, $courseId, $episodeId, $offset, $pageSize);
        break;
    case 'review':
        $sentences = getReviewSentences($userId);
        break;
    case 'episode':
        $sentences = getSentencesByEpisode($userId, $episodeId);
        break;
    default:
        http_response_code(400);
        echo json_encode(['error' => 'Invalid type']);
        exit();
}

// if ($favoriteListId !== null) {
//     $sentences = getFavoriteSentences($favoriteListId, $userId, $episodeId, $offset, $pageSize);
// } elseif ($episodeId !== null) {
//     $sentences = getSentencesByEpisode($userId, $episodeId);
// } elseif ($courseId !== null) {
//     http_response_code(400);
//     echo json_encode(['error' => 'fetch all sentence of a course is not permited']);
//     exit();
// } else {
//     http_response_code(400);
//     echo json_encode(['error' => 'Missing episode_id, course_id, or favorite_list_id']);
//     exit();
// }

header('Content-Type: application/json');
returnCompressed(json_encode($sentences));
