
/* PART ZERO: Loading the data into tables*/

-- Creating tables here and using different names for field names that would interfere with SQL keywords. For example 'id' -> 'id_key'
Drop table if exists Users_T;
Create table Users_T (
    id_key varchar(255),
    created_date datetime,
    birth_date datetime,
    state_acro varchar(2),
    language_field varchar(255),
    gender varchar(255));

-- I had to change the type of the barcode field to bigint because I was getting errors inserting the data when I used int as the datatype
Drop table if exists Products_T;
Create table Products_T (
    category_1 varchar(255),
	category_2 varchar(255),    
	category_3 varchar(255),
	category_4 varchar(255),
	manufacturer varchar(255),
	brand varchar(255),
	barcode bigint);

-- I had to change the datatype for quantity as well because I noticed several 'zero' text entries in the csv
Drop table if exists Transactions_T;
Create table Transactions_T (
    receipt_id varchar(255),
    purchase_date datetime,
    scan_date datetime,
    store_name varchar(255),
	user_id_fk varchar(255),    
	barcode_fk bigint,
	quantity varchar(255),
	sale float);

--Inserting data from the csv's into the tables
BULK INSERT Users_T
FROM 'C:\data\USER_TAKEHOME.csv'
WITH (
	FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2
);

BULK INSERT Products_T
FROM 'C:\data\PRODUCTS_TAKEHOME.csv'
WITH (
	FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2
);

BULK INSERT Transactions_T
FROM 'C:\data\TRANSACTION_TAKEHOME.csv'
WITH (
	FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2
);

/* PART ONE: Explore the Data*/
/* Data quality issues: Users table */

-- At first look, there are sporadic NULL values in the birth_date, state_acro, language_field, and gender fields
select * from Users_T

-- The lanuguage_field has the most nulls by far at 30508, compared to 3675 for birth_date, 4812 for state_acro, and 5892 for gender
select 
	SUM(case when birth_date is null then 1 else 0 end) birth_date_nulls,
	SUM(case when state_acro is null then 1 else 0 end) state_acro_nulls,
	SUM(case when language_field is null then 1 else 0 end) language_field_nulls,
	SUM(case when gender is null then 1 else 0 end) gender_nulls
from Users_T

-- Checking to make sure there are no unusual state values, but this returns 53 rows including NULL, so it seems to be as expected
select distinct state_acro from Users_T

-- Inconsistent that the structure of entries is either a 2 character string, presumably for English, or a 2 character string with '-419' appended for Spanish. 
-- Also unusual that there are only 2 languages and NULL entries for 100000 users
select distinct language_field from Users_T

--Ensuring that there are no duplicate primary keys in the User table, and there are not
select distinct id_key from Users_T

-- This table is used to create Graph A in the Python code and graph references
-- Looking at the graph, it's possible that the data isn't comprehensive for the full date range starting in April 2014 because
-- the quantity of new users is so low between April 2014 and June 2017 compared to the rest of the months. This may not be invalid data, 
-- but it would be worth investigating further.
Select 
	CONCAT(YEAR(created_date), '-', 
		FORMAT(MONTH(created_date), '00')) YearMonth, 
	COUNT(id_key) NewUsers
into UsersByMonth
from Users_T
Group By CONCAT(YEAR(created_date), '-', FORMAT(MONTH(created_date), '00'))
Order By CONCAT(YEAR(created_date), '-', FORMAT(MONTH(created_date), '00')) asc

/* Data quality issues: Products table */

-- I assumed that the nulls in the category fields are intentional to denote products that do not have 4 different categories
-- There are also nulls in manufacturer and brand fields, but the most alarming is the nulls in the primary key barcode field
select * from Products_T

-- There are 4025 total rows with null primary key barcode fields, as well as 226474 rows with a null manufacturer field and 226472 rows with
-- a null brand field. Looking at the table using the previous query, it seems that nearly every row that has a null manufacturer field also
-- has a null brand field, which could help debug the cause of this data quality issue
select 
	SUM(case when manufacturer is null then 1 else 0 end) manufacturer_nulls,
	SUM(case when brand is null then 1 else 0 end) brand_nulls,
	SUM(case when barcode is null then 1 else 0 end) barcode_nulls
from Products_T

-- There doesn't seem to be anything unusual about the only 2 rows that have a populated brand field but a null manufacturer,
-- other than both rows have the same brand and some matching categories
select * from Products_T
where manufacturer is null
and brand is not null

-- Looking at the table, I noticed that there were some instances of rows with an entry in the manufacturer field of
-- 'NONE' or 'PLACEHOLDER MANUFACTURER', which I assume are invalid entries like the nulls. This is a widespread issue
-- 4835 rows having 'NONE' and 86902 rows having 'PLACEHOLDER MANUFACTURER' in the manufacturer field. There could also be other
-- invalid text entries like these, but there are 4355 distinct manufacturer fields in the data, which is too many to validate manually
select manufacturer, COUNT(*) num_rows from Products_T
where manufacturer in ('placeholder manufacturer', 'none')
group by manufacturer

select distinct manufacturer from Products_T

/* Data quality issues: Transactions table */

-- There are nulls in the barcode_fk and sale fields
select * from Transactions_T

-- There are 5762 rows where the barcode_fk field is null, and 12500 rows where the sale field is null. It seems unusual that exactly 
-- one quarter of the rows in the data set have a null sale field
select 
	SUM(case when barcode_fk is null then 1 else 0 end) barcode_fk_nulls,
	SUM(case when sale is null then 1 else 0 end) sale_nulls
from Transactions_T

-- Besides the 'zero' text entries into the quantity field, its surprising to see so many entries that have decimal entries, as well
-- as the outlier quantity 276.00, but for thsi exercise I assumed that the outlier and decimal quantity entries were all valid
select distinct quantity from Transactions_T
order by quantity desc

-- There are 19408 records in the transaction table with a barcode_fk value that doesn't exist in the Products_T table. This means that the 
-- Products_T table is likely incomplete and missing data
select * from Transactions_T
where barcode_fk not in (select distinct barcode from Products_T where barcode is not null)

-- There are only 24440 distinct rows in the table despite 50000 total rows
select distinct receipt_id from Transactions_T

-- All of the receipt_ids in the table have at least one duplicate, and all of the duplicate quantities are multiples of two. This information
-- combined with the number of distinct ids being about half of the number of total records indicates that this table most likely needs to be deduped
select receipt_id, count(receipt_id) receipt_dups
from Transactions_T
group by receipt_id
order by COUNT(receipt_id) desc

-- Using this query to look at each pair or more of matching receipt ids, it seems that in almost every case, each pair of receipt_ids
-- has data that matches exactly except for a null in the sale field or a 'zero' in the quantity field
select * from Transactions_T order by  receipt_id

-- I'm assuming that the duplicate receipt_ids need to be deduped by removing the row in the pair that either has a 'zero' quantity
-- or a null sale value, and this query confirms that doing so will reduce the number of rows to 25000, which is close to the number of
-- unique receipt ids above. Next I'll look at some examples of receipt_ids that have more than 2 duplicates
select *
from Transactions_T
where quantity != 'zero'
and sale is not null

-- From this query I can see that the receipt_ids that have more than one duplicate have similar patterns where there is a
-- 'zero' in the quantity field or a null in the sale field, but they also have some rows that are exact duplicates with every field
-- matching. I assume that these fully duplicate entries should also be deduped from the table.
select * from Transactions_T 
where receipt_id in (
	'bedac253-2256-461b-96af-267748e6cecf',
	'bc304cd7-8353-4142-ac7f-f3ccec720cb3',
	'760c98da-5174-401f-a203-b839c4d406be',
	'4ec870d2-c39f-4a40-bf8a-26a079409b20')
order by  receipt_id

--First I'm deleting rows with invalid quantity and sale values
delete from Transactions_T 
where (quantity = 'zero' or sale is null)

-- Then I'm deleting the rows that still have duplicates by creating a modified version of the table. This modified table
--uses the row_number function to differentiate the duplicate rows and only select one of them into the new table
with TransactionRows as (
    select receipt_id, purchase_date, scan_date, store_name, user_id_fk, barcode_fk, quantity, sale,
           ROW_NUMBER() over (partition by receipt_id, purchase_date, scan_date, store_name, user_id_fk, barcode_fk order by receipt_id) as rownum
    from Transactions_T 
)
select * into ModTransactions_T
from TransactionRows
where rownum < 2

-- In the next two queries, I'm pulling some examples of rows that still have duplicate receipt_ids, and it looks like these
-- are cases where different products with different sale values were purchased simultaneously, so I'm assuming these rows are valid
select receipt_id, count(receipt_id) receipt_dups
from ModTransactions_T
group by receipt_id
order by COUNT(receipt_id) desc

select * from ModTransactions_T
where receipt_id in (
	'0fb89572-c817-47e2-bd11-6f467baacbb2',
	'79151f8d-0b75-48e2-8bb4-2591bc8c9ca2',
	'edff1028-0b81-425f-b22c-8f08a17ae564',
	'f3e89a5d-8908-46b7-b1c3-aac775bac313')

-- In this query I'm looking at the difference in hours between purchase_date and scan_date for the remaining transactions. It's unclear
-- why the time difference is so large (hundreds of hours) for many transactions, and why many transactions have scan_date's that preceed
-- purchase dates, but because I don't fully understandthe meaning of these fields, I'm assuming that this doesn't invalidate any of the data
select *, DATEDIFF(hour, purchase_date, scan_date)
from ModTransactions_T
order by DATEDIFF(hour, purchase_date, scan_date) desc

-- This query shows that only 91 user_ids in the modified Transaction table match to user_ids in the Users_T dimension table. This is a glaring data quality issue
select * from Users_T where id_key in (select user_id_fk from ModTransactions_T where user_id_fk is not null)


-- This table is used to create Graph B in the Python code and graph references
-- Looking at the graph, there don't seem to be any data quality issues, but it's worth noting that the Transactions data only encompasses June to September 2024.
-- I assumed the scan dat was more relevant to use here than the purchase date, because the scan date reflects when the users engaged with Fetch
Select 
	CONCAT(YEAR(scan_date), '-', 
		FORMAT(MONTH(scan_date), '00')) YearMonth, 
	COUNT(distinct receipt_id) Transactions
into TransactionsByMonth
from ModTransactions_T
Group By CONCAT(YEAR(scan_date), '-', FORMAT(MONTH(scan_date), '00'))
Order By CONCAT(YEAR(scan_date), '-', FORMAT(MONTH(scan_date), '00')) asc

-- This table is used to create Graph C in the Python code and graph references
-- I assumed that category_1 was the broadest category, so it would be the most relevant here. I also filtered out prducts where category_1 was null and transactions
-- where the barcode did not exist in the Products_T dimension table.
-- Looking at the graph, there are outliers including a very high rate of transactions in the Snacks cateogry, and only one in the Produce category
Select 
	category_1 maincategory, 
	COUNT(distinct receipt_id) Transactions
into TransactionsByProduct
from ModTransactions_T
left join Products_T on ModTransactions_T.barcode_fk = Products_T.barcode
where Products_T.category_1 is not null
and ModTransactions_T.barcode_fk in (select distinct barcode from Products_T)
Group By category_1


/* Diffcult to understand fields: */
-- In the Transaction table, I assumed that the quantity field represented the quantiy of a product purchased in the transaction,
-- and that the sale field represents the price per unit for the transaction, but its challenging to understand why there are
-- so many transactions that have a quantity of 'zero' and what those entries represent. I ended up assuming that those entries 
-- were invalid, but its unclear what might have caused the data to come through in this format.

-- I also assumed that the purchase_date and scan_date fields in the Transaction table represent when a customer bought a product and
-- when they subsequently scanned the product to register it with Fetch, but it's unclear why there are both many transactions
-- where the gap between purchase date and scan date is hundreds of hours, and why there are many transactions where the 
-- product was scanned before it was purchased


/* PART TWO: Provde specific SQL queries*/
/* What are the top 5 brands by receipts scanned among users 21 and over? */

-- The query below shows that Dove, Nerds Candy, Trident, Great Value, and Coca-Cola are the top 5 brands matching this criteria, but note
-- that the criteria have severely limited the data that can be retrieved because as mentioned above, there are only 91 user_ids in the User_T
-- dimension table that match to a user_id in the Transactions table, so only those 91 users can be validated to be 21 years old or older.
-- As a result, the top brands by receipts scanned only have 3 receipts scanned each

select top 5 brand, count(distinct receipt_id) receipts_scanned
from ModTransactions_T
left join Products_T on ModTransactions_T.barcode_fk = Products_T.barcode
left join Users_T on ModTransactions_T.user_id_fk = Users_T.id_key
where Datediff(year, Users_T.birth_date, SYSDATETIME()) >= 21
and brand is not null
group by brand
order by count(distinct receipt_id) desc

/* What are the top 5 brands by sales among users that have had their account for at least six months? */

-- The query below shows that CVS, Dove, TRESEMM+ë, Trident, and Coors Light have the highest sales from users with accounts that are at least 6 months
-- old. Similarly to the previous query, the sample of data that this query reflects is severely limited by the connection to the Users_T table

select top 5 brand, sum(quantity * sale) sale_sum
from ModTransactions_T
left join Products_T on ModTransactions_T.barcode_fk = Products_T.barcode
left join Users_T on ModTransactions_T.user_id_fk = Users_T.id_key
where Datediff(month, Users_T.created_date, SYSDATETIME()) >= 6
and brand is not null
group by brand
order by sum(quantity * sale) desc

/* Which is the leading brand in the Dips & Salsa category? */

-- Based on the query below, Tostitos is the leading brand in the Dips & Salsa category. Tostitos has the highest total sale value (quantity * sale) at 197.24,
-- more than double the next highest brand, Good Foods. Tostitos also has the highest amount of receipts scanned at 36
select brand, sum(quantity * sale) sale_sum, count(distinct receipt_id) receipts_scanned
from ModTransactions_T
left join Products_T on ModTransactions_T.barcode_fk = Products_T.barcode
where brand is not null
and category_2 = 'Dips & Salsa'
group by brand
order by sum(quantity * sale) desc


/* PART THREE: Communicate with stakeholders*/

/*

Hi John,

I've finished reviewing the data that we received for the case study project, and I wanted to follow up about some of the key points that came up in my review. 

Starting with data quality, there were two significant issues in the Users and Transactions tables:
	- In the Users table, we received data pertaining to 100,000 unique users. However, of the 17,694 unique users in the Transactions data that we received,
	  only 91 of those users have a matching id in the Users table. This discrepancy is preventing us from pulling in detailed User information for the vast majority of
	  tranactions that we received data for
	- Additionally, in the Transactions table, we received data that initially contained 50,000 transaction records, but we found that all of the records in the table were
	  duplicative at least once. As a result, we deduplicated the Transactions data and pared the table down to 24,795 records

Despite the data quality issues, the most interesting trend that emerged was that the number of new users, after gradually rising and peaking in July 2022 at 3,190 in that month,
has generally declined since then, down to a low of 958 new users in February 2024. However, the trend of declining new users may also be starting to shift - In the most recent complete
months of data, July and August 2024, the number of new users per month rose again to 2,037 and 1,807 respectively.

In order to further analyze this trend and it's potential causes, it's crucial that we resolve the data desparity between the User and Transaction tables that I mentioned above.
Can you please follow up to validate that the User and Transaction data that we received are complete? If we only have User data on 91 users in the Transaction data because
we are missing some records in the user data, then the new user trends will need to be re-evaluated.

Thanks!
Sean

*/
