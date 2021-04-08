CREATE OR REPLACE FUNCTION add_course_package(
    package_name VARCHAR, no_of_free_sessions INTEGER, package_start_date DATE, 
    package_end_date DATE, package_price DOUBLE
    ) AS $$
    INSERT INTO Course_Packages (sale_start_date, sale_end_date, name, num_free_registration, price)
    VALUES (package_start_date, package_end_date, package_name, no_of_free_sessions, package_price)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_available_course_packages()
RETURNS RECORD AS $$
    SELECT name, num_free_registration, sale_end_date, price
    FROM Course_Packages
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION buy_course_package(
    IN customer_id INTEGER, IN course_package_id INTEGER) AS $$
IF EXISTS(SELECT * FROM Customers WHERE cust_id = customer_id) AND
    EXISTS(SELECT * FROM Course_Packages WHERE package_id = course_package_id) AND
    EXISTS(SELECT * FROM Credit_Cards WHERE cust_id = customer_id)
    BEGIN
        INSERT INTO Buys VALUES (
            DATETODAY, course_package_id,
            SELECT card_number FROM Credit_Cards WHERE cust_id = customer_id, 
            SELECT num_free_registration FROM Course_Packages WHERE package_id = course_package_id    
        )
    END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_my_course_package(customer_id INTEGER) AS $$
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

CREATE OR REPLACE FUNCTION get_available_course_offerings() AS $$
    SELECT A.title, A.name, A.start_date, A.end_date, A.registration_deadline, A.fees,
    A.seating_capacity - count(R.course_id) AS no_of_remaining_redemption
    FROM (Offerings NATURAL JOIN Courses) A LEFT JOIN Registers R
    ON A.launch_date = R.launch_date and A.course_id = R.course_id
    GROUP BY A.course_id, A.launch_date, A.title, A.name, A.start_date, A.end_date,
    A.registration_deadline, A.fees
    HAVING A.seating_capacity - count(R.course_id) > 0;
$$ LANGUAGE sql;

