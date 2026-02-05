-- Library Management System Database Schema V2
-- MySQL - Enhanced with new features

CREATE DATABASE IF NOT EXISTS library_management
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE library_management;

-- Users table for authentication (Admin only)
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('admin') NOT NULL DEFAULT 'admin',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Book Categories table
CREATE TABLE IF NOT EXISTS book_categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Books table (Enhanced with cover images and copies)
CREATE TABLE IF NOT EXISTS books (
    id INT AUTO_INCREMENT PRIMARY KEY,
    isbn VARCHAR(20) UNIQUE NULL,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    rack_number VARCHAR(50),
    category VARCHAR(100),
    publisher VARCHAR(255),
    year_published YEAR,
    cover_image TEXT,
    total_copies INT DEFAULT 1,
    available_copies INT DEFAULT 1,
    description TEXT,
    status ENUM('available', 'issued', 'all_issued') DEFAULT 'available',
    added_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_isbn (isbn),
    INDEX idx_title (title),
    INDEX idx_author (author),
    INDEX idx_category (category)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Member Categories table (for different borrowing limits)
CREATE TABLE IF NOT EXISTS member_categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    max_books INT DEFAULT 3,
    loan_period_days INT DEFAULT 14,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Members table (Enhanced with profile photos and category)
CREATE TABLE IF NOT EXISTS members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    member_type ENUM('guest', 'faculty', 'staff') NOT NULL DEFAULT 'guest',
    profile_photo TEXT,
    address TEXT,
    membership_date DATE NOT NULL,
    expiry_date DATE,
    category_id INT,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_name (name),
    INDEX idx_email (email),
    FOREIGN KEY (category_id) REFERENCES member_categories(id) ON DELETE SET NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Issues table (Enhanced)
CREATE TABLE IF NOT EXISTS issues (
    id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    member_id INT NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE NULL,
    status ENUM('issued', 'returned', 'overdue') DEFAULT 'issued',
    notes TEXT,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
    INDEX idx_book_id (book_id),
    INDEX idx_member_id (member_id),
    INDEX idx_issue_date (issue_date),
    INDEX idx_due_date (due_date),
    INDEX idx_status (status)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('info', 'warning', 'error', 'success', 'overdue', 'due_soon', 'new_book', 'system') DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    related_id INT,
    related_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_is_read (is_read),
    INDEX idx_created_at (created_at)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dashboard Settings table (for customizable widgets)
CREATE TABLE IF NOT EXISTS dashboard_settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    widget_name VARCHAR(100) NOT NULL,
    is_visible BOOLEAN DEFAULT TRUE,
    position INT DEFAULT 0,
    settings JSON,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_widget (user_id, widget_name)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Book Recommendations table (for tracking preferences)
CREATE TABLE IF NOT EXISTS book_recommendations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    member_id INT NOT NULL,
    book_id INT NOT NULL,
    score DECIMAL(5,2) DEFAULT 0,
    reason VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default member categories
INSERT INTO member_categories (name, max_books, loan_period_days) VALUES
('guest', 3, 14),
('faculty', 10, 30),
('staff', 5, 21)
ON DUPLICATE KEY UPDATE name=name;

-- Insert default book categories
INSERT INTO book_categories (name, description) VALUES
('Fiction', 'Fictional works including novels and short stories'),
('Non-Fiction', 'Factual and informational books'),
('Science', 'Scientific literature and research'),
('History', 'Historical accounts and analysis'),
('Biography', 'Life stories of notable individuals'),
('Literature', 'Classical and modern literature'),
('Philosophy', 'Philosophical works and treatises'),
('Psychology', 'Psychological studies and self-help'),
('Art', 'Art history and techniques'),
('Music', 'Music theory and history'),
('Technology', 'Technology and computing'),
('Mathematics', 'Mathematical studies'),
('Physics', 'Physical sciences'),
('Chemistry', 'Chemical sciences'),
('Biology', 'Biological sciences'),
('Medicine', 'Medical literature'),
('Engineering', 'Engineering disciplines'),
('Computer Science', 'Computing and programming'),
('Business', 'Business and management'),
('Economics', 'Economic studies'),
('Politics', 'Political science'),
('Law', 'Legal studies'),
('Religion', 'Religious texts and studies'),
('Education', 'Educational materials'),
('Sports', 'Sports and athletics'),
('Travel', 'Travel guides and literature'),
('Cooking', 'Culinary arts'),
('Health', 'Health and wellness'),
('Self-Help', 'Personal development'),
('Poetry', 'Poetic works'),
('Drama', 'Theatrical works'),
('Romance', 'Romantic fiction'),
('Mystery', 'Mystery and detective fiction'),
('Thriller', 'Thriller and suspense'),
('Fantasy', 'Fantasy literature'),
('Science Fiction', 'Science fiction works'),
('Horror', 'Horror fiction'),
('Adventure', 'Adventure stories'),
('Children', 'Childrens literature'),
('Young Adult', 'Young adult fiction'),
('Reference', 'Reference materials'),
('Comics', 'Comic books and graphic novels')
ON DUPLICATE KEY UPDATE name=name;

-- Migration: Add new columns to existing tables if they don't exist
-- These are ALTER statements to upgrade existing databases

-- Add columns to books table
-- ALTER TABLE books ADD COLUMN IF NOT EXISTS cover_image TEXT;
-- ALTER TABLE books ADD COLUMN IF NOT EXISTS total_copies INT DEFAULT 1;
-- ALTER TABLE books ADD COLUMN IF NOT EXISTS available_copies INT DEFAULT 1;
-- ALTER TABLE books ADD COLUMN IF NOT EXISTS description TEXT;

-- Add columns to members table  
-- ALTER TABLE members ADD COLUMN IF NOT EXISTS profile_photo TEXT;
-- ALTER TABLE members ADD COLUMN IF NOT EXISTS address TEXT;
-- ALTER TABLE members ADD COLUMN IF NOT EXISTS expiry_date DATE;
-- ALTER TABLE members ADD COLUMN IF NOT EXISTS category_id INT;
-- ALTER TABLE members ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
-- ALTER TABLE members MODIFY COLUMN member_type ENUM('student', 'faculty', 'staff') NOT NULL DEFAULT 'student';

-- Sample data
INSERT INTO users (username, password_hash, role) VALUES
('admin', '$2b$10$5noxZoO0TwLU6R6JdSKkTe3Yj8mVUky2VMlOQNZsAvkA7KrRQrUsa', 'admin'),
('librarian', '$2b$10$5noxZoO0TwLU6R6JdSKkTe3Yj8mVUky2VMlOQNZsAvkA7KrRQrUsa', 'admin')
ON DUPLICATE KEY UPDATE username=username;

-- Update existing books to have copies
UPDATE books SET total_copies = 1, available_copies = CASE WHEN status = 'available' THEN 1 ELSE 0 END WHERE total_copies IS NULL;
