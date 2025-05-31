<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php'; // For send_error_response and other utilities
require 'common/learning_data.php'; // For get_learn_date and potentially date calculations

// Authenticate the user and get user_id
$data = ensure_token_method_argument();
$userId = $data['user_id'];

// Prepare the SQL query
// The learned_date in the database is an integer representing days since 2024-01-01.
// We need to convert this back to a YYYY-MM-DD string.
// MySQL's DATE_ADD function can be used: DATE_ADD('2024-01-01', INTERVAL learned_date DAY)
$query = "SELECT
            DATE_FORMAT(DATE_ADD('2024-01-01', INTERVAL ld.learned_date DAY), '%Y-%m-%d') AS date,
            COUNT(*) AS sentence_count
          FROM learning_data ld
          WHERE ld.user_id = ?
          GROUP BY ld.learned_date
          ORDER BY ld.learned_date ASC";

[$stmt, $result] = exec_query($query, "i", $userId);

$summary = [];
while ($row = $result->fetch_assoc()) {
    // Ensure sentence_count is an integer
    $row['sentence_count'] = (int)$row['sentence_count'];
    $summary[] = $row;
}

$stmt->close();
$conn->close();

header('Content-Type: application/json');
echo json_encode($summary);

?>
