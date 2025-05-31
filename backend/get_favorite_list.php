<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';

$data = ensure_token_method_argument();
$userId = $data['user_id'];

$query = "SELECT * FROM favorite_list_master WHERE user_id = ?";
[$stmt, $result] = exec_query($query, "i", $userId);
$favList = [];
while ($row = $result->fetch_assoc()) {
    $favList[] = $row;
}
$stmt->close();

header('Content-Type: application/json');
echo json_encode( $favList);


