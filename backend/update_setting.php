<?php
require 'common/db_config.php';
require 'user/token.php';
require 'common/validation.php';


// Define the allowed columns that can be updated
$allowed_columns = [
    'theme',
    'theme_color',
    'font_size',
    'flags',
    'playback_times',
    'playback_interval',
    'playback_speed',
    'default_favorite_list'
];

// Function to validate column names
function validate_columns($input_keys, $allowed_columns) {
    $invalid_keys = array_diff($input_keys, $allowed_columns);
    return $invalid_keys;
}

function exist_in_db($user_id) {
    $check_query = "SELECT user_id FROM setting WHERE user_id = ?";
    [$check_stmt, $check_result] = exec_query($check_query, "i", $user_id);
    $ret = $check_result->num_rows > 0;
    $check_stmt->close();
    return $ret;
}

// Function to validate data types (you can expand this based on your requirements)
function validate_data_types($data) {
    $errors = [];

    foreach ($data as $key => $value) {
        switch ($key) {
            case 'theme':
                if (!in_array($value, ['light', 'dark', 'system'])) {
                    $errors[] = "Invalid value for theme. Allowed values: light, dark, system.";
                }
                break;
            case 'theme_color':
                if (!preg_match('/^[0-9]+$/', $value)) {
                    $errors[] = "Invalid format for theme_color. Expected integer value.";
                }
                break;
            case 'font_size':
            case 'flags':
            case 'playback_times':
            case 'playback_interval':
                if (!is_int($value) || $value < 0) {
                    $errors[] = "$key must be a non-negative integer.";
                }
                break;
            case 'playback_speed':
                if (!is_numeric($value) || $value < 0.1 || $value > 5.0) { // Example range
                    $errors[] = "playback_speed must be a number between 0.1 and 5.0.";
                }
                break;
            default:
                // No validation for unspecified keys
                break;
        }
    }

    return $errors;
}

// Set the response header to JSON
header('Content-Type: application/json');
// Ensure the request method is POST and required parameters are present
ensure_method();
$user_id = ensure_token();
$data = ensure_method_argument([]);
$add = $data['add'] ?? false;
unset($data['add']);
log2file($data['playback_times']);

if (empty($data)) {
    send_error_response(400, 'No input data provided.');
}

if ($add && exist_in_db($user_id)) {
    send_error_response(400, 'data already exists in DB.');
}


// Validate that the input keys are allowed
$input_keys = array_keys($data);
$invalid_keys = validate_columns($input_keys, $allowed_columns);

if (!empty($invalid_keys)) {
    send_error_response(400, 'Invalid parameter(s): ' . implode(', ', $invalid_keys));
}

// Validate data types and constraints
$data_type_errors = validate_data_types($data);
if (!empty($data_type_errors)) {
    send_error_response(400, $data_type_errors);
}

// Build the SET part of the SQL statement dynamically
$set_clauses = [];
$params = [];
$types = '';

foreach ($data as $key => $value) {
    $set_clauses[] = "`$key` = ?";
    $insert_clauses[] = "`$key`";
    $insert_value_clauses[] = "?";
    // Determine the type based on the column
    switch ($key) {
        case 'theme':
            $types .= 's';
            $params[] = $value;
            break;
        case 'font_size':
        case 'playback_times':
        case 'playback_interval':
        case 'theme_color':
        case 'default_favorite_list':
        case 'flags':
            $types .= 'i';
            $params[] = $value;
            break;
        case 'playback_speed':
            $types .= 'd';
            $params[] = $value;
            break;
        default:
            break;
    }
}

// If there are no fields to update, return an error
if (empty($set_clauses)) {
    send_error_response(400, 'No valid fields provided for update.');
}
// Append the user_id for the WHERE clause
$types .= 'i'; // Assuming user_id is stored as SMALLINT UNSIGNED (integer)
$params[] = $user_id;

// insert a new record
if ($add) {
    $insert_clauses[] = 'user_id';
    $insert_value_clauses[] = '?';
    $insert_statement = implode(', ', $insert_clauses);
    $values_statement = implode(', ', $insert_value_clauses);
    $query = "INSERT INTO setting ($insert_statement) VALUES ($values_statement)";

// update a existing record
} else {
    // Construct the final SQL query
    $set_statement = implode(', ', $set_clauses);
    $query = "UPDATE setting SET $set_statement WHERE user_id = ?";
}


// Execute the update query
[$stmt, $affected_rows] = exec_query($query, $types, ...$params);
$stmt->close();

log2file("affected_rows: $affected_rows" . ", query: $query");

// Check if the update was successful
if ($affected_rows <= 0 && !exist_in_db($user_id)) {
    send_error_response(404, 'User settings not found.');
}


