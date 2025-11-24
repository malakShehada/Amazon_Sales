# 🛒 Amazon Sales — Data Engineering Project
Comprehensive ETL + Data Cleaning + Dimensional Modeling + SQL Insights + Power BI Dashboard

## ⭐ 1. Project Overview
This project demonstrates a complete Data Engineering workflow, starting from raw scraped Amazon product data and ending with a fully modeled PostgreSQL Data Warehouse, analytical SQL insights, and a Power BI dashboard.
The goal is to simulate how a real data engineering pipeline ingests, cleans, transforms, models, loads, and analyzes product data.

## 📂 2. Project Structure
📦 Amazon-Sales-Data-Engineering-Project
``` │
├── README.md
├── .gitignore
├── requirements.txt
│
├── data/
│   ├── processed/
│   │   ├── fact_product_snapshot.csv
│   │   ├── bridge_product_category.csv
│   │   ├── dim_category.csv
│   │   └── dim_product.csv
│   │
│   └── raw/
│       └── amazon.csv
│
├── src/
│   └── pipeline.py
│
├── sql/
│   ├── queries.sql
│   └── create_tables.sql
│
├── notebooks/
│   └── Amazon Sales.ipynb
│
├── reports/
│   ├── Amazon Sales Dashboard.pbix
│   └── states_report.md 
│
```


## 🛠 3. Tools & Technologies
| Component      | Technology           |
| ------------- | -------------------- |
| Language      | Python 3.10          |
| Data Processing | pandas             |
| Database      | PostgreSQL           |
| Visualization | Power BI Desktop     |
| Pipeline      | Custom Python ETL    |
| Documentation | Markdown, Jupyter    |


## 🧹 4. Data Preparation & Cleaning

- Performed in pipeline.py and the notebook.
- Loaded raw data
- Removed duplicates
- Dropped rows missing critical identifiers
- Cleaned and validated numeric fields
- Enforced consistent pricing logic
- Extracted hierarchical categories
- Computed category depth + cat_leaf
- Built dimensional tables
- Exported processed CSVs

## 🧱 5. Data Warehouse Schema
📌 Fact Table
fact_product_snapshot
- Stores product snapshot metrics (prices, ratings…) with date.

📌 Dimension Tables
- dim_product
- dim_category
- bridge_product_category

## 📊 6. SQL Insights & Analytics
All SQL queries and results documented in:
- reports/states_report.md
- sql/queries.sql
Analyses include:
- Best categories
- Discount vs rating
- Price segmentation
- Hidden gems
- Weak categories
- Platform-wide metrics

## 📈 7. Dashboard
Interactive Power BI dashboard:
reports/Amazon Sales Dashboard.pbix

## ▶️ 8. How to Run the Pipeline
1. **Install dependencies**
pip install -r requirements.txt
2. **Run ETL**
python src/pipeline.py
3. **Load schema**
sql/create_tables.sql
4. **Load CSV data into warehouse**
5. **Run analytics**
sql/queries.sql

## 🚀 9. Improvements
- Airflow DAG
- YAML configs
- Cloud DW migration
- API endpoints
- Unit testing
- More visualizations

## 🏁 10. Final Thoughts

This project demonstrates an end-to-end data engineering workflow: from raw CSV ingestion and rigorous data cleaning, through dimensional modeling in PostgreSQL, to SQL analytics and BI reporting with Power BI.  
It can serve as a template for similar retail/e‑commerce analytics projects or as a portfolio piece to showcase practical data engineering skills.  
