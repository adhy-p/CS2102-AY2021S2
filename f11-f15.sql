DROP PROCEDURE IF EXISTS add_course_package;
CREATE OR REPLACE PROCEDURE add_course_package(
    package_name text, no_of_free_sessions INTEGER, package_start_date DATE, 
    package_end_date DATE, package_price DOUBLE PRECISION
) AS $$
    INSERT INTO Course_Packages
    VALUES (
        (SELECT MAX(package_id) + 1 FROM Course_Packages),
        package_start_date, package_end_date, package_name, no_of_free_sessions, package_price
    )
$$ LANGUAGE sql;


DROP FUNCTION IF EXISTS get_available_course_packages();
CREATE OR REPLACE FUNCTION get_available_course_packages()
RETURNS TABLE (
    package_name VARCHAR(50), no_of_free_sessions INTEGER,
    end_date DATE, price DOUBLE PRECISION
) AS $$
    SELECT name, num_free_registration, sale_end_date, price
    FROM Course_Packages
$$ LANGUAGE sql;


DROP PROCEDURE IF EXISTS buy_course_package;
CREATE OR REPLACE PROCEDURE buy_course_package(IN customer_id INTEGER,
IN course_package_id INTEGER) AS $$
BEGIN
    IF (
        EXISTS(SELECT * FROM Customers WHERE cust_id = customer_id) AND
        EXISTS(SELECT * FROM Course_Packages WHERE package_id = course_package_id) AND
        EXISTS(SELECT * FROM Credit_Cards WHERE cust_id = customer_id)
    ) THEN
        INSERT INTO Buys VALUES (
            current_date, course_package_id,
            (SELECT card_number FROM Credit_Cards WHERE cust_id = customer_id),
            (SELECT num_free_registration FROM Course_Packages WHERE package_id = course_package_id)
        );
    END IF;
END;
$$ LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS get_my_course_package(INTEGER);
CREATE OR REPLACE FUNCTION get_my_course_package(customer_id INTEGER)
RETURNS json AS $$
    SELECT row_to_json(t)
    FROM (
        SELECT name, purchase_date, price, num_free_registration,
        num_free_registration - num_remaining_redemptions AS num_not_redeemed, (
            SELECT array_to_json(array_agg(row_to_json(s)))
            FROM (
                SELECT name, session_date, EXTRACT(hour FROM start_time) AS hours 
                FROM Redeems NATURAL JOIN Credit_Cards NATURAL JOIN Courses
                NATURAL JOIN sessions WHERE cust_id = customer_id
                ORDER BY session_date, hours
            ) s
        ) AS infomration
        FROM Course_Packages NATURAL JOIN Buys NATURAL JOIN Credit_Cards
        WHERE cust_id = customer_id
    ) t
$$ LANGUAGE sql;


DROP FUNCTION IF EXISTS get_available_course_offerings();
CREATE OR REPLACE FUNCTION get_available_course_offerings()
RETURNS TABLE (
    course_title VARCHAR(50), course_area VARCHAR(50), start_date DATE,
    end_date DATE, registration_deadline DATE, course_fees DOUBLE PRECISION, 
    remaining_seats BIGINT
) AS $$

    SELECT A.title, A.name, A.start_date, A.end_date, A.registration_deadline, A.fees,
    A.seating_capacity - COUNT(R.course_id) AS remaining_seats
    FROM (Offerings NATURAL JOIN Courses) A LEFT JOIN Registers R
    ON A.launch_date = R.launch_date and A.course_id = R.course_id
    GROUP BY A.course_id, A.launch_date, A.title, A.name, A.start_date, A.end_date,
    A.registration_deadline, A.fees 
    HAVING A.seating_capacity - COUNT(R.course_id) > 0
    ORDER BY A.registration_deadline, A.title;

$$ LANGUAGE sql;
