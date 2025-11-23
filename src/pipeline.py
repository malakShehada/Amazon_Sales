import pandas as pd
from datetime import date

# loading dataset function
def load_data(filepath):
    """Load the dataset from a csv file."""
    df = pd.read_csv(filepath)
    print(f"Data loaded successfully. Shape: {df.shape}")
    return df

# cleaning prices function
def clean_price_columns(df):
    """Cleans and converts price and discount columns to numeric"""
    df['actual_price'] = df['actual_price'].replace('[₹,]', '', regex=True).astype(float)
    df['discounted_price'] = df['discounted_price'].replace('[₹,]', '', regex=True).astype(float)
    df['discount_percentage'] = df['discount_percentage'].replace('[%,]', '', regex=True).astype(float)
    return df

# cleaning ratings function
def clean_rating_columns(df):
    """Cleans rating and rating_count columns"""
    df['rating'] = pd.to_numeric(df['rating'], errors='coerce').fillna(0)
    df['rating_count'] = (
        df['rating_count']
        .astype(str)
        .str.replace(',', '', regex=False)
        .replace('nan', '0')
        .replace('', '0')
        .astype('int'))
    return df

# split categories function
def process_categories(df):
    """Splits and processes category hierarchies into multiple columns."""
    cat_lists = (
        df['category']
        .fillna('')
        .astype(str)
        .str.split('|')
        .map(lambda xs: [x.strip() for x in xs if x.strip() != ''])
    )
    max_depth = cat_lists.map(len).max()
    cols = [f'cat_l{i+1}' for i in range(max_depth)]
    category_df = pd.DataFrame(cat_lists.tolist(), index=df.index, columns=cols)
    df = pd.concat([df, category_df], axis=1)
    
    def get_last_category(row):
        for c in reversed(cols):
            if pd.notna(row.get(c)) and str(row[c]).strip() != '':
                return row[c]
        return None
    
    df['cat_leaf'] = df[cols].apply(get_last_category, axis=1)
    df['cat_depth'] = df[cols].notna().sum(axis=1)
    df['category_path'] = df[cols].apply(
        lambda r: '|'.join([str(r[c]) for c in cols if pd.notna(r[c])]), axis=1)
    return df

# Quality checks function
def run_quality_checks(df):
    
    #prepare category data
    level_cols = [c for c in df.columns if c.startswith('cat_l')]
    
    # Fix None issue and recalculate (this was outside the function before)
    df[level_cols] = df[level_cols].replace({None: pd.NA})
    calc_depth = df[level_cols].notna().sum(axis=1)
    df['cat_depth'] = calc_depth
    
    # Recalculate path
    df['category_path'] = df[level_cols].apply(
        lambda r: "|".join([str(r[c]) for c in level_cols if pd.notna(r[c])]),
        axis=1
    )
    
    """Runs data quality assertions on the DataFrame."""
    # discount_price has to be <= actual_price
    assert (df['discounted_price'] <= df['actual_price']).all(), \
    "Found Products where discounted_price > actual_price"

    # rating has to be between 0 & 5
    assert df['rating'].between(0, 5, inclusive = 'both').all(), \
    "Found invalid values in 'rating' column (should be 0-5)"

    # each level has to have a parent
    for i in range(1,7):
        parent = f'cat_l{i}'
        child = f'cat_l{i+1}'
        assert not (df[child].notna() & df[parent].isna()).any(), \
        f"Found rows where {child} exists without {parent}"
    
    # depth check
    assert (calc_depth == df['cat_depth']).all(), "Depth mismatch"
    # path check
    assert ((df['category_path'].str.count(r'\|').fillna(0).astype(int) + 1) 
            == df['cat_depth']).all(), "Path mismatch with depth"
    print("All quality checks passed ✅")
    return df

# deduplicate function
def deduplicate_products(df):
    """Removes duplicate product_id rows keeping the one with highest rating count and rating."""
    df = (df.sort_values(['product_id', 'rating_count', 'rating'], ascending=[True, False, False])
          .drop_duplicates('product_id', keep='first'))
    assert not df['product_id'].duplicated().any(), "Duplicates remain!"
    return df

# Prepare Tables to Load them on Database
# build dim_category table function
def build_dim_category(df):
    level_cols = [c for c in df.columns if c.startswith('cat_l')]
    dim_category = (df[['category_path', 'cat_leaf', 'cat_depth'] + level_cols]
                    .drop_duplicates('category_path')
                    .reset_index(drop=True))
    dim_category['category_key'] = range(1, len(dim_category) + 1)
    dim_category = dim_category.loc[:, ~dim_category.columns.duplicated()].copy()
    return dim_category

# build dim_product table function
def build_dim_product(df):
    columns = ['product_id', 'product_name', 'img_link', 'product_link', 'cat_leaf']
    dim_product = df[columns].copy()
    return dim_product

# build bridge_product_category table function
def build_bridge_product_category(df, dim_category):
    bridge = (df[['product_id', 'category_path']]
              .merge(dim_category[['category_path', 'category_key']],
                     on='category_path', how='left'))
    return bridge[['product_id', 'category_key']]

# build fact_product_snapshot table function
def build_fact_product_snapshot(df, bridge):
    fact = df[['product_id', 'discounted_price', 'actual_price', 'discount_percentage', 'rating', 'rating_count']].copy()
    fact = fact.merge(bridge, on='product_id', how='left')
    fact['ingestion_date'] = date.today()
    return fact

# main function
def main():
    filepath = "../data/row/amazon.csv"
    
    # load and clean the data
    sales_data = load_data(filepath)
    sales_data = clean_price_columns(sales_data)
    sales_data = clean_rating_columns(sales_data)
    sales_data = process_categories(sales_data)
    
    # cheack the quality and remove duplicates
    sales_data = run_quality_checks(sales_data)
    sales_data = deduplicate_products(sales_data)
    
    # build new tables
    dim_category = build_dim_category(sales_data)
    dim_product = build_dim_product(sales_data)
    bridge = build_bridge_product_category(sales_data, dim_category)
    fact_snapshot = build_fact_product_snapshot(sales_data, bridge)
    
    # print new tables head
    print("\\n=== Dim Category ===")
    print(dim_category.head())
    print(f"Shape: {dim_category.shape}")
    
    print("\\n=== Dim Product ===")
    print(dim_product.head())
    print(f"Shape: {dim_product.shape}")
    
    print("\\n=== Bridge Table ===")
    print(bridge.head())
    print(f"Shape: {bridge.shape}")
    
    print("\\n=== Fact Snapshot ===")
    print(fact_snapshot.head())
    print(f"Shape: {fact_snapshot.shape}")
    
    # save new tables
    dim_product.to_csv('../data/processed/dim_product.csv', index=False)
    dim_category.to_csv('../data/processed/dim_category.csv', index=False)
    fact_snapshot.to_csv('../data/processed/fact_product_snapshot.csv', index=False)
    bridge.to_csv('../data/processed/bridge_product_category.csv', index=False)
    
    print("\\n✅ All tables saved successfully!")
    
    return sales_data, dim_category, dim_product, bridge, fact_snapshot

if __name__ == "__main__":
    sales_data, dim_category, dim_product, bridge, fact_snapshot = main()