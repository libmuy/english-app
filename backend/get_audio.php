<?php
require_once 'common/db_config.php';
require_once 'user/token.php';
require_once 'common/validation.php';
require_once 'vendor/autoload.php';

// Ensure the request method and token, and validate input parameters
$data = ensure_token_method_argument(['episode_id']);
$episodeId = $data['episode_id'];

// Validate that episode_id is an integer
if (!filter_var($episodeId, FILTER_VALIDATE_INT)) {
    send_error_response(400, "Invalid episode ID.");
}

// Database query to fetch the file path
$query = "SELECT path FROM episode_master WHERE id = ?";
[$stmt, $result] = exec_query($query, "i", $episodeId);

if (!$stmt || !$result) {
    error_log("Database query failed for episode_id: " . $episodeId);
    send_error_response(500, "Internal Server Error: Database query failed.");
}

if ($row = $result->fetch_assoc()) {
    $filePath = __DIR__ . '/../app-resource/' . trim($row['path']) . '.mp3';
} else {
    send_error_response(404, "Episode not found.");
}

$stmt->close();

// Log the file path (ensure not to expose sensitive info in production)
error_log("Fetching resource: " . $filePath);

// Check if the file exists and is a regular file
if (!is_file($filePath)) {
    send_error_response(404, "File not found: $filePath");
}

// Determine the MIME type
$mimeType = mime_content_type($filePath) ?: 'application/octet-stream';
header('Content-Type: ' . $mimeType);
header('X-Content-Type-Options: nosniff');

// Optional: Set caching headers
header('Cache-Control: public, max-age=604800'); // Cache for 1 week

// Get the size of the file
$fileSize = filesize($filePath);
if ($fileSize === false) {
    error_log("Failed to get file size for: " . $filePath);
    send_error_response(500, "Internal Server Error: Unable to retrieve file size.");
}

header('Content-Length: ' . $fileSize);
header('Content-Disposition: inline; filename="' . basename($filePath) . '"');

// Stream the file to handle large files efficiently
$fileHandle = fopen($filePath, 'rb');
if ($fileHandle === false) {
    error_log("Failed to open file: " . $filePath);
    send_error_response(500, "Internal Server Error: Unable to open file.");
}

// Stream the file in chunks
while (!feof($fileHandle)) {
    echo fread($fileHandle, 1024 * 8); // 8KB chunks
    flush(); // Ensure immediate output
}

fclose($fileHandle);
?>
