-- Library Management System Database Schema
-- MySQL

CREATE DATABASE IF NOT EXISTS library_management;
USE library_management;

-- Users table for authentication (Admin only)
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('admin') NOT NULL DEFAULT 'admin',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Books table
CREATE TABLE books (
    id INT AUTO_INCREMENT PRIMARY KEY,
    isbn VARCHAR(20) UNIQUE NOT NULL,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    publisher VARCHAR(255),
    year_published YEAR,
    cover_image TEXT,
    total_copies INT DEFAULT 1,
    available_copies INT DEFAULT 1,
    description TEXT,
    status ENUM('available', 'issued') DEFAULT 'available',
    added_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_isbn (isbn),
    INDEX idx_title (title),
    INDEX idx_author (author),
    INDEX idx_category (category)
);

-- Members table
CREATE TABLE members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    member_type ENUM('guest', 'staff') NOT NULL,
    membership_date DATE NOT NULL,
    profile_photo TEXT,
    address TEXT,
    expiry_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_name (name),
    INDEX idx_email (email)
);

-- Issues table
CREATE TABLE issues (
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
    INDEX idx_due_date (due_date)
);

-- Sample data (Admin only)
INSERT INTO users (username, password_hash, role) VALUES
('admin', '$2b$10$6W0zDqIEBMezJOSEpnIT7O2AyoMKbDd0dbZwV442BQT984WTt7sXu', 'admin'),
('librarian', '$2b$10$ausiZpSowIStAv4gdLu42uYSGdXBGVz0M5Hn2c62vXR3wR3sHU1AG', 'admin');

INSERT INTO books (isbn, title, author, category, publisher, year_published) VALUES
('978-0-123456-78-9', 'Sample Book 1', 'Author 1', 'Fiction', 'Publisher 1', 2020),
('978-0-987654-32-1', 'Sample Book 2', 'Author 2', 'Non-Fiction', 'Publisher 2', 2021);

INSERT INTO members (name, email, phone, member_type, membership_date) VALUES
('John Doe', 'john@example.com', '1234567890', 'guest', '2023-01-01'),
('Jane Smith', 'jane@example.com', '0987654321', 'staff', '2023-01-01');