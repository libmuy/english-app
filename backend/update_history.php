<?php
// Include necessary files
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';

function historyExists($data)
{
    $uniqueKeys = ['user_id', 'course_id', 'episode_id', 'favorite_list_id'];
    list($whereClause, $whereTypes, $whereParams) = prepareWhereClause($uniqueKeys, $data);

    $query = "SELECT 1 FROM `history` WHERE $whereClause";
    [$stmt, $result] = exec_query($query, $whereTypes, ...$whereParams);
    $stmt->close();

    return $result->num_rows > 0;
}

function updateHistory($data, $userId)
{
    $uniqueKeys = ['user_id', 'course_id', 'episode_id', 'favorite_list_id'];
    list($whereClause, $whereTypes, $whereParams) = prepareWhereClause($uniqueKeys, $data);

    $updateFields = [
        'audio_length_sec',
        'sentence_count',
        'title',
        'last_sentence_id'
        // 'last_learned' is managed by MySQL automatically
    ];

    $updateSetClauses = [];
    $updateParams = [];
    $updateTypes = '';

    foreach ($updateFields as $field) {
        if (isset($data[$field])) {
            $updateSetClauses[] = "`$field` = COALESCE(?, `$field`)";
            $updateParams[] = $data[$field];
            // Determine the type
            if ($field === 'title') {
                $updateTypes .= 's';
            } else {
                $updateTypes .= 'i';
            }
        }
    }

    // If there are fields to update, construct the SET clause
    if (!empty($updateSetClauses)) {
        $updateSet = implode(', ', $updateSetClauses);
    } else {
        send_error_response(400, 'Not a valid history (no fields specified).');
    }

    $updateQuery = "UPDATE `history` SET $updateSet WHERE $whereClause";

    // Combine types and parameters for the UPDATE statement
    $fullUpdateTypes = $updateTypes . $whereTypes;
    $fullUpdateParams = array_merge($updateParams, $whereParams);

    // Step 6: Execute the UPDATE statement using exec_query()
    [$stmtUpdate, $affectedRows] = exec_query($updateQuery, $fullUpdateTypes, ...$fullUpdateParams);
    $stmtUpdate->close();
}


function insertHistory($data, $userId)
{
    // Define all possible columns in the history table
    $allKeys = [
        'user_id',
        'course_id',
        'episode_id',
        'favorite_list_id',
        'audio_length_sec',
        'sentence_count',
        'title',
        'last_sentence_id',
        // 'last_learned' // Excluded to let MySQL handle it automatically
    ];
    $insertColumns = [];
    $insertPlaceholders = [];
    $insertParams = [];
    $insertTypes = '';

    foreach ($allKeys as $key) {
        if (isset($data[$key])) {
            $insertColumns[] = "`$key`";
            $insertPlaceholders[] = "?";
            $insertParams[] = $data[$key];
            // Determine the type
            if ($key === 'title') {
                $insertTypes .= 's';
            } else {
                $insertTypes .= 'i';
            }
        }
    }

    // Construct the INSERT statement
    $insertColumnsStr = implode(', ', $insertColumns);
    $insertPlaceholdersStr = implode(', ', $insertPlaceholders);
    $insertQuery = "INSERT INTO `history` ($insertColumnsStr) VALUES ($insertPlaceholdersStr)";

    // Execute the INSERT statement using exec_query()
    [$stmtInsert, $insertedRows] = exec_query($insertQuery, $insertTypes, ...$insertParams);
    $stmtInsert->close();

    if ($insertedRows > 0) {
        log2file("Inserted new history record for user_id: $userId");
    } else {
        throw new Exception("Failed to insert new history record.");
    }

}

$data = ensure_token_method_argument(['last_learned', 'last_sentence_id']);
$userId = $data['user_id'];
try {
    if (historyExists($data)) {
        updateHistory($data, $userId);
    } else {
        insertHistory($data, $userId);
    }

    echo json_encode(['success' => true, 'message' => 'History upserted successfully.']);

} catch (Exception $e) {
    send_error_response(500, 'Internal Server Error: ' . $e->getMessage());
}
