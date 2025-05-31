<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';
require 'common/learning_data.php';

$keys = ['sentence_id', 'review_result'];
$data = ensure_token_method_argument($keys);
$userId = $data['user_id'];
$sentenceId = $data['sentence_id'];
$reviewResult = $data['review_result'];

if (!in_array($reviewResult, ['skip', 'again', 'hard', 'good', 'easy'])) {
    send_error_response(400, 'Invalid review result');
}

$currentData = get_learning_data($userId, $sentenceId);
if (!$currentData) {
    $currentData = default_learning_data($userId, $sentenceId);
    set_learning_data($currentData);
    exit();
}

if ($reviewResult == 'skip') {
    $currentData['is_skipped'] = 1;
    $currentData['learned_date'] = get_learn_date();
    set_learning_data($currentData);
    exit();
}

$easeFactor = $currentData['ease_factor'];
$intervalDays = $currentData['interval_days'];
$isGraduated = $currentData['is_graduated'];
$learnedDate = $currentData['learned_date'];

// Review algorithm logic
$minEaseFactor = 1.3;
$maxEaseFactor = 2.5;
$maxIntervalDays = 365;
$initialIntervals = [1, 3, 7];
$graduatedInterval = 14;

if (!$isGraduated) {
    if ($reviewResult == 'again') {
        $intervalDays = $initialIntervals[0];
    } else {
        $currentIndex = array_search($intervalDays, $initialIntervals);
        if ($currentIndex !== false && $currentIndex < count($initialIntervals) - 1) {
            $intervalDays = $initialIntervals[$currentIndex + 1];
        } else {
            $isGraduated = true;
            $intervalDays = $graduatedInterval;
        }
    }
} else {
    switch ($reviewResult) {
        case 'again':
            $intervalDays = 1;
            $easeFactor = max($minEaseFactor, $easeFactor - 0.2);
            break;
        case 'hard':
            $intervalDays = max(1, $intervalDays * 0.8);
            $easeFactor = max($minEaseFactor, $easeFactor - 0.15);
            break;
        case 'good':
            $intervalDays = min($maxIntervalDays, $intervalDays * $easeFactor);
            break;
        case 'easy':
            $intervalDays = min($maxIntervalDays, $intervalDays * $easeFactor * 1.3);
            $easeFactor = min($maxEaseFactor, $easeFactor + 0.15);
            break;
    }
}

$flags = $isGraduated ? 1 : 0;

// Handle late reviews
$currentDate = get_learn_date();
$daysLate = $currentDate - $learnedDate - $intervalDays;
if ($daysLate > 4) {
    $newIntervalDays = round($intervalDays - $daysLate / 4);
    $limit = round($intervalDays / 3);
    $intervalDays = max($limit, $newIntervalDays);
}

// Apply interval randomization
$randomFactor = 1 + (mt_rand() / mt_getrandmax() * 0.1 - 0.05);
$intervalDays = round($intervalDays * $randomFactor);

// Ensure interval does not exceed maximum
$intervalDays = max(1, min($intervalDays, $maxIntervalDays));

// // Leech management
// // Assuming failureCount is stored in the database
// $failureCount = $currentData['failure_count'] ?? 0;
// if ($failureCount >= 5) {
//     // Mark for extra attention or removal
//     // This can be implemented as needed
// }

$currentData['interval_days'] = $intervalDays;
$currentData['learned_date'] = get_learn_date();
$currentData['ease_factor'] = $easeFactor;
$currentData['is_graduated'] = $isGraduated;

set_learning_data($currentData);
