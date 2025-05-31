<?php
// Include necessary files
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';

$data = json_decode(file_get_contents('php://input'), true);

// Define the UNIQUE key columns
$uniqueKeys = ['user_id', 'course_id', 'episode_id', 'favorite_list_id'];

try {
    list($whereClause, $whereTypes, $whereParams) = prepareWhereClause($uniqueKeys, $data);
    // If there are fields to update, construct the SET clause
    if (empty($whereClause)) {
        send_error_response(400, 'Not a valid history(no fields specified).');
    }
    $query = "DELETE FROM history WHERE $whereClause";
    [$stmt, $affectedRows] = exec_query($query, $whereTypes, ...$whereParams);
    $stmt->close();

    if ($affectedRows === 0) {
        send_error_response(404, 'History not found.');
    }

} catch (Exception $e) {
    send_error_response(500, 'Internal Server Error: ' . $e->getMessage());
}
