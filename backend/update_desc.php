<?php
require 'common/db_config.php';
require 'common/validation.php';
require 'user/token.php';

$repo_dir="/var/www/html/english.libmuy.com/app-gh-pages/desc";
$commit_script = __DIR__ . '/update_desc.sh';

// Get input data
$data = ensure_token_method_argument(['sentence_id', 'desc']);
$userId = $data['user_id'];
$sentenceId = $data['sentence_id'];
$desc = $data['desc'];
$filename = "$sentenceId.md";

// Save description to file
save2file("$repo_dir/$filename", $desc);

// Commit description to git
$escapedFilename = escapeshellarg("$filename");
$output = shell_exec("$commit_script $escapedFilename");
if ($output === null) {
    send_error_response(500, 'Failed to execute shell script');
}


// Update database
updateSentenceMaster($sentenceId);

function save2file($path, $content) {
    $fp = fopen($path, 'w');
    if ($fp) {
        fwrite($fp, $content);
        fclose($fp);
    } else {
        send_error_response(500, 'Failed to save file');
    }
}



function updateSentenceMaster($sentenceId) {
    $query = "UPDATE sentence_master SET has_description = 1 WHERE id = ?";
    [$stmt, $affectedRows] = exec_query($query, "i", $sentenceId);
    $stmt->close();
}
