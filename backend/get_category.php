<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';

// category_id == NULL is acceptable.
ensure_token_method_argument();

$data = json_decode(file_get_contents('php://input'), true);
$categoryId = $data['category_id'];

if (is_null($categoryId)) {
    $name = "Root Category";
    $description = "";
    $condition = "IS NULL";

    $query = "SELECT id, name, description FROM category_master WHERE parent_id IS NULL";
    [$categoryStmt, $categoryResult] = exec_query($query);
    $query = "SELECT id, name, description, episode_count FROM course_master WHERE category_id IS NULL";
    [$courseStmt, $courseResult] = exec_query($query);
} else {
    $query = "SELECT * FROM category_master WHERE id = ?";
    [$stmt, $result] = exec_query($query, "s", $categoryId);
    $row = $result->fetch_assoc();

    $name = $row['name'];
    $description = $row['description'];
    $stmt->close();

    $query = "SELECT id, name, description FROM category_master WHERE parent_id = ?";
    [$categoryStmt, $categoryResult] = exec_query($query, "i", $categoryId);
    $query = "SELECT id, name, description, episode_count FROM course_master WHERE category_id = ?";
    [$courseStmt, $courseResult] = exec_query($query, "i", $categoryId);
}

$subcategories = [];
while ($row = $categoryResult->fetch_assoc()) {
    $subcategories[] = $row;
}
$categoryStmt->close();

$courses = [];
while ($row = $courseResult->fetch_assoc()) {
    $courses[] = $row;
}
$courseStmt->close();


header('Content-Type: application/json');
echo json_encode( [
    "name" => $name,
    "id" => $categoryId,
    "desc" => $description,
    "subcategories" => $subcategories,
    "courses" => $courses
]);
?>
