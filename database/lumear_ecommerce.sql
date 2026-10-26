-- LUMEAR BUYER / SELLER DATABASE HANDOFF
-- Standalone proposal for MySQL 8.0.16+ (InnoDB).
-- Not connected to Flutter. Run manually on a NEW database after review.
-- No DROP statements, credentials, accounts, or live customer data are included.
-- Money is integer PHP centavos: 49900 = PHP 499.00, matching the Flutter API.
-- Store all DATETIME values in UTC; the API formats dates for clients.

CREATE DATABASE lumear_ecommerce
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE lumear_ecommerce;
SET time_zone = '+00:00';

CREATE TABLE Users (
    user_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(254) NOT NULL UNIQUE,
    password_hash VARCHAR(255), -- NULL for Google-only accounts; never plaintext
    role ENUM('buyer', 'seller') NOT NULL,
    phone VARCHAR(30),
    email_verified_at DATETIME,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE UserIdentities (
    identity_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    provider ENUM('google') NOT NULL,
    provider_subject VARCHAR(255) COLLATE utf8mb4_bin NOT NULL,
    UNIQUE (provider, provider_subject),
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
) ENGINE=InnoDB;

CREATE TABLE AuthSessions (
    session_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    revoked_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
) ENGINE=InnoDB;

CREATE TABLE Shops (
    shop_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    seller_user_id BIGINT UNSIGNED NOT NULL UNIQUE,
    shop_name VARCHAR(150) NOT NULL,
    description TEXT,
    contact_email VARCHAR(254),
    contact_phone VARCHAR(30),
    status ENUM('pending', 'active', 'suspended') NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (seller_user_id) REFERENCES Users(user_id)
) ENGINE=InnoDB;

CREATE TABLE Addresses (
    address_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    label VARCHAR(50) NOT NULL DEFAULT 'Home',
    recipient_name VARCHAR(150) NOT NULL,
    phone VARCHAR(30) NOT NULL,
    region VARCHAR(100),
    province VARCHAR(100) NOT NULL,
    city_municipality VARCHAR(100) NOT NULL,
    barangay VARCHAR(100) NOT NULL,
    house_street VARCHAR(255) NOT NULL,
    postal_code VARCHAR(20),
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    -- Multiple NULLs are allowed; only one default address per user.
    default_for_user BIGINT UNSIGNED GENERATED ALWAYS AS
        (CASE WHEN is_default THEN user_id ELSE NULL END) STORED,
    UNIQUE (default_for_user),
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
) ENGINE=InnoDB;

CREATE TABLE Categories (
    category_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE Subcategories (
    subcategory_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    category_id BIGINT UNSIGNED NOT NULL,
    subcategory_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (category_id, subcategory_name),
    UNIQUE (subcategory_id, category_id),
    FOREIGN KEY (category_id) REFERENCES Categories(category_id)
) ENGINE=InnoDB;

CREATE TABLE Products (
    product_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    shop_id BIGINT UNSIGNED NOT NULL,
    category_id BIGINT UNSIGNED NOT NULL,
    subcategory_id BIGINT UNSIGNED NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE (product_id, shop_id),
    INDEX idx_products_category (category_id, is_active),
    FOREIGN KEY (shop_id) REFERENCES Shops(shop_id),
    FOREIGN KEY (category_id) REFERENCES Categories(category_id),
    FOREIGN KEY (subcategory_id, category_id) REFERENCES Subcategories(subcategory_id, category_id)
) ENGINE=InnoDB;

CREATE TABLE ProductVariants (
    variant_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    product_id BIGINT UNSIGNED NOT NULL,
    sku VARCHAR(100) NOT NULL UNIQUE,
    variant_label VARCHAR(150) NOT NULL DEFAULT 'Default',
    price_centavos BIGINT UNSIGNED NOT NULL,
    stock_quantity INT UNSIGNED NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (variant_id, product_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
) ENGINE=InnoDB;

CREATE TABLE ProductMedia (
    media_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    product_id BIGINT UNSIGNED NOT NULL,
    media_type ENUM('image', 'video') NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    media_url VARCHAR(2048) NOT NULL,
    sort_order INT UNSIGNED NOT NULL DEFAULT 0,
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
) ENGINE=InnoDB;

CREATE TABLE CartItems (
    cart_item_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    buyer_user_id BIGINT UNSIGNED NOT NULL,
    variant_id BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (buyer_user_id, variant_id),
    CONSTRAINT ck_cart_quantity CHECK (quantity > 0),
    FOREIGN KEY (buyer_user_id) REFERENCES Users(user_id),
    FOREIGN KEY (variant_id) REFERENCES ProductVariants(variant_id)
) ENGINE=InnoDB;

CREATE TABLE Wishlist (
    user_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, product_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
) ENGINE=InnoDB;

CREATE TABLE ShopFollowers (
    user_id BIGINT UNSIGNED NOT NULL,
    shop_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id, shop_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (shop_id) REFERENCES Shops(shop_id)
) ENGINE=InnoDB;

CREATE TABLE Vouchers (
    voucher_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    shop_id BIGINT UNSIGNED, -- NULL = platform-wide voucher
    code VARCHAR(50) NOT NULL UNIQUE,
    title VARCHAR(150) NOT NULL,
    kind ENUM('discount', 'shipping') NOT NULL,
    discount_type ENUM('fixed', 'percent') NOT NULL,
    fixed_centavos BIGINT UNSIGNED,
    percent_value DECIMAL(5,2),
    cap_centavos BIGINT UNSIGNED NOT NULL,
    minimum_spend_centavos BIGINT UNSIGNED NOT NULL DEFAULT 0,
    starts_at DATETIME NOT NULL,
    expires_at DATETIME NOT NULL,
    usage_limit INT UNSIGNED NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_voucher_dates CHECK (expires_at > starts_at),
    CONSTRAINT ck_voucher_value CHECK (
        (discount_type = 'fixed' AND fixed_centavos IS NOT NULL
            AND fixed_centavos > 0 AND percent_value IS NULL) OR
        (discount_type = 'percent' AND percent_value IS NOT NULL
            AND percent_value > 0 AND percent_value <= 100 AND fixed_centavos IS NULL)
    ),
    FOREIGN KEY (shop_id) REFERENCES Shops(shop_id)
) ENGINE=InnoDB;

CREATE TABLE UserVouchers (
    user_id BIGINT UNSIGNED NOT NULL,
    voucher_id BIGINT UNSIGNED NOT NULL,
    claimed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, voucher_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (voucher_id) REFERENCES Vouchers(voucher_id)
) ENGINE=InnoDB;

-- One order per shop; checkout_group groups orders from one multi-shop checkout.
-- Address, names and prices are snapshots, so later edits do not rewrite a sale.
CREATE TABLE Orders (
    order_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    order_number VARCHAR(60) NOT NULL UNIQUE,
    checkout_group VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
    buyer_user_id BIGINT UNSIGNED NOT NULL,
    shop_id BIGINT UNSIGNED NOT NULL,
    status ENUM('pending', 'accepted', 'packed', 'ready_to_ship',
        'in_transit', 'delivered', 'completed', 'cancelled') NOT NULL DEFAULT 'pending',
    recipient_name VARCHAR(150) NOT NULL,
    recipient_phone VARCHAR(30) NOT NULL,
    address_region VARCHAR(100),
    address_province VARCHAR(100) NOT NULL,
    address_city VARCHAR(100) NOT NULL,
    address_barangay VARCHAR(100) NOT NULL,
    address_street VARCHAR(255) NOT NULL,
    address_postal_code VARCHAR(20),
    payment_method ENUM('COD', 'GCash', 'Card', 'Bank transfer') NOT NULL DEFAULT 'COD',
    subtotal_centavos BIGINT UNSIGNED NOT NULL,
    shipping_centavos BIGINT UNSIGNED NOT NULL DEFAULT 0,
    discount_centavos BIGINT UNSIGNED NOT NULL DEFAULT 0,
    total_centavos BIGINT UNSIGNED NOT NULL,
    -- Lumear commission: 10% of merchandise subtotal BEFORE voucher discounts.
    -- Shipping is excluded. Round to the nearest centavo, half up.
    commission_centavos BIGINT UNSIGNED GENERATED ALWAYS AS
        (ROUND(subtotal_centavos * 0.10, 0)) STORED,
    cancellation_reason TEXT,
    placed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE (order_id, shop_id),
    UNIQUE (buyer_user_id, checkout_group, shop_id),
    INDEX idx_orders_buyer (buyer_user_id, placed_at),
    INDEX idx_orders_shop_status (shop_id, status, placed_at),
    CONSTRAINT ck_order_total CHECK (
        subtotal_centavos + shipping_centavos = total_centavos + discount_centavos
    ),
    CONSTRAINT ck_order_commission CHECK (commission_centavos <= subtotal_centavos),
    FOREIGN KEY (buyer_user_id) REFERENCES Users(user_id),
    FOREIGN KEY (shop_id) REFERENCES Shops(shop_id)
) ENGINE=InnoDB;

CREATE TABLE OrderItems (
    order_item_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    shop_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    variant_id BIGINT UNSIGNED NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    variant_label VARCHAR(150) NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    unit_price_centavos BIGINT UNSIGNED NOT NULL,
    line_total_centavos BIGINT UNSIGNED NOT NULL,
    CONSTRAINT ck_order_item_quantity CHECK (quantity > 0),
    CONSTRAINT ck_order_item_total CHECK (line_total_centavos = quantity * unit_price_centavos),
    FOREIGN KEY (order_id, shop_id) REFERENCES Orders(order_id, shop_id),
    FOREIGN KEY (product_id, shop_id) REFERENCES Products(product_id, shop_id),
    FOREIGN KEY (variant_id, product_id) REFERENCES ProductVariants(variant_id, product_id)
) ENGINE=InnoDB;

CREATE TABLE OrderVouchers (
    order_id BIGINT UNSIGNED NOT NULL,
    voucher_id BIGINT UNSIGNED NOT NULL,
    discount_centavos BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (order_id, voucher_id),
    FOREIGN KEY (order_id) REFERENCES Orders(order_id),
    FOREIGN KEY (voucher_id) REFERENCES Vouchers(voucher_id)
) ENGINE=InnoDB;

CREATE TABLE Payments (
    payment_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    provider VARCHAR(50) NOT NULL, -- 'COD' or server-approved payment provider
    provider_reference VARCHAR(150) COLLATE utf8mb4_bin,
    amount_centavos BIGINT UNSIGNED NOT NULL,
    status ENUM('pending', 'paid', 'failed', 'cancelled') NOT NULL DEFAULT 'pending',
    paid_at DATETIME,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (provider, provider_reference),
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)
) ENGINE=InnoDB;

CREATE TABLE OrderStatusHistory (
    history_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    status ENUM('pending', 'accepted', 'packed', 'ready_to_ship',
        'in_transit', 'delivered', 'completed', 'cancelled') NOT NULL,
    note TEXT,
    changed_by_user_id BIGINT UNSIGNED, -- NULL = authorized backend process
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_order_timeline (order_id, changed_at, history_id),
    FOREIGN KEY (order_id) REFERENCES Orders(order_id),
    FOREIGN KEY (changed_by_user_id) REFERENCES Users(user_id)
) ENGINE=InnoDB;

CREATE TABLE RefundRequests (
    refund_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    requested_by_user_id BIGINT UNSIGNED NOT NULL,
    reason TEXT NOT NULL,
    amount_centavos BIGINT UNSIGNED NOT NULL,
    status ENUM('requested', 'approved', 'rejected', 'refunded') NOT NULL DEFAULT 'requested',
    provider_reference VARCHAR(150),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME,
    CONSTRAINT ck_refund_amount CHECK (amount_centavos > 0),
    FOREIGN KEY (order_id) REFERENCES Orders(order_id),
    FOREIGN KEY (requested_by_user_id) REFERENCES Users(user_id)
) ENGINE=InnoDB;

CREATE TABLE Reviews (
    review_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    order_item_id BIGINT UNSIGNED NOT NULL UNIQUE,
    reviewer_user_id BIGINT UNSIGNED NOT NULL,
    stars TINYINT UNSIGNED NOT NULL,
    review_text TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_review_stars CHECK (stars BETWEEN 1 AND 5),
    FOREIGN KEY (order_item_id) REFERENCES OrderItems(order_item_id),
    FOREIGN KEY (reviewer_user_id) REFERENCES Users(user_id)
) ENGINE=InnoDB;

CREATE TABLE SellerPayouts (
    payout_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    shop_id BIGINT UNSIGNED NOT NULL,
    amount_centavos BIGINT UNSIGNED NOT NULL,
    request_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
    status ENUM('requested', 'processing', 'paid', 'rejected') NOT NULL DEFAULT 'requested',
    provider_reference VARCHAR(150),
    requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at DATETIME,
    UNIQUE (shop_id, request_id),
    UNIQUE (payout_id, shop_id),
    CONSTRAINT ck_payout_amount CHECK (amount_centavos > 0),
    FOREIGN KEY (shop_id) REFERENCES Shops(shop_id)
) ENGINE=InnoDB;

CREATE TABLE PayoutOrders (
    order_id BIGINT UNSIGNED PRIMARY KEY, -- An order can be settled only once
    shop_id BIGINT UNSIGNED NOT NULL,
    payout_id BIGINT UNSIGNED NOT NULL,
    net_amount_centavos BIGINT UNSIGNED NOT NULL,
    FOREIGN KEY (order_id, shop_id) REFERENCES Orders(order_id, shop_id),
    FOREIGN KEY (payout_id, shop_id) REFERENCES SellerPayouts(payout_id, shop_id)
) ENGINE=InnoDB;

CREATE TABLE Notifications (
    notification_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    order_id BIGINT UNSIGNED,
    is_sent BOOLEAN NOT NULL DEFAULT FALSE,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notifications_user (user_id, is_read, created_at),
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)
) ENGINE=InnoDB;

CREATE TABLE DeviceTokens (
    token_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    device_token VARCHAR(512) COLLATE utf8mb4_bin NOT NULL UNIQUE,
    platform ENUM('Android', 'iOS', 'Web') NOT NULL,
    last_used_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
) ENGINE=InnoDB;

CREATE TABLE ChatThreads (
    thread_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    buyer_user_id BIGINT UNSIGNED NOT NULL,
    shop_id BIGINT UNSIGNED NOT NULL,
    initial_product_id BIGINT UNSIGNED,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (buyer_user_id, shop_id),
    FOREIGN KEY (buyer_user_id) REFERENCES Users(user_id),
    FOREIGN KEY (shop_id) REFERENCES Shops(shop_id),
    FOREIGN KEY (initial_product_id, shop_id) REFERENCES Products(product_id, shop_id)
) ENGINE=InnoDB;

CREATE TABLE ChatMessages (
    message_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    thread_id BIGINT UNSIGNED NOT NULL,
    sender_user_id BIGINT UNSIGNED NOT NULL,
    request_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
    message_text VARCHAR(2000) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at DATETIME,
    UNIQUE (thread_id, sender_user_id, request_id),
    INDEX idx_chat_history (thread_id, message_id),
    CONSTRAINT ck_chat_text CHECK (CHAR_LENGTH(TRIM(message_text)) > 0),
    FOREIGN KEY (thread_id) REFERENCES ChatThreads(thread_id),
    FOREIGN KEY (sender_user_id) REFERENCES Users(user_id)
) ENGINE=InnoDB;

-- Optional server-side AI history. Current mobile assistant uses session history.
CREATE TABLE AssistantConversations (
    conversation_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
) ENGINE=InnoDB;

CREATE TABLE AssistantMessages (
    assistant_message_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    conversation_id BIGINT UNSIGNED NOT NULL,
    role ENUM('user', 'assistant') NOT NULL,
    message_text TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_assistant_history (conversation_id, assistant_message_id),
    CONSTRAINT ck_assistant_text CHECK (CHAR_LENGTH(TRIM(message_text)) > 0),
    FOREIGN KEY (conversation_id) REFERENCES AssistantConversations(conversation_id)
) ENGINE=InnoDB;

-- Eight main categories and 48 subcategories. No demo users or passwords.
INSERT INTO Categories (category_name) VALUES ('Pet Supplies');
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Dog Food & Treats' FROM Categories WHERE category_name = 'Pet Supplies';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Cat Litter & Accessories' FROM Categories WHERE category_name = 'Pet Supplies';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Aquariums & Fish Supplies' FROM Categories WHERE category_name = 'Pet Supplies';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Bird Feeders & Food' FROM Categories WHERE category_name = 'Pet Supplies';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Pet Grooming Products' FROM Categories WHERE category_name = 'Pet Supplies';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Pet Health & Wellness' FROM Categories WHERE category_name = 'Pet Supplies';

INSERT INTO Categories (category_name) VALUES ('Electronics and Gadgets');
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Mobile Phones & Accessories' FROM Categories WHERE category_name = 'Electronics and Gadgets';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Laptops, Desktops & Monitors' FROM Categories WHERE category_name = 'Electronics and Gadgets';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Audio & Video Equipment' FROM Categories WHERE category_name = 'Electronics and Gadgets';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Smart Home Devices' FROM Categories WHERE category_name = 'Electronics and Gadgets';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Cameras & Photography' FROM Categories WHERE category_name = 'Electronics and Gadgets';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Wearable Technology' FROM Categories WHERE category_name = 'Electronics and Gadgets';

INSERT INTO Categories (category_name) VALUES ('Women''s Apparel');
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Dresses & Skirts' FROM Categories WHERE category_name = 'Women''s Apparel';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Tops & Blouses' FROM Categories WHERE category_name = 'Women''s Apparel';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Activewear & Yoga Pants' FROM Categories WHERE category_name = 'Women''s Apparel';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Lingerie & Sleepwear' FROM Categories WHERE category_name = 'Women''s Apparel';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Jackets & Coats' FROM Categories WHERE category_name = 'Women''s Apparel';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Shoes & Accessories' FROM Categories WHERE category_name = 'Women''s Apparel';

INSERT INTO Categories (category_name) VALUES ('Men''s Apparel');
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Suits & Blazers' FROM Categories WHERE category_name = 'Men''s Apparel';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Casual Shirts & Pants' FROM Categories WHERE category_name = 'Men''s Apparel';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Outerwear & Jackets' FROM Categories WHERE category_name = 'Men''s Apparel';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Activewear & Fitness Gear' FROM Categories WHERE category_name = 'Men''s Apparel';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Shoes & Accessories' FROM Categories WHERE category_name = 'Men''s Apparel';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Grooming Products' FROM Categories WHERE category_name = 'Men''s Apparel';

INSERT INTO Categories (category_name) VALUES ('Kids and Baby');
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Baby Clothes & Accessories' FROM Categories WHERE category_name = 'Kids and Baby';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Toys & Games' FROM Categories WHERE category_name = 'Kids and Baby';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Educational Materials' FROM Categories WHERE category_name = 'Kids and Baby';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Strollers & Gear' FROM Categories WHERE category_name = 'Kids and Baby';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Nursery Furniture' FROM Categories WHERE category_name = 'Kids and Baby';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Safety and Health' FROM Categories WHERE category_name = 'Kids and Baby';

INSERT INTO Categories (category_name) VALUES ('Home and Garden');
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Kitchen Appliances' FROM Categories WHERE category_name = 'Home and Garden';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Furniture & Decor' FROM Categories WHERE category_name = 'Home and Garden';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Gardening Tools' FROM Categories WHERE category_name = 'Home and Garden';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Outdoor Living' FROM Categories WHERE category_name = 'Home and Garden';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Home Improvement Tools' FROM Categories WHERE category_name = 'Home and Garden';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Bedding & Bath' FROM Categories WHERE category_name = 'Home and Garden';

INSERT INTO Categories (category_name) VALUES ('Sports and Outdoors');
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Fitness Equipment' FROM Categories WHERE category_name = 'Sports and Outdoors';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Camping & Hiking Gear' FROM Categories WHERE category_name = 'Sports and Outdoors';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Sports Apparel' FROM Categories WHERE category_name = 'Sports and Outdoors';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Cycling & Bikes' FROM Categories WHERE category_name = 'Sports and Outdoors';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Water Sports' FROM Categories WHERE category_name = 'Sports and Outdoors';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Team Sports Equipment' FROM Categories WHERE category_name = 'Sports and Outdoors';

INSERT INTO Categories (category_name) VALUES ('Health and Beauty');
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Skincare Products' FROM Categories WHERE category_name = 'Health and Beauty';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Haircare Solutions' FROM Categories WHERE category_name = 'Health and Beauty';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Makeup & Cosmetics' FROM Categories WHERE category_name = 'Health and Beauty';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Personal Care Appliances' FROM Categories WHERE category_name = 'Health and Beauty';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Men''s Grooming' FROM Categories WHERE category_name = 'Health and Beauty';
INSERT INTO Subcategories (category_id, subcategory_name) SELECT category_id, 'Health Supplements' FROM Categories WHERE category_name = 'Health and Beauty';

-- Optional inspection queries after importing:
-- SHOW TABLES;
-- SELECT * FROM Categories;
-- SELECT product_id, product_name, shop_id FROM Products;
