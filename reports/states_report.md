# Amazon Sales Data Analysis Report

## 1. Project Overview
This report presents an analysis of Amazon product listings with a focus on prices, discounts, and customer ratings based on a curated snapshot of 1,351 products organized into 211 leaf categories in the category dimension, of which 207 are active in the current product snapshot.
The objective is to extract meaningful insights about product quality, category performance, discount strategies, and popularity patterns to support decision‑making for merchandising, marketing, and recommendation use cases.

## 2. Data Sources
The analysis is based on an Amazon products dataset obtained from Kaggle, which provides product metadata, pricing information, discount percentages, 
and aggregated customer rating statistics for each product ```https://www.kaggle.com/datasets/karkavelrajaj/amazon-sales-dataset```.

After modeling, all metrics are stored in the warehouse fact table `fact_product_snapshot` with 1,351 product records linked to detailed product and category dimensions.

## 3. Data Preparation & Cleaning
- **Loading Dataset**: The raw Amazon sales dataset was loaded from a CSV file.
- **Initial Exploration**: Displayed the first rows, reviewed column types, checked for missing values, and validated the completeness of key fields.
- **Cleaning Price Columns**: Price-related columns (actual_price, discounted_price, discount_percentage) contained currency symbols and commas. These were cleaned and converted into proper numeric formats.
- **Cleaning Rating Fields**: The rating and rating_count fields were cleaned by removing invalid characters, converting them to numeric types, and filling missing values with logical defaults.
- **Handling Missing & Invalid Values**: All invalid numeric values (negative prices, unrealistic discounts, or malformed ratings) were corrected or replaced. Rows missing essential product identifiers were removed.
- **Splitting Hierarchical Categories**: The original category column, containing pipe-separated paths, was split into multiple levels (cat_l1 to cat_l7). Additional fields were created: `cat_leaf (last category level)`, `cat_depth (number of levels)`, `category_path (standardized full path)`.
- **Removing Duplicate Products**: Duplicate product_id entries were detected and removed by keeping the record with the highest rating activity.
- **Running Data Quality Checks**: Applied consistency checks to verify category hierarchy validity, depth/path alignment, and price/rating integrity.
- **Preparing Dimensional Tables**: Based on the cleaned dataset:
    `Unique categories were stored in dim_category.`
    `Unique products were stored in dim_product.`
    `A bridge table mapped products to categories.`
    `A fact_product_snapshot table captured pricing, discounts, ratings, and review activity.`
- **Saving Final Outputs**: All cleaned and transformed tables were exported for loading into PostgreSQL.

## 4. Data Warehouse Schema
The data warehouse is organized as a star schema centered around a fact table that captures the latest price, discount, and rating snapshot for each product.

The main tables are:
- `dim_product`: descriptive attributes for each product such as `product_id`, `product_name`, image link and product link.
- `dim_category`: hierarchical category attributes including `category_path`, `cat_leaf`, `cat_depth`, and levels `cat_l1`–`cat_l7`.
- `bridge_product_category`: bridge table that links each `product_id` to its `category_key`, allowing many‑to‑many relationships between products and categories when needed.
- `fact_product_snapshot`: measures per product and category such as `actual_price`, `discounted_price`, `discount_percentage`, `rating`, `rating_count`, and `ingestion_date`.

All analytical queries in this report are executed directly on these four tables using standard SQL joins between the fact and dimension tables.

## 5. Key Insights & Statistics

### 5.1 Platform overview
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

- **Result**
"total_products" "total_categories"	"platform_avg_rating" "platform_avg_discount" "total_reviews" "avg_selling_price" "pct_high_rated"	"pct_high_discount"	"pct_popular"
1351	207	4.09	46.69	23802463	3304.65	74.76	45.00	77.05

- **Interpretation**
This query summarizes the whole dataset by counting total products and categories, and computing the average rating, average discount, total reviews, average selling price, and the percentage of high‑rated, high‑discount, and very popular items.

### 5.2 Best categories by products and engagement
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

- **Result**
"category"	"product_count"	"avg_rating"	"avg_discount"	"total_reviews"	"avg_actual_price"	"avg_discounted_price"
"AirFryers"	5	4.46	44.00	12237	12116.80	6276.40
"DisposableBatteries"	7	4.41	14.29	84049	388.43	327.43
"ExternalHardDisks"	6	4.40	27.00	213112	4642.67	3516.83
"GamingMice"	6	4.38	33.50	66068	1622.83	943.67
"MousePads"	8	4.38	61.25	32212	959.88	368.63
"CompositionNotebooks"	7	4.37	12.00	23333	267.86	227.14
"MicroSD"	10	4.36	57.10	873673	2159.80	892.00
"ScreenProtectors"	12	4.35	65.58	83306	1640.67	569.50
"Mice"	24	4.29	42.04	407289	1055.79	609.33
"EggBoilers"	11	4.29	52.91	29443	1678.91	812.73

- **Interpretation**
This query finds the top leaf categories that have enough products and combines their average rating, average discount, total reviews, and average prices to highlight the strongest‑performing categories overall.

### 5.3 Best deals: high discount and high rating
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

- **Result**
"product_name"	"category"	"discounted_price"	"actual_price"	"discount_percentage"	"rating"	"rating_count"	"value_score"
"AmazonBasics Flexible Premium HDMI Cable (Black, 4K@60Hz, 18Gbps), 3-Foot"	"HDMICables"	219.00	700.00	69.00	4.40	426973	8578.4530
"Amazon Basics High-Speed HDMI Cable, 6 Feet (2-Pack),Black"	"HDMICables"	309.00	1400.00	78.00	4.40	426973	6079.8744
"Pigeon Polypropylene Mini Handy and Compact Chopper with 3 Blades for Effortlessly Chopping Vegetables and Fruits for Your Kitchen (12420, Green, 400 ml)"	"Choppers"	199.00	495.00	60.00	4.10	270563	5574.4136
"boAt Bassheads 100 in Ear Wired Earphones with Mic(Taffy Pink)"	"In-Ear"	349.00	999.00	65.00	4.10	363713	4272.8461
"boAt BassHeads 100 in-Ear Wired Headphones with Mic (Black)"	"In-Ear"	365.00	999.00	63.00	4.10	363711	4085.5208
"boAt Bassheads 100 in Ear Wired Earphones with Mic(Furious Red)"	"In-Ear"	379.00	999.00	62.00	4.10	363713	3934.6261
"SanDisk Cruzer Blade 32GB USB Flash Drive"	"PenDrives"	289.00	650.00	56.00	4.30	253105	3765.9221
"AmazonBasics USB 2.0 Cable - A-Male to B-Male - for Personal Computer, Printer- 6 Feet (1.8 Meters), Black"	"USBCables"	209.00	695.00	70.00	4.50	107687	2318.6196
"AmazonBasics Micro USB Fast Charging Cable for Android Phones with Gold Plated Connectors (3 Feet, Black)"	"USBCables"	179.00	500.00	64.00	4.20	92595	2172.6201
"STRIFF PS2_01 Multi Angle Mobile/Tablet Tabletop Stand. Phone Holder for iPhone, Android, Samsung, OnePlus, Xiaomi. Portable, Foldable Cell Phone Stand. Perfect for Bed, Office, Home & Desktop (Black)"	"Stands"	99.00	499.00	80.00	4.30	42641	1852.0838
"AmazonBasics USB 2.0 - A-Male to A-Female Extension Cable for Personal Computer, Printer (Black, 9.8 Feet/3 Meters)"	"USBCables"	199.00	750.00	73.00	4.50	74976	1695.4372
"boAt Bassheads 242 in Ear Wired Earphones with Mic(Blue)"	"In-Ear"	455.00	1490.00	69.00	4.10	161677	1456.8697
"SanDisk Ultra Dual 64 GB USB 3.0 OTG Pen Drive (Black)"	"PenDrives"	579.00	1400.00	59.00	4.30	189104	1404.3993
"boAt Rugged v3 Extra Tough Unbreakable Braided Micro USB Cable 1.5 Meter (Black)"	"USBCables"	299.00	799.00	63.00	4.20	94364	1325.5144
"boAt Rugged V3 Braided Micro USB Cable (Pearl White)"	"USBCables"	299.00	799.00	63.00	4.20	94363	1325.5003

- **Interpretation**
This query selects products that have both high discounts and strong ratings with many reviews, then ranks them by a value score so you can see the most attractive “bang‑for‑buck” deals on the platform.

### 5.4 Most popular categories by number of products
SELECT
	c.category_path,
	COUNT(*) AS total_products
FROM bridge_product_category b
JOIN dim_category c
	ON b.category_key = c.category_key
GROUP BY c.category_path
ORDER BY total_products DESC
LIMIT 10;

- **Result**
"category_path"	"total_products"
"Computers&Accessories|Accessories&Peripherals|Cables&Accessories|Cables|USBCables|USBCables"	161
"Electronics|Mobiles&Accessories|Smartphones&BasicMobiles|Smartphones|Smartphones"	68
"Electronics|WearableTechnology|SmartWatches|SmartWatches"	62
"Electronics|HomeTheater,TV&Video|Televisions|SmartTelevisions|SmartTelevisions"	60
"Electronics|Headphones,Earbuds&Accessories|Headphones|In-Ear|In-Ear"	51
"Electronics|HomeTheater,TV&Video|Accessories|RemoteControls|RemoteControls"	49
"Home&Kitchen|Kitchen&HomeAppliances|SmallKitchenAppliances|MixerGrinders|MixerGrinders"	27
"Computers&Accessories|Accessories&Peripherals|Keyboards,Mice&InputDevices|Mice|Mice"	24
"Home&Kitchen|Kitchen&HomeAppliances|Vacuum,Cleaning&Ironing|Irons,Steamers&Accessories|Irons|DryIrons|DryIrons"	24
"Home&Kitchen|Heating,Cooling&AirQuality|WaterHeaters&Geysers|InstantWaterHeaters|InstantWaterHeaters"	23

- **Interpretation**
This query counts how many products fall into each full category path and returns the top ones, showing where the catalog is most dense and where the assortment is richest.

### 5.5 Rating distribution by category
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


- **Result**
"cat_leaf"	"rating_bucket"	"product_count"
"3DGlasses"	4	1
"Adapters"	4	2
"Adapters&Multi-Outlets"	4	1
"AirFryers"	4	3
"AirFryers"	5	2
"AirPurifiers&Ionizers"	4	1
"AutomobileChargers"	4	4
"AVReceivers&Amplifiers"	4	1
"BackgroundSupports"	4	1
"Basic"	5	1
"BasicCases"	4	4
"BasicMobiles"	4	9
"BatteryChargers"	4	1
"Bedstand&DeskMounts"	4	2
"BluetoothAdapters"	4	1
"BluetoothSpeakers"	4	6
"BottledInk"	4	2
"CableConnectionProtectors"	4	2
"Caddies"	4	1
"CameraPrivacyCovers"	4	2

- **Interpretation**
This query groups products into rating buckets inside each leaf category and counts how many items fall into each bucket, so you can see whether a category has mostly average, good, or excellent products.

### 5.6 Do higher discounts lead to better ratings?
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

- **Result**
"discount_range"	"product_count"	"average_rating"	"avg_reviews"	"avg_final_price"
"Low Discount (0-20%)"	162	4.14	14935.84	3978.69
"Medium Discount (20-50%)"	527	4.12	18263.04	5662.59
"High Discount (50%+)"	662	4.06	17761.69	1262.62

- **Interpretation**
This query groups products into discount ranges (low, medium, high) and calculates average rating, average review count, and average final price in each range to check how discount level relates to perceived quality and popularity.

### 5.7 Most popular products by review volume
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

- **Result**
"product_id"	"product_name"	"rating_count"	"rating"	"discounted_price"
"B07KSMBL2H"	"AmazonBasics Flexible Premium HDMI Cable (Black, 4K@60Hz, 18Gbps), 3-Foot"	426973	4.40	219.00
"B014I8SSD0"	"Amazon Basics High-Speed HDMI Cable, 6 Feet - Supports Ethernet, 3D, 4K video,Black"	426973	4.40	309.00
"B014I8SX4Y"	"Amazon Basics High-Speed HDMI Cable, 6 Feet (2-Pack),Black"	426973	4.40	309.00
"B07GQD4K6L"	"boAt Bassheads 100 in Ear Wired Earphones with Mic(Furious Red)"	363713	4.10	379.00
"B07GPXXNNG"	"boAt Bassheads 100 in Ear Wired Earphones with Mic(Taffy Pink)"	363713	4.10	349.00
"B071Z8M4KX"	"boAt BassHeads 100 in-Ear Wired Headphones with Mic (Black)"	363711	4.10	365.00
"B09GFLXVH9"	"Redmi 9A Sport (Coral Green, 2GB RAM, 32GB Storage) | 2GHz Octa-core Helio G25 Processor | 5000 mAh Battery"	313836	4.10	6499.00
"B09GFPVD9Y"	"Redmi 9 Activ (Carbon Black, 4GB RAM, 64GB Storage) | Octa-core Helio G35 | 5000 mAh Battery"	313836	4.10	8499.00
"B09GFM8CGS"	"Redmi 9A Sport (Carbon Black, 2GB RAM, 32GB Storage) | 2GHz Octa-core Helio G25 Processor | 5000 mAh Battery"	313832	4.10	6499.00
"B09GFPN6TP"	"Redmi 9A Sport (Coral Green, 3GB RAM, 32GB Storage) | 2GHz Octa-core Helio G25 Processor | 5000 mAh Battery"	313832	4.10	7499.00

- **Interpretation**
This query orders all products by the number of reviews and shows the top ones with their ratings and prices, highlighting the items that attract the most customer attention and feedback.

### 5.8 Hidden gems: high rating, reasonable price
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

- **Result**
"product_name"	"category"	"rating"	"rating_count"	"discounted_price"	"discount_percentage"	"value_index"
"AmazonBasics USB 2.0 Cable - A-Male to B-Male - for Personal Computer, Printer- 6 Feet (1.8 Meters), Black"	"USBCables"	4.50	107687	209.00	70.00	2318.6196
"AmazonBasics USB 2.0 - A-Male to A-Female Extension Cable for Personal Computer, Printer (Black, 9.8 Feet/3 Meters)"	"USBCables"	4.50	74976	199.00	73.00	1695.4372
"AmazonBasics USB 2.0 Extension Cable for Personal Computer, Printer, 2-Pack - A-Male to A-Female - 3.3 Feet (1 Meter, Black)"	"USBCables"	4.50	74977	299.00	63.00	1128.4164
"SanDisk Extreme SD UHS I 64GB Card for 4K Video for DSLR and Mirrorless Cameras 170MB/s Read & 80MB/s Write"	"MicroSD"	4.50	205052	939.00	48.00	982.6773
"Goldmedal Curve Plus 202042 Plastic Spice 3-Pin 240V Universal Travel Adaptor (White)"	"WallChargers"	4.50	11339	99.00	42.00	515.4091
"Redgear MP35 Speed-Type Gaming Mousepad (Black/Red)"	"Gamepads"	4.60	33434	299.00	46.00	514.3692
"Dell MS116 1000Dpi USB Wired Optical Mouse, Led Tracking, Scrolling Wheel, Plug and Play."	"Mice"	4.50	33176	299.00	54.00	499.3043
"ELV Aluminum Adjustable Mobile Phone Foldable Tabletop Stand Dock Mount for All Smartphones, Tabs, Kindle, iPad (Black)"	"Stands"	4.50	28978	269.00	82.00	484.7621
"Duracell Ultra Alkaline AA Battery, 8 Pcs"	"DisposableBatteries"	4.50	28030	266.00	16.00	474.1917
"Elv Aluminium Adjustable Mobile Phone Foldable Holder Tabletop Stand Dock Mount for All Smartphones, Tabs, Kindle, iPad (Moonlight Silver)"	"Stands"	4.50	28978	314.00	79.00	415.2898
"Logitech M235 Wireless Mouse, 1000 DPI Optical Tracking, 12 Month Life Battery, Compatible with Windows, Mac, Chromebook/PC/Laptop"	"Mice"	4.50	54405	699.00	30.00	350.2468
"AirCase Rugged Hard Drive Case for 2.5-inch Western Digital, Seagate, Toshiba, Portable Storage Shell for Gadget Hard Disk USB Cable Power Bank Mobile Charger Earphone, Waterproof (Black)"	"HardDiskBags"	4.50	21010	299.00	40.00	316.2040
"Gizga Essentials Hard Drive Case Shell, 6.35cm/2.5-inch, Portable Storage Organizer Bag for Earphone USB Cable Power Bank Mobile Charger Digital Gadget Hard Disk, Water Resistance Material, Black"	"HardDiskBags"	4.50	13568	199.00	67.00	306.8141
"Duracell Ultra Alkaline AAA Battery, 8 Pcs"	"DisposableBatteries"	4.50	17810	269.00	15.00	297.9368
"Classmate Soft Cover 6 Subject Spiral Binding Notebook, Single Line, 300 Pages"	"WireboundNotebooks"	4.50	8618	157.00	2.00	247.0127

- **Interpretation**
This query filters for products with very high ratings, many reviews, and relatively low prices, then ranks them by a value index to surface under‑priced but very well‑loved items.

### 5.9 Price segment performance
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

- **Result**
"price_segment"	"product_count"	"avg_rating"	"avg_discount"	"avg_reviews"
"Luxury (5000+)"	203	4.17	33.41	18255.51
"Mid-Range (500-2000)"	499	4.09	45.54	21025.16
"Budget (0-500)"	501	4.07	54.93	15863.81
"Premium (2000-5000)"	148	4.05	40.85	11197.76

- **Interpretation**
This query splits products into price bands (budget, mid‑range, premium, luxury) and summarizes for each band the product count, average rating, average discount, and average reviews, to compare how different price levels perform.

### 5.10 High‑quality categories by share of excellent products
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

- **Result**
"category"	"total_products"	"high_rated_products"	"pct_high_rated"	"avg_rating"	"avg_discount"	"avg_reviews"
"CompositionNotebooks"	7	3	42.86	4.37	12.00	3333.29
"ScreenProtectors"	12	5	41.67	4.35	65.58	6942.17
"AirFryers"	5	2	40.00	4.46	44.00	2447.40
"MousePads"	8	3	37.50	4.38	61.25	4026.50
"ExternalHardDisks"	6	2	33.33	4.40	27.00	35518.67
"GamingMice"	6	2	33.33	4.38	33.50	11011.33
"DisposableBatteries"	7	2	28.57	4.41	14.29	12007.00
"Mice"	24	6	25.00	4.29	42.04	16970.38
"HandBlenders"	19	4	21.05	4.06	41.68	4528.32
"MicroSD"	10	2	20.00	4.36	57.10	87367.30
- **Interpretation**
This query looks at each leaf category, measures what fraction of its items have excellent ratings (for example ≥ 4.5), and returns the categories with the highest share, along with their average discount and reviews, to reveal true quality hotspots.

### 6. Visualizations
Several exploratory visualizations were created in the accompanying Jupyter notebook to better understand rating, discount, and category behavior before and after modeling.

The key charts are:
- A histogram of product ratings showing how scores are distributed across the 1–5 scale, confirming that most items cluster around 4–5 stars.
- A horizontal bar chart of the top 10 leaf categories by total review count, highlighting where customer attention and engagement are most concentrated.
- A bar chart of average rating by price segment (Budget, Mid-Range, Premium, Luxury), visualizing how perceived quality changes across different price bands.

In addition to the notebook-based charts, an interactive Power BI dashboard [amazon_sales_dashboard.pbix](reports/Amazon Sales Dashboard.pbix) is included, providing the same key KPIs and category insights with slicers for main category, price segment, and rating filters.


## 7. Conclusions & Recommendations
### Conclusions
This analysis provides a comprehensive look into product performance, customer engagement, pricing strategy, and category-level trends across the platform.
Key findings indicate:

- Categories with deeper hierarchical structures are not necessarily better performing—quality varies widely across depth levels.
- High-discount products do not always achieve better ratings, but strategic discounts can boost popularity for certain segments.
- Price segments show distinct behavior: budget and mid-range products tend to attract the highest engagement, while premium items have strong ratings but lower review counts.
- "Hidden gem" products (high rating, moderate price, high value index) exist across multiple categories and represent strong opportunities for promotion.

### Recommendations
- Focus marketing and recommendation efforts on the strongest categories (like memory cards, screen protectors, mice, and small kitchen appliances) where ratings, discounts, and review volumes are all high.
- Highlight “best deal” products (high discount + good rating + many reviews) in featured sections, banners, and bundles to maximize perceived value and conversion.
- Use hidden‑gem products (very high rating, many reviews, affordable price) in cross‑sell and up‑sell strategies, especially on cart and checkout pages.
- Use high‑quality categories (with a large share of excellent products) as benchmarks when onboarding new items or vendors, ensuring that new products align with existing quality standards. 

### Final Thoughts
This project demonstrates an end‑to‑end data warehouse pipeline: starting from a Kaggle CSV, through systematic cleaning and dimensional modeling, to a set of focused analytical queries that answer real merchandising and pricing questions.​
Extending this work with scheduled data ingestion, richer time‑series snapshots, and production‑grade dashboards would turn it from a portfolio project into a reusable decision support asset for any retail or e‑commerce environment.