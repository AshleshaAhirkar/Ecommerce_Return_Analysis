--PHASE 1 — DATABASE SETUP

--STEP 1 — Create Database

--STEP 2 — Create Schema
create schema ecommerce;

--STEP 3 — Create Table
create table ecommerce.online_retail(
InvoiceNo varchar(20),
StockCode varchar(20),
Description text,	
Quantity integer,
InvoiceDate	timestamp,
UnitPrice numeric(10,2),
CustomerID numeric,
Country varchar(50)
);

--PHASE 2 — IMPORT CSV
select * from ecommerce.online_retail;

--PHASE 3 — DATA CLEANING

--STEP 1 — Check Total Records
select count(*) from ecommerce.online_retail;

--STEP 2 — Check Null Values --->found 1 lakh + null customer_id-->remove it 
select *
from ecommerce.online_retail
where customerid is null;

--STEP 3 — Check Duplicate Rows--->dupliactes are present -->remove that
select invoiceno,
stockcode,
description,
quantity,
invoicedate,
unitprice,
customeriD,
country, count(*)
from ecommerce.online_retail
group by invoiceno,
stockcode,
description,
quantity,
invoicedate,
unitprice,
customeriD,
country
having count(*)>1;

--STEP 4 - Check invalid prices
select *
from ecommerce.online_retail
where unitprice<=0;

-- STEP 5 - Check invalid quantity
select * 
from ecommerce.online_retail
where quantity<=0;

-- STEP 6 - Check description is null
select * 
from ecommerce.online_retail
where description is null;

--Step 7 - Check cancelled product
select * 
from ecommerce.online_retail
where invoiceno like 'C%';

--STEP 8 - create cleaned dataset

create table ecommerce.cleaned_retail as
select distinct
invoiceno,stockcode,
description,quantity,
invoicedate,unitprice,
customerid,country,
case 
  when invoiceno like 'C%' then 'Returned'
  else 'Purchased'
 end as order_status,
 (quantity*unitprice) as total_amount
 from ecommerce.online_retail
 where customerid is not null
 and description is not null
 and unitprice>0;

 select * from ecommerce.cleaned_retail;

--PHASE 4 — Validation Checks
--STEP 1 — Total Records
select count(*) 
from ecommerce.cleaned_retail;

--STEP 2 — Check Null CustomerID
select *
from ecommerce.cleaned_retail
where customerid is null;

--STEP 3 — Check Null Description
select *
from ecommerce.cleaned_retail
where description is null;

--STEP 4 — Check Invalid Prices
select * 
from ecommerce.cleaned_retail
where unitprice<=0;

--STEP 5 — Check Duplicate Rows 
select invoiceno,
stockcode,
description,
quantity,
invoicedate,
unitprice,
customeriD,
country,count(*)
from ecommerce.cleaned_retail
group by invoiceno,
stockcode,
description,
quantity,
invoicedate,
unitprice,
customeriD,
country
having count(*)>1;

--STEP 6 — Verify Return Flag
select distinct order_status
from ecommerce.cleaned_retail;

--STEP 7 — Check Returned Orders Count
select *
from ecommerce.cleaned_retail
where order_status='Returned';

--PHASE 5 — COLUMN STANDARDIZATION --->Renaming column haeders for butter readiability
alter table ecommerce.cleaned_retail
rename column invoiceno to invoice_no;

alter table ecommerce.cleaned_retail
rename column stockcode to stock_code;

alter table ecommerce.cleaned_retail
rename column unitprice to unit_price;

alter table ecommerce.cleaned_retail
rename column customerid to customer_id;

alter table ecommerce.cleaned_retail
rename column invoicedate to invoice_date;


select * from ecommerce.cleaned_retail;


--PHASE 6 — EXPLORATORY ANALYSIS

--Total Revenue
select sum(total_amount)
from ecommerce.cleaned_retail
where order_status='Purchased';

--Total Refund Loss
select sum(abs(total_amount))
from ecommerce.cleaned_retail
where order_status='Returned';

--Total Customers
select count(distinct customer_id)
from ecommerce.cleaned_retail;


--PHASE 7 — CUSTOMER RETURN ANALYSIS

--count all customers, count purchased, count returned, return ratio

select customer_id,count(*) as total_transactions,
count(case when order_status='Purchased' then 1 end) as total_purchases,
count(case when order_status='Returned' then 1 end) as total_returns,
round(count(case when order_status='Returned' then 1 end)::numeric/nullif(count(case when order_status='Purchased' then 1 end),0),3) as return_ratio
from ecommerce.cleaned_retail
group by customer_id
order by customer_id;

with cte as(
select customer_id,count(*) as total_transactions,
count(case when order_status='Purchased' then 1 end) as total_purchases,
count(case when order_status='Returned' then 1 end) as total_returns,
round(count(case when order_status='Returned' then 1 end)::numeric/nullif(count(case when order_status='Purchased' then 1 end),0),3) as return_ratio
from ecommerce.cleaned_retail
group by customer_id
order by customer_id
)
select customer_id,total_transactions,total_purchases,total_returns,return_ratio
from cte 
where return_ratio>0.5
order by return_ratio desc; 


--PHASE 8 — HIGH-RISK CUSTOMERS
with cte1 as(
select customer_id,count(*) as total_transactions,
count(case when order_status='Purchased' then 1 end) as total_purchases,
count(case when order_status='Returned' then 1 end) as total_returns,
coalesce(
round(count(case when order_status='Returned' then 1 end)::numeric/nullif(count(case when order_status='Purchased' then 1 end),0),3) ---niche isme count(*) kiya hai 
,0) as return_ratio
from ecommerce.cleaned_retail
group by customer_id
order by customer_id
)
select *,
case 
when total_purchases=0 and total_returns>0 then 'High Risk'
when total_returns>10 and return_ratio>1 then 'High Risk'
when total_returns>5 and return_ratio>0.5 then 'Medium Risk'
else 'Low Risk'
end as risk_category
from cte1
order by risk_category, return_ratio desc;

--PHASE 9 - PRODUCT RETURN ANALYSIS --Most Returned Products

select distinct stock_code,description
from ecommerce.cleaned_retail
group by stock_code,description;

select stock_code,description,count(*) as cnt
from ecommerce.cleaned_retail
group by stock_code,description
having count(*)>=1
order by cnt desc


----
select stock_code,description,count(*) as total_returns,abs(sum(total_amount)) as refund_loss
from ecommerce.cleaned_retail
where order_status='Returned' and stock_code not in('POST','M','D','CRUK')
group by stock_code,description 
order by refund_loss desc;

select * 
from ecommerce.cleaned_retail
where stock_code='23843'                  ------return 1 hai par quantity bahut thi isliye sabh se jada loss produce kar ra

----
--------------       phase 11 solve karne ke baad is wale query ko order by return karne ka idea aaya
---correct query
SELECT stock_code,description,COUNT(*) AS total_returns,ABS(SUM(total_amount)) AS refund_loss
FROM ecommerce.cleaned_retail
WHERE order_status='Returned'
AND stock_code NOT IN ('POST','M','D','CRUK')
GROUP BY stock_code,description
ORDER BY total_returns DESC,refund_loss DESC;

--PHASE 10 — COUNTRY ANALYSIS
select country,count(*) as total_returns,abs(sum(total_amount)) as refund_loss
from ecommerce.cleaned_retail
where order_status='Returned' and stock_code not in('POST','M','D','CRUK')
group by country
order by refund_loss desc;

--PHASE 11 — ADVANCED SQL -- Rank High-Risk Customers
select *
from(
select customer_id,count(*) as total_returns, abs(sum(total_amount)) as refund_loss,
dense_rank() over(order by abs(sum(total_amount)) desc) as rnk
from ecommerce.cleaned_retail
where order_status='Returned'
group by customer_id
)
---previous mai ek bada outlier aara tha ..isliye niche wale mai order by count(*) bhi kar loya...abh retuen aur total ke according ranking hogi
select *
from(
select customer_id,count(*) as total_returns, abs(sum(total_amount)) as refund_loss,
dense_rank() over(order by count(*) desc,abs(sum(total_amount)) desc) as rnk
from ecommerce.cleaned_retail
where order_status='Returned'
group by customer_id
)

--clean query
select
    customer_id,
    count(*) as total_returns,
    abs(sum(total_amount)) as refund_loss,
    dense_rank() over(
        order by count(*) desc,
        abs(sum(total_amount)) desc
    ) as rnk
from ecommerce.cleaned_retail
where order_status='Returned'
group by customer_id
order by rnk;

---upar wale mai anamoly hai ..outlier kind of hai..isliye niche wale mai ek consition add ki hai...but not related to outlier
-- select *
-- from(
-- select customer_id,count(*) as total_returns, abs(sum(total_amount)) as refund_loss,
-- dense_rank() over(order by count(*) desc,abs(sum(total_amount)) desc) as rnk
-- from ecommerce.cleaned_retail
-- where order_status='Returned'
-- group by customer_id
-- having count(*)>5
-- )

--PHASE 12 — MONTHLY FRAUD TREND
select distinct(extract(year from invoice_date))
from ecommerce.cleaned_retail

-- select extract(year from invoice_date)as year,extract(month from invoice_date) as month,count(*) as total_returns, abs(sum(total_amount)) as refund_loss
-- from ecommerce.cleaned_retail
-- where order_status='Returned'
-- group by extract(year from invoice_date),extract(month from invoice_date)
-- order by year,month

--
select extract(year from invoice_date)as year,to_char(invoice_date,'Mon') as month,count(*) as total_returns, abs(sum(total_amount)) as refund_loss
from ecommerce.cleaned_retail
where order_status='Returned'
group by extract(year from invoice_date),extract(month from invoice_date), to_char(invoice_date,'Mon')
order by year,extract(month from invoice_date)

--PHASE 13 — CREATE POWER BI VIEWS


-----------------------------------------------------------
--create customer risk table  (needed for power bi visuals)

-- create table customer_risk_analysis as ---schema mention nahi kiya isliye public isme craete hua
-- with cte1 as(
-- select customer_id,count(*) as total_transactions,
-- count(case when order_status='Purchased' then 1 end) as total_purchases,
-- count(case when order_status='Returned' then 1 end) as total_returns,
-- coalesce(
-- round(count(case when order_status='Returned' then 1 end)::numeric/nullif(count(case when order_status='Purchased' then 1 end),0),3) 
-- ,0) as return_ratio
-- from ecommerce.cleaned_retail
-- group by customer_id
-- order by customer_id
-- )
-- select *,
-- case 
-- when total_purchases=0 and total_returns>0 then 'High Risk'
-- when total_returns>10 and return_ratio>1 then 'High Risk'
-- when total_returns>5 and return_ratio>0.5 then 'Medium Risk'
-- else 'Low Risk'
-- end as risk_category
-- from cte1
-- order by risk_category, return_ratio desc;

-- select * from customer_risk_analysis;
-- ----
-- select schemaname, tablename
-- from pg_tables
-- where tablename='customer_risk_analysis';

-- ----
-- create table ecommerce.customer_risk_analysis as 
-- with cte1 as(
-- select customer_id,count(*) as total_transactions,
-- count(case when order_status='Purchased' then 1 end) as total_purchases,
-- count(case when order_status='Returned' then 1 end) as total_returns,
-- coalesce(
-- round(count(case when order_status='Returned' then 1 end)::numeric/nullif(count(case when order_status='Purchased' then 1 end),0),3) 
-- ,0) as return_ratio
-- from ecommerce.cleaned_retail
-- group by customer_id
-- order by customer_id
-- )
-- select *,
-- case 
-- when total_purchases=0 and total_returns>0 then 'High Risk'
-- when total_returns>10 and return_ratio>1 then 'High Risk'
-- when total_returns>5 and return_ratio>0.5 then 'Medium Risk'
-- else 'Low Risk'
-- end as risk_category
-- from cte1
-- order by risk_category, return_ratio desc;

-- select * from customer_risk_analysis;

-- ----
-- drop table ecommerce.customer_risk_analysis;  --donut analysis barabar nahi aara tha ...isliye case change kiya

-- ---
--  create table ecommerce.customer_risk_analysis as 
--  with cte1 as(
--  select customer_id,count(*) as total_transactions,
--  count(case when order_status='Purchased' then 1 end) as total_purchases,
--  count(case when order_status='Returned' then 1 end) as total_returns,
--  coalesce(
--  round(count(case when order_status='Returned' then 1 end)::numeric/nullif(count(case when order_status='Purchased' then 1 end),0),3) 
--  ,0) as return_ratio
--  from ecommerce.cleaned_retail
--  group by customer_id
--  order by customer_id
-- )
--  select *,
--  case
--  when total_returns >= 5
--  and return_ratio >= 0.5
--  then 'High Risk'

--  when total_returns >= 2
--  and return_ratio >= 0.2
--  then 'Medium Risk'

--  else 'Low Risk'

--  end as risk_category
--  from cte1
--  order by risk_category, return_ratio desc;

-- select * from ecommerce.customer_risk_analysis;

--upar wala nahi bana re donut chart ..barabar nahi ban ra

---------------------------------
drop table ecommerce.customer_risk_analysis;

-- create table ecommerce.customer_risk_analysis as 
-- with cte1 as(
-- select customer_id,count(*) as total_transactions,
-- count(case when order_status='Purchased' then 1 end) as total_purchases,
-- count(case when order_status='Returned' then 1 end) as total_returns,
-- coalesce(
-- round(count(case when order_status='Returned' then 1 end)::numeric/nullif(count(*),0),3)   ----dive by count(*) ...changes made
-- ,0) as return_ratio
-- from ecommerce.cleaned_retail
-- group by customer_id
-- order by customer_id
-- )
-- select *,
-- case 
-- when total_purchases=0 and total_returns>0 then 'High Risk'
-- when total_returns>10 and return_ratio>1 then 'High Risk'
-- when total_returns>5 and return_ratio>0.5 then 'Medium Risk'
-- else 'Low Risk'
-- end as risk_category
-- from cte1
-- order by risk_category, return_ratio desc;

-- select * from ecommerce.customer_risk_analysis;

--upar wale se table mai bhi issue aayega

--------------
drop table ecommerce.customer_risk_analysis;

  create table ecommerce.customer_risk_analysis as 
  with cte1 as(
  select customer_id,count(*) as total_transactions,
  count(case when order_status='Purchased' then 1 end) as total_purchases,
  count(case when order_status='Returned' then 1 end) as total_returns,
  coalesce(
  round(count(case when order_status='Returned' then 1 end)::numeric/nullif(count(*),0),3) 
  ,0) as return_ratio
  from ecommerce.cleaned_retail
  group by customer_id
  order by customer_id
  )
  select *,
  case
  when total_returns >= 5
  and return_ratio >= 0.5
  then 'High Risk'

  when total_returns >= 2
  and return_ratio >= 0.2
  then 'Medium Risk'

  else 'Low Risk'

  end as risk_category
  from cte1
  order by risk_category, return_ratio desc;

select * from ecommerce.customer_risk_analysis;

---------------------------------------


