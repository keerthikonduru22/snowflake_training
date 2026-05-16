-------creating three warehouses---------
create or replace warehouse marketing_wh
WITH WAREHOUSE_SIZE = 'XSMALL'
WAREHOUSE_TYPE = 'STANDARD' 
AUTO_SUSPEND = 60
AUTO_RESUME = TRUE 
MIN_CLUSTER_COUNT = 1 
MAX_CLUSTER_COUNT = 1;

create or replace warehouse finance_wh
WITH WAREHOUSE_SIZE = 'XSMALL'
WAREHOUSE_TYPE = 'STANDARD' 
AUTO_SUSPEND = 60
AUTO_RESUME = TRUE 
MIN_CLUSTER_COUNT = 1 
MAX_CLUSTER_COUNT = 1;

create or replace warehouse elt_wh
WITH WAREHOUSE_SIZE = 'SMALL'
WAREHOUSE_TYPE = 'STANDARD' 
AUTO_SUSPEND = 60
AUTO_RESUME = TRUE 
MIN_CLUSTER_COUNT = 1 
MAX_CLUSTER_COUNT = 1;
----------assigning roles---------

CREATE ROLE marketing_analyst;
GRANT USAGE ON WAREHOUSE marketing_wh TO ROLE marketing_analyst;

CREATE ROLE finance_user;
GRANT USAGE ON WAREHOUSE finance_wh TO ROLE finance_user;

CREATE ROLE etl_developer;
GRANT USAGE ON WAREHOUSE elt_wh TO ROLE etl_developer;

-----creating users---------------

CREATE USER mkt_user1 PASSWORD = 'mkt' LOGIN_NAME = 'mkt_user' DEFAULT_ROLE='marketing_analyst' DEFAULT_WAREHOUSE = 'marketing_wh'  MUST_CHANGE_PASSWORD = FALSE;
CREATE USER fin_user1 PASSWORD = 'fin' LOGIN_NAME = 'fin_user' DEFAULT_ROLE='finance_user' DEFAULT_WAREHOUSE = 'finance_wh'  MUST_CHANGE_PASSWORD = FALSE;
CREATE USER etl_user1 PASSWORD = 'etl' LOGIN_NAME = 'etl_user' DEFAULT_ROLE='etl_developer' DEFAULT_WAREHOUSE = 'elt_wh'  MUST_CHANGE_PASSWORD = FALSE;

GRANT ROLE marketing_analyst TO USER mkt_user1;
GRANT ROLE finance_user TO USER fin_user1;
GRANT ROLE etl_developer TO USER etl_user1;

--------------------creating database and tables-------------------

create or replace database retail_marketing_db;

use retail_marketing_db;

create or replace schema public;

use schema public;
-- select * from snowflake_sample_data.tpcds_sf10tcl.customer limit 2;
-- select * from snowflake_sample_data.tpcds_sf10tcl.date_dim limit 2;
-- select * from snowflake_sample_data.tpcds_sf10tcl.store_sales limit 2;
-- select * from snowflake_sample_data.tpcds_sf10tcl.item limit 2;

create or replace table campaign_sales as
select c.C_CUSTOMER_SK AS ID,
c.C_CUSTOMER_ID AS CUSTOMER_ID,
c.C_FIRST_NAME AS FIRST_NAME,
c.C_LAST_NAME AS LAST_NAME,
s.ss_item_sk AS item_id,
s.ss_sold_date_sk AS SOLD_sk,
s.ss_sold_time_sk AS SOLD_time_sk,
s.SS_QUANTITY AS QUANTITY,
s.ss_sales_price AS PRICE,
s.ss_ticket_number AS TICKET_NO,
d.d_date as date,
i.i_product_name as product_name,
i.i_category as category,
i.i_class as product_class
FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.STORE_SALES s
JOIN SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER c
    ON s.ss_customer_sk = c.c_customer_sk
JOIN SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.DATE_DIM d
    ON s.ss_sold_date_sk = d.d_date_sk
JOIN SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.ITEM i
    ON s.ss_item_sk = i.i_item_sk limit 1000000000;

-- DROP TABLE CAMPAIGN_SALES;
----------------------grant permissions------------

GRANT USAGE ON DATABASE retail_marketing_db TO ROLE marketing_analyst;
GRANT USAGE ON DATABASE retail_marketing_db TO ROLE finance_user;
GRANT USAGE ON DATABASE retail_marketing_db TO ROLE etl_developer;

GRANT USAGE ON SCHEMA public TO ROLE marketing_analyst;
GRANT USAGE ON SCHEMA public TO ROLE finance_user;
GRANT USAGE ON SCHEMA public TO ROLE etl_developer;


GRANT SELECT ON TABLE campaign_sales TO ROLE marketing_analyst;
GRANT SELECT ON TABLE campaign_sales  TO ROLE finance_user;

GRANT INSERT,UPDATE,SELECT,DELETE ON TABLE campaign_sales TO ROLE etl_developer;

show grants to role marketing_analyst;
show grants to role finance_user;
show grants to role etl_developer;


---------------performance testing----------------
use warehouse marketing_wh;

-- select * from campaign_sales limit 2;

-- select count(*) as products_count,CATEGORY from campaign_sales group by CATEGORY
-- order by products_count;

select customer_id,first_name,sum(price) from campaign_sales group by customer_id,first_name;

select * from campaign_sales;

alter warehouse marketing_wh set warehouse_size = 'small';

select * from campaign_sales; 

-- select * from campaign_sales limit 100;

alter warehouse marketing_wh set warehouse_size = 'xsmall';



--------------------catche testing---------------

select customer_id,first_name,last_name,item_id,sold_sk,price,date,product_name from campaign_sales order by date;

select customer_id,first_name,last_name,item_id,sold_sk,price,date,product_name from campaign_sales order by date;

---------------------cluster key -----------------------------
select date,sum(price) as total_price,count(item_id) as count_products,count(customer_id) as count_customers from campaign_sales group by date order by date;

select date,price,item_id,customer_id
from campaign_sales where date = '2000-10-15';


alter table campaign_sales cluster by (date);

select date,price,item_id,customer_id
from campaign_sales where date = '2000-12-27';


select date,sum(price) as total_price,count(item_id) as count_products,count(customer_id) as count_customers from campaign_sales group by date order by date;



