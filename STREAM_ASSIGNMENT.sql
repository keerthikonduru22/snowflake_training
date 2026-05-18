create or replace transient database streams_db;
create or replace schema stream_schema;

create or replace table sales_raw_staging
(
id number,
product string,
price float,
amount float,
store_id number
);
insert into sales_raw_staging values
(1,'banana',1.99,1,1),
(2,'lemon',0.99,1,1),
(3,'apple',1.79,1,2),
(4,'orange',1.89,1.89,1),
(5,'cereals',5.98,2,1);

select * from sales_raw_staging;

truncate table sales_raw_staging;
create or replace table store_table
(
store_id number,
location string,
employees number
);
insert into store_table values
(1,'chicago',33),
(2,'london',12);

select * from store_table;

create or replace table sales_final_table
as select 
s.id,
s.product,
s.price,
s.amount,
s.store_id,
st.location,
st.employees
from sales_raw_staging s join store_table st
on s.store_id = st.store_id;

select * from sales_raw_staging;
select * from store_table;
select * from sales_final_table;

-----stream implementation-------

create or replace stream sales_stream
on table sales_raw_staging;

show streams;
desc stream sales_stream;
select * from sales_stream;

--the stream is empty because the stream only capture cahnges on table after it was creted 
-- the changes which made before creating stream will not et tracked and no changes were done after stream cretion so it was seen empty-------

insert into sales_raw_staging values
(6,'mango',1.99,1,2),
(7,'garlic',0.99,1,1);

select * from sales_raw_staging;

select * from sales_stream;

---we see insert in metadata$action----------

select * from sales_raw_staging;

select * from sales_final_table;

---------no------

insert into sales_final_table
select 
s.id,
s.product,
s.price,
s.amount,
s.store_id,
st.location,
st.employees
from sales_stream s join store_table st
on s.store_id = st.store_id;

select * from sales_final_table;

--------

select * from sales_stream;

----the stream was empty because the change was added to the final table 

insert into sales_raw_staging values
(8,'paprika',4.99,1,2),
(9,'tomato',3.99,1,2);

insert into sales_final_table
select 
s.id,
s.product,
s.price,
s.amount,
s.store_id,
st.location,
st.employees
from sales_stream s join store_table st
on s.store_id = st.store_id;

--------

select * from sales_final_table;

select * from sales_raw_staging;

select * from sales_stream;

-------------9 records

select * from sales_raw_staging;

select * from sales_stream;

----------

update sales_raw_staging set product = 'potato' where id = 1;

select * from sales_raw_staging;

select * from sales_stream;


------------

merge into sales_final_table f
using 
(select
s.id,
s.product,
s.price,
s.amount,
s.store_id,
st.location,
st.employees
from sales_stream s join store_table st
on s.store_id = st.store_id where s.metadata$action='INSERT')sk
on f.id = sk.id
when matched then update set
f.product=sk.product,
f.price=sk.price,
f.amount=sk.amount,
f.store_id=sk.store_id,
f.location=sk.location,
f.employees=sk.employees

WHEN NOT MATCHED THEN INSERT
(
id,
product,
price,
amount,
store_id,
location,
employees
)
VALUES
(
    sk.id,
sk.product,
sk.price,
sk.amount,
sk.store_id,
sk.location,
sk.employees
);

select * from sales_stream;
------------yes banana changed to potato-------

update sales_raw_staging set product = 'green apple' where id = 3;

select * from sales_raw_staging;

select * from sales_stream;


------------

merge into sales_final_table f
using 
(select
s.id,
s.product,
s.price,
s.amount,
s.store_id,
st.location,
st.employees
from sales_stream s join store_table st
on s.store_id = st.store_id where s.metadata$action='INSERT')sk
on f.id = sk.id
when matched then update set
f.product=sk.product,
f.price=sk.price,
f.amount=sk.amount,
f.store_id=sk.store_id,
f.location=sk.location,
f.employees=sk.employees

WHEN NOT MATCHED THEN INSERT
(
id,
product,
price,
amount,
store_id,
location,
employees
)
VALUES
(
    sk.id,
sk.product,
sk.price,
sk.amount,
sk.store_id,
sk.location,
sk.employees
);

select * from sales_stream;

----------------------final output

select * from sales_final_table;

select * from sales_raw_staging;

select * from sales_stream;


---------------yes apple changed to green apple


