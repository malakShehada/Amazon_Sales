CREATE TABLE dim_product(
    product_id VARCHAR(50) PRIMARY KEY,
    product_name TEXT NOT NULL,
    img_link TEXT,
    product_link TEXT,
    cat_leaf VARCHAR(255)
);


CREATE TABLE dim_category(
    category_key INT PRIMARY KEY,
    category_path TEXT NOT NULL,
    cat_leaf VARCHAR(255),
    cat_depth INT NOT NULL,
    cat_l1 VARCHAR(255),
    cat_l2 VARCHAR(255),
    cat_l3 VARCHAR(255),
    cat_l4 VARCHAR(255),
    cat_l5 VARCHAR(255),
    cat_l6 VARCHAR(255),
    cat_l7 VARCHAR(255),
    CONSTRAINT uq_dim_category_path UNIQUE (category_path)
    
);

CREATE TABLE bridge_product_category(
    product_id VARCHAR(50) NOT NULL,
    category_key INT NOT NULL,
    CONSTRAINT pk_bridge_product_category PRIMARY KEY (product_id, category_key),
    CONSTRAINT fk_bridge_product_product
        FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
    CONSTRAINT fk_bridge_category
        FOREIGN KEY (category_key) REFERENCES dim_category (category_key)
);

CREATE TABLE fact_product_snapshot(
    product_id VARCHAR(50) NOT NULL,
    category_key INT NOT NULL,
    discounted_price DECIMAL(10,2),
    actual_price DECIMAL(10,2),
    discount_percentage DECIMAL(5,2),
    rating DECIMAL(5,2),
    rating_count INT,
    ingestion_date DATE NOT NULL,
    CONSTRAINT fk_fact_product
        FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
    CONSTRAINT fk_fact_category
        FOREIGN KEY (category_key) REFERENCES dim_category(category_key)
);

