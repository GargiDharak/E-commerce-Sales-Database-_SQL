-- Project 1: E-commerce Sales Database
-- Database: MySQL 8.0+
-- Purpose: demonstrate relational schema design, CRUD, joins, aggregation,
-- reporting views, and basic data-quality checks.

CREATE DATABASE IF NOT EXISTS ecommerce_sales_db;
USE ecommerce_sales_db;



CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    city VARCHAR(80),
    created_at DATE NOT NULL
);

CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(120) NOT NULL,
    category VARCHAR(80) NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_product_price CHECK (unit_price >= 0)
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    order_status ENUM('Pending','Paid','Shipped','Delivered','Cancelled') NOT NULL DEFAULT 'Pending',
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price_at_purchase DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT chk_item_quantity CHECK (quantity > 0),
    CONSTRAINT chk_item_price CHECK (unit_price_at_purchase >= 0)
);

CREATE TABLE payments (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL UNIQUE,
    payment_date DATE,
    payment_method ENUM('UPI','Card','Net Banking','Cash on Delivery') NOT NULL,
    payment_status ENUM('Pending','Successful','Failed','Refunded') NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT chk_payment_amount CHECK (amount >= 0)
);

INSERT INTO customers (customer_name, email, city, created_at) VALUES
('Aarav Shah','aarav.shah@example.com','Pune','2025-01-10'),
('Meera Joshi','meera.joshi@example.com','Mumbai','2025-02-05'),
('Kabir Patil','kabir.patil@example.com','Pune','2025-02-18'),
('Anaya Rao','anaya.rao@example.com','Bengaluru','2025-03-01'),
('Ishaan Desai','ishaan.desai@example.com','Hyderabad','2025-03-12');

INSERT INTO products (product_name, category, unit_price, active) VALUES
('Wireless Mouse','Accessories',799.00,TRUE),
('Mechanical Keyboard','Accessories',2499.00,TRUE),
('USB-C Hub','Accessories',1599.00,TRUE),
('Laptop Stand','Office',1199.00,TRUE),
('Notebook Set','Office',299.00,TRUE),
('Old Webcam','Electronics',999.00,FALSE);

INSERT INTO orders (customer_id, order_date, order_status) VALUES
(1,'2025-04-01','Delivered'),
(2,'2025-04-03','Shipped'),
(1,'2025-04-08','Paid'),
(3,'2025-04-12','Cancelled'),
(4,'2025-05-02','Delivered'),
(5,'2025-05-09','Pending'),
(2,'2025-05-15','Delivered');

INSERT INTO order_items (order_id, product_id, quantity, unit_price_at_purchase) VALUES
(1,1,2,799.00),(1,5,1,299.00),
(2,2,1,2499.00),(2,3,1,1599.00),
(3,4,2,1199.00),
(4,1,1,799.00),
(5,2,1,2399.00),(5,5,2,299.00),
(6,3,1,1599.00),
(7,1,1,799.00),(7,4,1,1199.00);

INSERT INTO payments (order_id, payment_date, payment_method, payment_status, amount) VALUES
(1,'2025-04-01','UPI','Successful',1897.00),
(2,'2025-04-03','Card','Successful',4098.00),
(3,'2025-04-08','UPI','Successful',2398.00),
(4,'2025-04-12','Card','Refunded',799.00),
(5,'2025-05-02','Net Banking','Successful',2997.00),
(6,NULL,'UPI','Pending',1599.00),
(7,'2025-05-15','Cash on Delivery','Successful',1998.00);

-- 1. Inspect the tables.
SHOW TABLES;

-- 2. Order-level report: customer, date, status, and order value.
SELECT o.order_id, c.customer_name, o.order_date, o.order_status,
       ROUND(SUM(oi.quantity * oi.unit_price_at_purchase), 2) AS order_value
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, c.customer_name, o.order_date, o.order_status
ORDER BY o.order_date DESC;

-- 3. Sales by product category; exclude cancelled orders.
SELECT p.category,
       SUM(oi.quantity) AS units_sold,
       ROUND(SUM(oi.quantity * oi.unit_price_at_purchase), 2) AS gross_order_value
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status <> 'Cancelled'
GROUP BY p.category
ORDER BY gross_order_value DESC;

-- 4. Customers with at least two orders.
SELECT c.customer_id, c.customer_name, COUNT(o.order_id) AS order_count
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(o.order_id) >= 2
ORDER BY order_count DESC;

-- 5. Customers who have never placed an order.
SELECT c.customer_id, c.customer_name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- 6. Payment reconciliation: compare recorded payment with calculated order value.
SELECT o.order_id,
       ROUND(SUM(oi.quantity * oi.unit_price_at_purchase), 2) AS calculated_order_value,
       p.amount AS recorded_payment,
       p.payment_status,
       CASE WHEN p.amount = SUM(oi.quantity * oi.unit_price_at_purchase)
            THEN 'MATCH' ELSE 'REVIEW' END AS reconciliation_result
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN payments p ON p.order_id = o.order_id
GROUP BY o.order_id, p.amount, p.payment_status
ORDER BY o.order_id;

-- 7. Data-quality checks: duplicate emails should be prevented by UNIQUE constraint.
SELECT email, COUNT(*) AS duplicate_count
FROM customers
GROUP BY email
HAVING COUNT(*) > 1;

-- 8. Data-quality check: order items with invalid quantity (expected: no rows).
SELECT * FROM order_items WHERE quantity <= 0;

-- 9. Reusable monthly sales reporting view; exclude cancelled orders.
CREATE OR REPLACE VIEW vw_monthly_sales AS
SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS sales_month,
       COUNT(DISTINCT o.order_id) AS order_count,
       SUM(oi.quantity) AS units_sold,
       ROUND(SUM(oi.quantity * oi.unit_price_at_purchase), 2) AS gross_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status <> 'Cancelled'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m');

SELECT * FROM vw_monthly_sales ORDER BY sales_month;

-- 10. Example safe update: change a pending order to paid only after confirmation.
-- Run only if you intend to change the sample record:
-- UPDATE orders SET order_status = 'Paid' WHERE order_id = 6 AND order_status = 'Pending';
