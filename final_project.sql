-----------------------part a----------
----warehouse
create or replace warehouse healthcare_wh
with
warehouse_size = 'XSMALL'
initially_suspended = TRUE
auto_suspend = 60
auto_resume = TRUE
---database
create or replace database healthcare_db;
-------schema
create or replace schema appointment_shema;
-------file format
create or replace file format csv_format
TYPE = CSV
FIELD_DELIMITER = ','
SKIP_HEADER = 1;
----internal stage
create or replace stage healthcare_stage
file_format = csv_format

-----------------------part b----------------
----scale warehouse up---
alter warehouse healthcare_wh set warehouse_size='SMALL';
-----scale down----
alter warehouse healthcare_wh set warehouse_size='XSMALL';
------suspend warehouse--
alter warehouse healthcare_wh suspend;
----resume warehouse-------
alter warehouse healthcare_wh resume;

-------------------part c----------------------

----appointment_no_show.csv was downloaded------

--------------------part d------------------

list @healthcare_stage;

------------------part e-----------------
create or replace table appointment_raw
(
PATIENTID varchar(50),
APPOINTMENTID NUMBER,
GENDER STRING,
SCHEDULEDDAY TIMESTAMP,
APPOINTMENTDAY TIMESTAMP,
AGE NUMBER,
NEIGHBOURHOOD STRING,
SCHOLARSHIP NUMBER,
HIPERTENSION NUMBER,
DIABETES NUMBER,
ALCOHOLISM NUMBER,
HANDCAP NUMBER,
SMS_RECEIVED NUMBER,
NO_SHOW STRING
);

----------part f--------
copy into appointment_raw
from @healthcare_stage
file_format = csv_format;

select * from appointment_raw limit 10;

-------------part g---------

------create final table-----------

create or replace table appointment_final
(
Patient_ID varchar(50),
Appointment_ID number,
Gender string,
Age number,
Age_group string,
Scheduled_date timestamp,
Appointment_date date,
Waiting_days number,
Neighborhood string,
Scholarship string,
Hypertension string,
Diabetes string,
Alcoholism string,
Handicap string,
SMS_received string,
No_show_status string,
Attendance_status string
);
----------------------part h--------
--------------snowpark python-----------
CREATE OR REPLACE PROCEDURE LOAD_APPOINTMENT_FINAL()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.9'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$

from snowflake.snowpark import Session
from snowflake.snowpark.functions import *

def main(session: Session):

    df = session.table("APPOINTMENT_RAW")

    transformed_df = df.select(

        col("PATIENTID").alias("Patient_ID"),

        col("APPOINTMENTID").alias("Appointment_ID"),

        col("GENDER").alias("Gender"),

        col("AGE").alias("Age"),

        when(col("AGE") < 18, "Children")
        .when((col("AGE") >= 18) & (col("AGE") <= 30), "Youth")
        .when((col("AGE") > 30) & (col("AGE") < 60), "Adults")
        .otherwise("Senior Citizens")
        .alias("Age_group"),

        col("SCHEDULEDDAY").alias("Scheduled_date"),

        to_date(col("APPOINTMENTDAY")).alias("Appointment_date"),

        datediff(
            "day",
            to_date(col("SCHEDULEDDAY")),
            to_date(col("APPOINTMENTDAY"))
        ).alias("Waiting_days"),

        col("NEIGHBOURHOOD").alias("Neighborhood"),

        when(col("SCHOLARSHIP") == 1, "Yes")
        .otherwise("No")
        .alias("Scholarship"),

        when(col("HIPERTENSION") == 1, "Yes")
        .otherwise("No")
        .alias("Hypertension"),

        when(col("DIABETES") == 1, "Yes")
        .otherwise("No")
        .alias("Diabetes"),

        when(col("ALCOHOLISM") == 1, "Yes")
        .otherwise("No")
        .alias("Alcoholism"),

        when(col("HANDCAP") >= 1, "Yes")
        .otherwise("No")
        .alias("Handicap"),

        when(col("SMS_RECEIVED") == 1, "Yes")
        .otherwise("No")
        .alias("SMS_received"),

        col("NO_SHOW").alias("No_show_status"),

        when(col("NO_SHOW") == "Yes", "Missed")
        .otherwise("Visited")
        .alias("Attendance_status")

    )

    transformed_df.write.mode("overwrite").save_as_table("APPOINTMENT_FINAL")

    return "Data Loaded Successfully"

$$;
    
call LOAD_APPOINTMENT_FINAL();

select * from appointment_final limit 10;
    
----------------------------part 9----------
---------schema creation
create or replace stream hospital_stream
on table appointment_raw;

select * from hospital_stream;

--------------------------part 10---------
--------insert new records into raw table

insert into appointment_raw values
(
'P10019999E',
10001,
'F',
'2024-05-01 10:00:00',
'2024-05-05',
25,
'CENTRAL',
1,
0,
0,
0,
0,
1,
'YES'
),
(
'P100188888E',
10003,
'F',
'2024-06-01 10:00:00',
'2024-06-05',
26,
'CALIFORNIA',
1,
0,
0,
0,
0,
1,
'YES'
);

------INSERT STREAM DATA TO FINAL TABLE-----

INSERT INTO APPOINTMENT_FINAL

SELECT

PATIENTID AS Patient_ID,

APPOINTMENTID AS Appointment_ID,

GENDER AS Gender,

AGE AS Age,

CASE
WHEN AGE < 18 THEN 'Children'
WHEN AGE BETWEEN 18 AND 30 THEN 'Youth'
WHEN AGE > 30 AND AGE < 60 THEN 'Adults'
ELSE 'Senior Citizens'
END AS Age_group,

SCHEDULEDDAY AS Scheduled_date,

TO_DATE(APPOINTMENTDAY) AS Appointment_date,

DATEDIFF(
DAY,
TO_DATE(SCHEDULEDDAY),
TO_DATE(APPOINTMENTDAY)
) AS Waiting_days,

NEIGHBOURHOOD AS Neighborhood,

CASE WHEN SCHOLARSHIP = 1 THEN 'Yes' ELSE 'No' END AS Scholarship,

CASE WHEN HIPERTENSION = 1 THEN 'Yes' ELSE 'No' END AS Hypertension,

CASE WHEN DIABETES = 1 THEN 'Yes' ELSE 'No' END AS Diabetes,

CASE WHEN ALCOHOLISM = 1 THEN 'Yes' ELSE 'No' END AS Alcoholism,

CASE WHEN HANDCAP >= 1 THEN 'Yes' ELSE 'No' END AS Handicap,

CASE WHEN SMS_RECEIVED = 1 THEN 'Yes' ELSE 'No' END AS SMS_received,

NO_SHOW AS No_show_status,

CASE
WHEN NO_SHOW = 'Yes' THEN 'Missed'
ELSE 'Visited'
END AS Attendance_status

FROM hospital_stream
WHERE METADATA$ACTION = 'INSERT';

-----------------------PART 11
-------SNOWPIPE--

CREATE OR REPLACE PIPE HOSPITAL_PIPE
AUTO_INGEST = FALSE
AS
COPY INTO APPOINTMENT_RAW
FROM @HEALTHCARE_STAGE
FILE_FORMAT = CSV_FORMAT;

ALTER PIPE HOSPITAL_PIPE REFRESH;

SELECT SYSTEM$PIPE_STATUS('HOSPITAL_PIPE');

----------------part 12--------

-----------------revenue view-----------

CREATE OR REPLACE VIEW VW_APPOINTMENT_DASHBOARD 
AS
SELECT
Patient_ID,
Appointment_ID,
Gender,
Age,
Age_group,
Scheduled_date,
Appointment_date,
Waiting_days,
Neighborhood,
Scholarship,
Hypertension,
Diabetes,
Alcoholism,
Handicap,
SMS_received,
No_show_status,
Attendance_status

FROM APPOINTMENT_FINAL;

select * from VW_APPOINTMENT_DASHBOARD limit 10;

---------------part 13 (connecting snowflake with power bi)------------



----------------------------------------------------------------------------
list @healthcare_stage
select * from hospital_stream;
select * from appointment_raw;
select count(*) from appointment_raw;
select * from appointment_final;
select count(*) from appointment_final;

drop stream hospital_stream;

truncate table appointment_raw;
truncate table appointment_final;

REMOVE @healthcare_stage/appointment_no_show_new_10_rows.csv;