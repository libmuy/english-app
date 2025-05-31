<?php
require 'cors_header.php';
require 'user/token.php';

// Validate the token
validateToken();

// Function to check if the description file exists and return its content
function getDescriptionContent($episodeId, $sentenceId) {
    $baseDir = __DIR__ . '/resources';
    $fileName = sprintf("%s-desc-%03d.md", $episodeId, $sentenceId);
    $filePath = $baseDir . '/' . $fileName;

    // echo "file name:" . $fileName . "\n";
    // echo "file path:" . $filePath . "\n";

    if (file_exists($filePath)) {
        return file_get_contents($filePath);
    }
    return null;
}

// Function to get a list of all sentence IDs with descriptions
function getAllDescriptionIds($episodeId) {
    $baseDir = dirname(__DIR__ . '/resources/' . $episodeId);
    $files = scandir($baseDir);
    $descriptionIds = [];

    foreach ($files as $file) {
        if (preg_match('/-desc-(\d{3})\.md$/', $file, $matches)) {
            $descriptionIds[] = (int)$matches[1];
        }
    }

    sort($descriptionIds);
    return $descriptionIds;
}

header('Content-Type: application/json');

// Get episode_id and sentence_id from the query parameters
$episodeId = $_GET['episode_id'] ?? null;
$sentenceId = $_GET['sentence_id'] ?? null;

if ($episodeId) {
    if ($sentenceId !== null) {
        // Fetch and return the description for the specific sentence
        $description = getDescriptionContent($episodeId, (int)$sentenceId);
        if ($description) {
            echo json_encode(['description' => $description]);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Description not found']);
        }
    } else {
        // Return the list of sentence IDs with descriptions
        $descriptionIds = getAllDescriptionIds($episodeId);
        echo json_encode(['description_ids' => $descriptionIds]);
    }
} else {
    http_response_code(400);
    echo json_encode(['error' => 'Missing episode_id']);
}
