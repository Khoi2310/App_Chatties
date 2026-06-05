-- Servers table
CREATE TABLE IF NOT EXISTS servers (
    server_id INT PRIMARY KEY AUTO_INCREMENT,
    server_name VARCHAR(100) NOT NULL,
    description TEXT,
    owner_id INT NOT NULL,
    icon_url VARCHAR(500),
    is_public BOOLEAN DEFAULT TRUE,
    member_count INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (owner_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_owner_id (owner_id),
    INDEX idx_server_name (server_name),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Server members table
CREATE TABLE IF NOT EXISTS server_members (
    member_id INT PRIMARY KEY AUTO_INCREMENT,
    server_id INT NOT NULL,
    user_id INT NOT NULL,
    role ENUM('owner', 'admin', 'moderator', 'member') DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_member (server_id, user_id),
    FOREIGN KEY (server_id) REFERENCES servers(server_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_server_id (server_id),
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
