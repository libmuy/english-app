<?php
require __DIR__ . '/redis_config.php';

function learning_data_cache_key($userId, $sentenceId)
{
    return "learning_data:user:$userId:sentence:$sentenceId";
}


function get_learning_data_from_cache($userId, $sentenceId)
{
    global $redis;
    // Generate a unique cache key
    $cacheKey = learning_data_cache_key($userId, $sentenceId);

    // Check if data is in Redis cache
    if ($redis->exists($cacheKey)) {
        return json_decode($redis->get($cacheKey), true);
    }

    return false;
}


function set_learning_data_to_cache($data)
{
    global $redis;
    // Generate a unique cache key
    $cacheKey = learning_data_cache_key($data['user_id'], $data['sentence_id']);
    $redis->set($cacheKey, json_encode($data));
}


function get_learning_data($userId, $sentenceId)
{
    $data = get_learning_data_from_cache($userId, $sentenceId);
    if ($data) return $data;
    
    $query = "SELECT user_id, sentence_id, interval_days, learned_date, ease_factor / 100.0 as ease_factor, (flags & 1 > 0) as is_graduated, (flags & 2 > 0) as is_skipped
            FROM `learning_data` 
            WHERE user_id = ? AND sentence_id = ?";
    [$stmt, $result] = exec_query($query, "ii", $userId, $sentenceId);
    if ($row = $result->fetch_assoc()) {
        set_learning_data_to_cache($row);
    }
    $stmt->close();

    return $row;
}

function set_learning_data($data) {
    $userId = $data['user_id'];
    $sentenceId = $data['sentence_id'];
    $intervalDays = $data['interval_days'];
    $learnedDate = $data['learned_date'];
    $easeFactor = (int)($data['ease_factor'] * 100);
    $isGradurated = $data['is_graduated'] ? 1 : 0;
    $isSkipped = $data['is_skipped'] ? 1 : 0;
    $flags = $isGradurated + $isSkipped * 2;


    // Upsert the learning data
    $upsertQuery = "INSERT INTO `learning_data` (user_id, sentence_id, interval_days, learned_date, ease_factor, flags)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE
                    interval_days = VALUES(interval_days),
                    learned_date = VALUES(learned_date),
                    ease_factor = VALUES(ease_factor),
                    flags = VALUES(flags)";
    [$stmt, $affectedRows] = exec_query($upsertQuery, "iiiiii", $userId, $sentenceId, $intervalDays, $learnedDate, $easeFactor, $flags);
    $stmt->close();
    if ($affectedRows > 0) {
        set_learning_data_to_cache($data);
    }

    return $affectedRows > 0;
}

function default_learning_data($userId, $sentenceId) {
    return [
        'user_id' => $userId,
        'sentence_id' => $sentenceId,
        'interval_days' => 1,
        'learned_date' => get_learn_date(),
        'ease_factor' => 2.5,
        'is_graduated' => false,
        'is_skipped' => false
    ];
}


function get_learn_date($dateStr = "now") {
    $timezone = new DateTimeZone('Asia/Tokyo');
    $baseDate = new DateTime('2024-01-01', $timezone);
    $date = new DateTime($dateStr, $timezone);
    $interval = $baseDate->diff($date);

    return $interval->days;
}

