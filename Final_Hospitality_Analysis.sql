-- Create Database
CREATE DATABASE hospitality_analysis;
USE hospitality_analysis;


-- Imported Data and modify Datatype 
-- A) dim_date 
ALTER TABLE dim_date
CHANGE COLUMN `mmm yy` mmm_yy VARCHAR(20),
CHANGE COLUMN `week no` week_no TEXT;

ALTER TABLE dim_date
MODIFY COLUMN date DATE,
MODIFY COLUMN day_type VARCHAR(20),
ADD PRIMARY KEY (date);

select * from dim_date;

-- B) dim_hotel
ALTER TABLE dim_hotel
CHANGE COLUMN `ï»¿property_id` property_id VARCHAR(20);

ALTER TABLE dim_hotel
MODIFY COLUMN property_id INT,
MODIFY COLUMN property_name VARCHAR(255),
MODIFY COLUMN category VARCHAR(50),
MODIFY COLUMN city VARCHAR(100),
ADD PRIMARY KEY (property_id);

select * from dim_hotel;

-- C) dim_room
ALTER TABLE dim_room
CHANGE COLUMN `ï»¿room_id` room_id VARCHAR(50),
MODIFY COLUMN room_class VARCHAR(50),
ADD PRIMARY KEY (room_id);

select * from dim_room;

-- D) fact_agreegate_bookings

ALTER TABLE fact_agreegate_bookings
CHANGE COLUMN `ï»¿property_id` property_id INT;

ALTER TABLE fact_agreegate_bookings 
MODIFY COLUMN check_in_date VARCHAR(10);

-- New column for DATE type 
ALTER TABLE fact_agreegate_bookings 
ADD COLUMN check_in_date_new DATE;

-- Disable safe-updates for current session
SET SQL_SAFE_UPDATES = 0;

-- convert prev column data 
UPDATE fact_agreegate_bookings
SET check_in_date_new = STR_TO_DATE(check_in_date, '%d-%m-%Y');

-- check if coversion is ok
SELECT check_in_date, check_in_date_new 
FROM fact_agreegate_bookings
LIMIT 10;

-- remove prev column
ALTER TABLE fact_agreegate_bookings DROP COLUMN check_in_date;

-- add new column
ALTER TABLE fact_agreegate_bookings 
CHANGE COLUMN check_in_date_new check_in_date DATE;

-- datatype modification
ALTER TABLE fact_agreegate_bookings
MODIFY COLUMN check_in_date DATE,
MODIFY COLUMN room_category VARCHAR(50),
MODIFY COLUMN successful_bookings INT,
MODIFY COLUMN capacity INT;

select * from fact_agreegate_bookings;

-- E) fact_booking
ALTER TABLE fact_booking
CHANGE COLUMN `fact_bookings` booking_id VARCHAR(100);

ALTER TABLE fact_booking
MODIFY COLUMN booking_date VARCHAR(10),
MODIFY COLUMN check_in_date VARCHAR(10),
MODIFY COLUMN checkout_date VARCHAR(10);

ALTER TABLE fact_booking 
ADD COLUMN booking_date_new DATE,
ADD COLUMN check_in_date_new DATE,
ADD COLUMN checkout_date_new DATE;

-- Disable safe-updates for current session
SET SQL_SAFE_UPDATES = 0;

-- convert prev column data 
UPDATE fact_booking
SET booking_date_new = STR_TO_DATE(booking_date, '%d-%m-%Y');

UPDATE fact_booking
SET check_in_date_new = STR_TO_DATE(check_in_date, '%d-%m-%Y');

UPDATE fact_booking
SET checkout_date_new = STR_TO_DATE(checkout_date, '%d-%m-%Y');

-- check if coversion is ok
SELECT booking_date, booking_date_new
FROM fact_booking
LIMIT 10;

SELECT check_in_date, check_in_date_new
FROM fact_booking
LIMIT 10;

SELECT checkout_date, checkout_date_new
FROM fact_booking
LIMIT 10;

-- remove prev column
ALTER TABLE fact_booking DROP COLUMN booking_date;
ALTER TABLE fact_booking DROP COLUMN check_in_date;
ALTER TABLE fact_booking DROP COLUMN checkout_date;

-- add new column
ALTER TABLE fact_booking
CHANGE COLUMN booking_date_new booking_date DATE;

ALTER TABLE fact_booking
CHANGE COLUMN check_in_date_new check_in_date DATE;

ALTER TABLE fact_booking
CHANGE COLUMN checkout_date_new checkout_date DATE;

-- datatype modification
ALTER TABLE fact_booking
MODIFY COLUMN booking_date DATE,
MODIFY COLUMN check_in_date DATE,
MODIFY COLUMN checkout_date DATE, 
MODIFY COLUMN no_guests INT,
MODIFY COLUMN room_category VARCHAR(50),
MODIFY COLUMN booking_platform VARCHAR(100),
MODIFY COLUMN ratings_given DECIMAL(3,1),
MODIFY COLUMN booking_status VARCHAR(50),
MODIFY COLUMN revenue_generated DECIMAL(14,2),
MODIFY COLUMN revenue_realized DECIMAL(14,2),
MODIFY COLUMN rating_cleaning VARCHAR(50);

select * from dim_date;
select * from dim_hotel;
select * from dim_room;
select * from fact_agreegate_bookings;
select * from fact_booking;


-- Step 1, setting dates as per Data 

SET @start_date = '2022-05-01';
SET @end_date   = '2022-07-31';


-- Step 2: The Indexes created - Indexes are like a book’s table of contents — they help the database find rows faster without scanning the whole table.
-- fact_booking
ALTER TABLE fact_booking ADD INDEX idx_fb_checkin (check_in_date);
ALTER TABLE fact_booking ADD INDEX idx_fb_status (booking_status);
ALTER TABLE fact_booking ADD INDEX idx_fb_property (property_id);

-- fact_agreegate_bookings
ALTER TABLE fact_agreegate_bookings ADD INDEX idx_fab_checkin (check_in_date);
ALTER TABLE fact_agreegate_bookings ADD INDEX idx_fab_property (property_id);


-- KPI's 
-- 1) Total Revenue
SELECT SUM(revenue_realized) AS total_revenue
FROM fact_booking;


-- 2) Total Bookings
SELECT COUNT(*) AS total_bookings
FROM fact_booking;


-- 3) Occupancy % = (successful_bookings / capacity) * 100
SELECT 
    ROUND(SUM(successful_bookings) / SUM(capacity) * 100, 2) AS occupancy_pct
FROM fact_agreegate_bookings;


-- 4) Cancellation Rate = % of cancelled bookings
SELECT 
  (SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS cancellation_rate_pct
FROM fact_booking;


-- 5) Utilized Capacity = Total utilized rooms
SELECT 
    ROUND(SUM(successful_bookings) / SUM(capacity) * 100, 2) AS utilized_capacity_pct
FROM fact_agreegate_bookings;


-- 6) ADR (Average Daily Rate) = Total Revenue / Successful Bookings
SELECT 
    ROUND(SUM(revenue_realized) / NULLIF(SUM(successful_bookings),0),2) AS ADR
FROM fact_booking fb
JOIN fact_agreegate_bookings fab 
  ON fb.property_id = fab.property_id 
 AND fb.check_in_date = fab.check_in_date;


-- 7) Revenue by City & Hotel
SELECT 
    h.city,
    h.property_name,
    ROUND(SUM(fb.revenue_realized),2) AS total_revenue
FROM fact_booking fb
JOIN dim_hotel h ON fb.property_id = h.property_id
GROUP BY h.city, h.property_name
ORDER BY total_revenue DESC;


-- 8) Top 5 Hotels by Revenue
SELECT 
    h.property_name,
    ROUND(SUM(fb.revenue_realized),2) AS total_revenue
FROM fact_booking fb
JOIN dim_hotel h ON fb.property_id = h.property_id
GROUP BY h.property_name
ORDER BY total_revenue DESC
LIMIT 5;


-- 9) Total Booking by City & Hotel
SELECT 
    h.city,
    h.property_name,
    COUNT(fb.booking_id) AS total_bookings
FROM fact_booking fb
JOIN dim_hotel h ON fb.property_id = h.property_id
GROUP BY h.city, h.property_name
ORDER BY total_bookings DESC;


-- 10) Top 5 Hotels by Bookings
SELECT 
    h.property_name,
    COUNT(fb.booking_id) AS total_bookings
FROM fact_booking fb
JOIN dim_hotel h ON fb.property_id = h.property_id
GROUP BY h.property_name
ORDER BY total_bookings DESC
LIMIT 5;


-- 11) Class Wise Revenue
SELECT 
    r.room_class,
    ROUND(SUM(fb.revenue_realized),2) AS total_revenue
FROM fact_booking fb
JOIN dim_room r ON fb.room_category = r.room_id
GROUP BY r.room_class
ORDER BY total_revenue DESC;


-- 12) Checked Out, Cancelled, No Show
SELECT 
    booking_status,
    COUNT(*) AS total_bookings,
    ROUND(SUM(revenue_realized),2) AS total_revenue
FROM fact_booking
GROUP BY booking_status;









