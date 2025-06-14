-- -------------------------------------------
-- Select the Target Database
-- -------------------------------------------
USE english_app_new;

-- -------------------------------------------
-- Disable Foreign Key Checks for Cleanup
-- -------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;

-- -------------------------------------------
-- Drop Existing Triggers if They Exist
-- -------------------------------------------
DROP TRIGGER IF EXISTS after_insert_sentence;
DROP TRIGGER IF EXISTS after_delete_sentence;
DROP TRIGGER IF EXISTS after_insert_favorite_sentence;
DROP TRIGGER IF EXISTS after_delete_favorite_sentence;
DROP TRIGGER IF EXISTS after_insert_episode_master;
DROP TRIGGER IF EXISTS after_delete_episode_master;

-- -------------------------------------------
-- Drop Existing Tables if They Exist
-- -------------------------------------------
DROP TABLE IF EXISTS learning_data;
DROP TABLE IF EXISTS setting;
DROP TABLE IF EXISTS favorite_resource;
DROP TABLE IF EXISTS favorite_sentence;
DROP TABLE IF EXISTS history;
DROP TABLE IF EXISTS favorite_list_master;
DROP TABLE IF EXISTS sentence_master;
DROP TABLE IF EXISTS episode_master;
DROP TABLE IF EXISTS course_master;
DROP TABLE IF EXISTS category_master;
DROP TABLE IF EXISTS user; -- Renamed from 'user'

-- -------------------------------------------
-- Re-enable Foreign Key Checks
-- -------------------------------------------
SET FOREIGN_KEY_CHECKS = 1;

-- -------------------------------------------
-- Create user Table
-- -------------------------------------------
CREATE TABLE user (
    id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(32) NOT NULL UNIQUE,
    password VARCHAR(64) NOT NULL,
    email VARCHAR(64) NOT NULL UNIQUE,
    nonce VARCHAR(32) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------
-- Create Category Master Table
-- -------------------------------------------
CREATE TABLE category_master (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    path VARCHAR(255) UNIQUE NOT NULL,
    parent_id INT UNSIGNED DEFAULT NULL,
    name VARCHAR(64) NOT NULL,
    description VARCHAR(1024),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES category_master(id) ON DELETE CASCADE,
    INDEX idx_parent_id (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------
-- Create Course Master Table
-- -------------------------------------------
CREATE TABLE course_master (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    path VARCHAR(512) UNIQUE NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    name VARCHAR(64) NOT NULL,
    description VARCHAR(1024),
    episode_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES category_master(id) ON DELETE CASCADE,
    INDEX idx_category_id (category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------
-- Create Episode Master Table
-- -------------------------------------------
CREATE TABLE episode_master (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    course_id INT UNSIGNED NOT NULL,
    name VARCHAR(64) NOT NULL,
    path VARCHAR(512) UNIQUE NOT NULL,
    audio_length_sec SMALLINT UNSIGNED DEFAULT NULL,
    sentence_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (course_id) REFERENCES course_master(id) ON DELETE CASCADE,
    INDEX idx_course_id (course_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------
-- Create Sentence Master Table
-- -------------------------------------------
CREATE TABLE sentence_master (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    episode_id INT UNSIGNED NOT NULL,
    sentence_idx SMALLINT UNSIGNED NOT NULL,
    start_time INT NOT NULL,
    end_time INT NOT NULL,
    has_description BOOLEAN,
    english VARCHAR(512) NOT NULL,
    chinese VARCHAR(512) NOT NULL,
    UNIQUE (episode_id, sentence_idx),
    FOREIGN KEY (episode_id) REFERENCES episode_master(id) ON DELETE CASCADE,
    INDEX idx_episode_id (episode_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------
-- Create Favorite Resource Table
-- -------------------------------------------
CREATE TABLE favorite_resource (
    user_id SMALLINT UNSIGNED NOT NULL,
    type ENUM('category', 'course', 'episode') NOT NULL,
    id INT UNSIGNED NOT NULL,
    UNIQUE (user_id, type, id),
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE,
    INDEX idx_type_id (type, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------
-- Create Favorite List Master Table
-- -------------------------------------------
CREATE TABLE favorite_list_master (
    user_id SMALLINT UNSIGNED NOT NULL,
    id TINYINT UNSIGNED,
    name VARCHAR(64) NOT NULL,
    sentence_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, id),
    UNIQUE (user_id, name),
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------
-- Create Favorite Sentence Table
-- -------------------------------------------
CREATE TABLE favorite_sentence (
    user_id SMALLINT UNSIGNED NOT NULL,
    list_id TINYINT UNSIGNED NOT NULL,
    sentence_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id, list_id, sentence_id),
    FOREIGN KEY (user_id, list_id) REFERENCES favorite_list_master(user_id, id) ON DELETE CASCADE,
    FOREIGN KEY (sentence_id) REFERENCES sentence_master(id) ON DELETE CASCADE,
    INDEX idx_sentence_id (sentence_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------
-- Create History Table
-- -------------------------------------------
CREATE TABLE history (
    user_id SMALLINT UNSIGNED NOT NULL,
    course_id INT UNSIGNED DEFAULT NULL,
    episode_id INT UNSIGNED DEFAULT NULL,
    favorite_list_id TINYINT UNSIGNED DEFAULT NULL,
    audio_length_sec SMALLINT UNSIGNED DEFAULT NULL,
    sentence_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    title VARCHAR(64) NOT NULL,
    last_sentence_id INT UNSIGNED NOT NULL,
    last_learned TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE (user_id, course_id, episode_id, favorite_list_id),
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE,
    FOREIGN KEY (course_id) REFERENCES course_master(id) ON DELETE CASCADE,
    FOREIGN KEY (episode_id) REFERENCES episode_master(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id, favorite_list_id) REFERENCES favorite_list_master(user_id, id) ON DELETE CASCADE,
    FOREIGN KEY (last_sentence_id) REFERENCES sentence_master(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------
-- Create Setting Table
-- -------------------------------------------
CREATE TABLE setting (
    user_id SMALLINT UNSIGNED PRIMARY KEY,
    theme ENUM('light', 'dark', 'system') DEFAULT 'system',
    theme_color INT UNSIGNED NOT NULL,
    font_size TINYINT UNSIGNED NOT NULL,
    flags TINYINT UNSIGNED NOT NULL,
    playback_times SMALLINT UNSIGNED DEFAULT 1,
    playback_interval SMALLINT UNSIGNED DEFAULT 5,
    playback_speed DECIMAL(3,1) DEFAULT 1.0,
    default_favorite_list TINYINT UNSIGNED,
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------
-- Create Learning Data Table
-- -------------------------------------------
CREATE TABLE learning_data (
    user_id SMALLINT UNSIGNED NOT NULL,
    sentence_id INT UNSIGNED NOT NULL,
    interval_days SMALLINT UNSIGNED NOT NULL,
    learned_date SMALLINT UNSIGNED NOT NULL,
    ease_factor TINYINT UNSIGNED NOT NULL,
    flags BIT(2) NOT NULL,            -- 1st bit: is_graduated, 2nd bit: is_skipped
    PRIMARY KEY (user_id, sentence_id),
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE,
    FOREIGN KEY (sentence_id) REFERENCES sentence_master(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE learning_history (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id SMALLINT UNSIGNED NOT NULL,
    sentence_id INT UNSIGNED NOT NULL,
    learned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_learned_at (user_id, learned_at),
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE,
    FOREIGN KEY (sentence_id) REFERENCES sentence_master(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------
-- Create Triggers for Auto-Maintaining Counters
-- -------------------------------------------

DELIMITER //

-- Trigger for sentence_master: Increment sentence_count in episode_master
CREATE TRIGGER after_insert_sentence
AFTER INSERT ON sentence_master
FOR EACH ROW
BEGIN
  UPDATE episode_master
  SET sentence_count = sentence_count + 1
  WHERE id = NEW.episode_id;
END//

-- Trigger for sentence_master: Decrement sentence_count in episode_master
CREATE TRIGGER after_delete_sentence
AFTER DELETE ON sentence_master
FOR EACH ROW
BEGIN
  UPDATE episode_master
  SET sentence_count = GREATEST(sentence_count - 1, 0) -- Prevent negative counts
  WHERE id = OLD.episode_id;
END//

-- Trigger for favorite_sentence: Increment sentence_count in favorite_list_master
CREATE TRIGGER after_insert_favorite_sentence
AFTER INSERT ON favorite_sentence
FOR EACH ROW
BEGIN
  UPDATE favorite_list_master
  SET sentence_count = sentence_count + 1
  WHERE user_id = NEW.user_id AND id = NEW.list_id;
END//

-- Trigger for favorite_sentence: Decrement sentence_count in favorite_list_master
CREATE TRIGGER after_delete_favorite_sentence
AFTER DELETE ON favorite_sentence
FOR EACH ROW
BEGIN
  UPDATE favorite_list_master
  SET sentence_count = GREATEST(sentence_count - 1, 0) -- Prevent negative counts
  WHERE user_id = OLD.user_id AND id = OLD.list_id;
END//

-- Trigger for episode_master: Increment episode_count in course_master
CREATE TRIGGER after_insert_episode_master
AFTER INSERT ON episode_master
FOR EACH ROW
BEGIN
  UPDATE course_master
  SET episode_count = episode_count + 1
  WHERE id = NEW.course_id;
END//

-- Trigger for episode_master: Decrement episode_count in course_master
CREATE TRIGGER after_delete_episode_master
AFTER DELETE ON episode_master
FOR EACH ROW
BEGIN
  UPDATE course_master
  SET episode_count = GREATEST(episode_count - 1, 0) -- Prevent negative counts
  WHERE id = OLD.course_id;
END//

DELIMITER ;
