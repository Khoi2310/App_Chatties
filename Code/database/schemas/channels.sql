-- Channels table
CREATE TABLE IF NOT EXISTS channels (
    channel_id INT PRIMARY KEY AUTO_INCREMENT,
    server_id INT NOT NULL,
    channel_name VARCHAR(100) NOT NULL,
    channel_type ENUM('text', 'voice', 'video') DEFAULT 'text',
    description TEXT,
    is_private BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (server_id) REFERENCES servers(server_id) ON DELETE CASCADE,
    UNIQUE KEY unique_channel (server_id, channel_name),
    INDEX idx_server_id (server_id),
    INDEX idx_channel_type (channel_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Channel members (for private channels)
CREATE TABLE IF NOT EXISTS channel_members (
    member_id INT PRIMARY KEY AUTO_INCREMENT,
    channel_id INT NOT NULL,
    user_id INT NOT NULL,
    can_view BOOLEAN DEFAULT TRUE,
    can_send BOOLEAN DEFAULT TRUE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_channel_member (channel_id, user_id),
    FOREIGN KEY (channel_id) REFERENCES channels(channel_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_channel_id (channel_id),
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
