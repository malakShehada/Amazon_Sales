SELECT
	COUNT(*) AS total_products,
	COUNT(DISTINCT cat_leaf) AS total_categories,
	ROUND(AVG(rating), 2) AS platform_avg_rating,
	ROUND(AVG(discount_percentage), 2) AS platform_avg_discount,
	SUM(rating_count) AS total_reviews,
	ROUND(AVG(discounted_price), 2) AS avg_selling_price,
	ROUND(100.0 * SUM(CASE WHEN rating >= 4.0 THEN 1 ELSE 0 END) / COUNT(*), 2) 
		AS pct_high_rated,
	ROUND(100.0 * SUM(CASE WHEN discount_percentage > 50 THEN 1 ELSE 0 END) / COUNT(*), 2) 
		AS pct_high_discount,
	ROUND(100.0 * SUM(CASE WHEN rating_count > 1000 THEN 1 ELSE 0 END) / COUNT(*), 2) 
		AS pct_popular
FROM fact_product_snapshot f
JOIN dim_category c
	ON f.category_key = c.category_key


-- Best 10 categories(products & rating count)
SELECT
	c.cat_leaf AS category,
	COUNT(*) AS product_count,
	ROUND(AVG(f.rating), 2) AS avg_rating,
	ROUND(AVG(f.discount_percentage), 2) AS avg_discount,
	SUM(f.rating_count) AS total_reviews,
	ROUND(AVG(f.actual_price), 2) AS avg_actual_price,
	ROUND(AVG(f.discounted_price), 2) AS avg_discounted_price
FROM dim_category c
JOIN fact_product_snapshot f
	ON c.category_key = f.category_key
GROUP BY c.cat_leaf
HAVING count(*) >= 5
ORDER BY avg_rating DESC, total_reviews DESC
LIMIT 10;


-- products with highest discount & high rated (Best Deals)
SELECT
	p.product_name,
	c.cat_leaf AS category,
	f.discounted_price,
	f.actual_price,
	f.discount_percentage,
	f.rating,
	f.rating_count,
	ROUND((f.rating * f.rating_count) / NULLIF(f.discounted_price, 0), 4)
		AS value_score
FROM fact_product_snapshot f
JOIN dim_product p
	ON f.product_id = p.product_id
JOIN dim_category c
	ON f.category_key = c.category_key
WHERE f.rating >= 4.0
	AND f.rating_count >= 100
	AND f.discount_percentage > 50
ORDER BY value_score DESC
LIMIT 15;


-- Most popular categories by products count
SELECT
	c.category_path,
	COUNT(*) AS total_products
FROM bridge_product_category b
JOIN dim_category c
	ON b.category_key = c.category_key
GROUP BY c.category_path
ORDER BY total_products DESC
LIMIT 10;


-- Products rating by category
SELECT
	c.cat_leaf, 
	ROUND(f.rating, 0) AS rating_bucket,
	COUNT(*) AS product_count
FROM fact_product_snapshot f
JOIN dim_category c 
	ON f.category_key = c.category_key
GROUP BY c.cat_leaf, ROUND(f.rating, 0)
ORDER BY c.cat_leaf, rating_bucket
LIMIT 20;


-- Are products with high discounts have high ratings?
SELECT
    CASE
        WHEN discount_percentage < 20 THEN 'Low Discount (0-20%)'
        WHEN discount_percentage < 50 THEN 'Medium Discount (20-50%)'
        ELSE 'High Discount (50%+)'
    END AS discount_range,
    COUNT(*) AS product_count,
    ROUND(AVG(rating), 2) AS average_rating,
    ROUND(AVG(rating_count), 2) AS avg_reviews,
    ROUND(AVG(discounted_price), 2) AS avg_final_price
FROM fact_product_snapshot
GROUP BY discount_range
ORDER BY average_rating DESC;


-- Most popular products
SELECT
    p.product_id,
    p.product_name,
    f.rating_count,
    f.rating,
    f.discounted_price
FROM fact_product_snapshot f
JOIN dim_product p USING (product_id)
ORDER BY f.rating_count DESC
LIMIT 10;


-- High rated products with normal price(Hidden Gems)
SELECT
    p.product_name,
    c.cat_leaf AS category,
    f.rating,
    f.rating_count,
    f.discounted_price,
    f.discount_percentage,
    ROUND(f.rating * f.rating_count / f.discounted_price, 4) AS value_index
FROM fact_product_snapshot f
JOIN dim_product p ON f.product_id = p.product_id
JOIN dim_category c ON f.category_key = c.category_key
WHERE f.rating >= 4.5
  AND f.rating_count >= 500
  AND f.discounted_price <= 1000
ORDER BY value_index DESC
LIMIT 15;


-- Price range analysis and performance
SELECT
    CASE
        WHEN discounted_price < 500 THEN 'Budget (0-500)'
        WHEN discounted_price < 2000 THEN 'Mid-Range (500-2000)'
        WHEN discounted_price < 5000 THEN 'Premium (2000-5000)'
        ELSE 'Luxury (5000+)'
    END AS price_segment,
    COUNT(*) AS product_count,
    ROUND(AVG(rating), 2) AS avg_rating,
    ROUND(AVG(discount_percentage), 2) AS avg_discount,
    ROUND(AVG(rating_count), 2) AS avg_reviews
FROM fact_product_snapshot
GROUP BY price_segment
ORDER BY avg_rating DESC;


-- High quality categories
SELECT
    c.cat_leaf AS category,
    COUNT(*) AS total_products,
    SUM(CASE WHEN f.rating >= 4.5 THEN 1 ELSE 0 END) AS high_rated_products,
    ROUND(100.0 * SUM(CASE WHEN f.rating >= 4.5 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_high_rated,
    ROUND(AVG(f.rating), 2) AS avg_rating,
    ROUND(AVG(f.discount_percentage), 2) AS avg_discount,
    ROUND(AVG(f.rating_count), 2) AS avg_reviews
FROM dim_category c
JOIN fact_product_snapshot f ON c.category_key = f.category_key
GROUP BY c.cat_leaf
HAVING COUNT(*) >= 5
ORDER BY pct_high_rated DESC, avg_rating DESC
LIMIT 10;

