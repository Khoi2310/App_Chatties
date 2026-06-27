-- Permissions table
CREATE TABLE IF NOT EXISTS permissions (
    permission_id INT PRIMARY KEY AUTO_INCREMENT,
    role VARCHAR(50) NOT NULL,
    permission_name VARCHAR(100) NOT NULL,
    can_perform BOOLEAN DEFAULT TRUE,
    
    UNIQUE KEY unique_role_permission (role, permission_name),
    INDEX idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Predefined permissions
INSERT INTO permissions (role, permission_name, can_perform) VALUES
-- Owner permissions
('owner', 'delete_server', TRUE),
('owner', 'manage_roles', TRUE),
('owner', 'manage_channels', TRUE),
('owner', 'manage_members', TRUE),

-- Admin permissions
('admin', 'manage_channels', TRUE),
('admin', 'manage_members', TRUE),
('admin', 'delete_messages', TRUE),
('admin', 'mute_users', TRUE),

-- Moderator permissions
('moderator', 'delete_messages', TRUE),
('moderator', 'mute_users', TRUE),
('moderator', 'manage_channels', FALSE),

-- Member permissions
('member', 'send_messages', TRUE),
('member', 'send_voice', TRUE),
('member', 'send_video', TRUE),
('member', 'read_messages', TRUE)
ON DUPLICATE KEY UPDATE can_perform=VALUES(can_perform);
