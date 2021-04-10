/*1*/
DROP PROCEDURE IF EXISTS add_employee;
CREATE OR REPLACE PROCEDURE add_employee(
    name VARCHAR(50), address VARCHAR(100), contact INTEGER, 
    email VARCHAR(100), monthly_salary INTEGER, hourly_rate INTEGER, join_date DATE,
    category VARCHAR(50), areas VARCHAR(50)[]
    ) AS $$
DECLARE
    employee_id INTEGER;
    area VARCHAR(50);
BEGIN
    INSERT INTO Employees (name, address, email, phone, join_date)
    VALUES (name, address, email, contact, join_date);

    SELECT eid 
    FROM Employees
    ORDER BY cust_id DESC 
    LIMIT 1
    INTO employee_id;

    IF (monthly_salary IS NOT NULL AND hourly_rate IS NULL) THEN
        INSERT INTO Full_time_employees VALUES(employee_id, monthly_salary);
    
        IF  (category='Administrator') THEN
            INSERT INTO Administrators VALUES (employee_id);
    
        ELSIF (category='Manager') THEN
            INSERT INTO Managers VALUES (employee_id);

        ELSIF (category='Instructor') THEN
            INSERT INTO Instructors VALUES (employee_id);
            INSERT INTO Full_time_instructors VALUES (employee_id);

        ELSE
    	    RAISE EXCEPTION 'Invalid input';
        END IF;
        
    ELSIF (monthly_salary IS NULL AND hourly_rate IS NOT NULL and category='Instructor') THEN 
        INSERT INTO Part_time_employees VALUES(employee_id, hourly_rate);
        INSERT INTO Instructors VALUES (employee_id);
        INSERT INTO Part_Time_Instructors VALUES (employee_id);

    ELSE
    	RAISE EXCEPTION 'Invalid input';
    END IF;

    IF (areas IS NOT NULL) THEN
        FOREACH area IN ARRAY areas
        LOOP
            INSERT INTO Specializes VALUES (area, employee_id);
        END LOOP;
    END IF; 
END;
$$ LANGUAGE plpgsql;


/*2*/
DROP PROCEDURE IF EXISTS remove_employee;
CREATE OR REPLACE PROCEDURE remove_employee(
    eid VARCHAR(50), departure_date DATE
    ) AS $$
BEGIN
    IF (SELECT EXISTS(SELECT 1 FROM CourseOfferings CO WHERE CO.eid = eid AND registration_deadline >= departure_date)) THEN
        RAISE EXCEPTION 'Cannot remove administrator';
    ELSIF (SELECT EXISTS(SELECT 1 FROM Conducts C, Sessions S WHERE C.eid = eid AND S.session_date >= departure_date)) THEN
        RAISE EXCEPTION 'Cannot remove instructor';
    ELSIF (SELECT EXISTS(SELECT 1 FROM Areas A WHERE A.eid = eid)) THEN
        RAISE EXCEPTION 'Cannot remove manager';
    ELSE
    UPDATE Employees E
    SET E.depart_date = departure_date 
    WHERE E.eid = eid;
    END IF;
END;
$$ LANGUAGE plpgsql;


/*3*/
DROP PROCEDURE IF EXISTS add_customer;
CREATE OR REPLACE PROCEDURE add_customer(
    name VARCHAR(50), address VARCHAR(100), contact INTEGER, 
    email VARCHAR(100), cc_num VARCHAR(16), cc_expiry DATE, cc_cvv INTEGER
    ) AS $$
BEGIN
    IF (cc_expiry < CURRENT_DATE) THEN
    	RAISE EXCEPTION 'Invalid input, credit card expired';
    END IF;

    INSERT INTO Customers (name, email, address, phone)
    VALUES (name, email, address, contact);

    INSERT INTO Credit_Cards 
    VALUES (cc_num, cc_cvv, cc_expiry, CURRENT_DATE,  
            (SELECT cust_id 
            FROM Customers 
            ORDER BY cust_id DESC 
            LIMIT 1));
END;
$$ LANGUAGE plpgsql;

/*4*/
DROP PROCEDURE IF EXISTS update_credit_card;
CREATE OR REPLACE PROCEDURE update_credit_card(
    c_id INTEGER, cc_num VARCHAR(16), cc_expiry DATE, cc_cvv INTEGER
    ) AS $$
BEGIN
    IF (cc_expiry < CURRENT_DATE) THEN
    	RAISE EXCEPTION 'Invalid input, credit card expired';
    END IF;

    IF (SELECT EXISTS(SELECT 1 FROM Customers C where C.cust_id = cid)) THEN
        UPDATE Credit_Cards
        SET card_number = cc_num,
            cvv = cc_cvv,
            expiry_date = cc_expiry,
            from_date = CURRENT_DATE
        WHERE cust_id = c_id;
    ELSE
        RAISE EXCEPTION 'Invalid input, invalid customer ID';
    END IF;
END;
$$ LANGUAGE plpgsql;

/*5*/
DROP PROCEDURE IF EXISTS add_course;
CREATE OR REPLACE PROCEDURE add_course(
    title VARCHAR(50), description TEXT, area VARCHAR(50), duration INTEGER
    ) AS $$
BEGIN
    INSERT INTO Courses (title, name, duration, description)
    VALUES (title, area, duration, description);
END;
$$ LANGUAGE plpgsql;

/*6*/
DROP FUNCTION IF EXISTS find_instructors;
CREATE OR REPLACE FUNCTION find_instructors(
    course_id INTEGER, session_date DATE, session_start_hour TIMESTAMP
    ) RETURNS TABLE(eid INTEGER, name VARCHAR(50)) AS $$
DECLARE
    course_duration TIME;
BEGIN
    IF (course_id NOT IN (SELECT course_id FROM Courses)) THEN
		RAISE EXCEPTION 'Invalid input, invalid course ID';
    END IF;

    SELECT C.duration INTO course_duration
    FROM Courses C
    WHERE C.course_id = course_id;

    WITH Busy_instructors AS(
        SELECT S.eid, E.name
        FROM Sessions S, Employees E
        WHERE S.course_id = course_id
        AND S.session_date = session_date
        AND (S.start_time, S.end_time) OVERLAPS (TIME '00:00' + INTERVAL '1 HOUR' * (session_start_hour), 
        TIME '00:00' + INTERVAL '1 HOUR' * (session_start_hour - INTERVAL '30 minutes'+ session_duration + INTERVAL '30 minutes'))),

    Other_unavail_instructors AS(
        SELECT S.eid, E.name
        FROM Specializes S, Employees E
        HAVING INTERVAL '30 hours' - course_duration >= (
            SELECT SUM(duration)
            FROM ((Part_Time_Instructors NATURAL JOIN Sessions) INNER JOIN Courses ON course_id) PSC
            WHERE PSC.eid = eid
            AND PSC.course_id = course_id))
    
    SELECT S.eid, E.name
    FROM Specializes S, Employees E
    EXCEPT
    SELECT eid, name FROM Busy_instructors
    EXCEPT
    SELECT eid, name FROM Other_unavail_instructors;
END;
$$ LANGUAGE plpgsql;

/*7*/
CREATE OR REPLACE FUNCTION get_available_instructors(
    course_id INTEGER, start_date DATE, end_date DATE
    ) RETURNS TABLE(eid INTEGER, name VARCHAR(50), teaching_hours INTEGER, day DATE, avail_hours TIME[]) AS $$
BEGIN
    IF (course_id NOT IN (SELECT course_id FROM Courses)) THEN
		RAISE EXCEPTION 'Invalid input, invalid course ID';
    END IF;

    SELECT SE.eid, SE.name, SUM(CO.duration),
    FROM (Courses NATURAL JOIN Offerings) CO, (Employee NATURAL JOIN (ALTER TABLE Specializes RENAME name TO area) ) SE
    WHERE CO.course_id = course_id
    AND CO.start_date = start_date
    AND CO.end_date = end_date
    GROUP BY SE.eid

END;
$$ LANGUAGE plpgsql;

/*8*/
DROP FUNCTION IF EXISTS find_rooms;
CREATE OR REPLACE FUNCTION find_rooms(
    session_date DATE, session_start_hour TIMESTAMP, session_duration INTEGER
    ) RETURNS TABLE(rid INTEGER) AS $$
BEGIN
    WITH Used_rooms AS(
        SELECT rid
        FROM Sessions NATURAL JOIN Courses
        WHERE session_date = session_date
        AND (start_time, end_time) OVERLAPS (TIME '00:00' + INTERVAL '1 HOUR' * (session_start_hour), 
        TIME '00:00' + INTERVAL '1 HOUR' * (session_start_hour + session_duration)))

    SELECT rid
    FROM Rooms 
    EXCEPT 
    SELECT rid
    FROM Used_rooms;
END;
$$ LANGUAGE plpgsql;

/*9*/
CREATE OR REPLACE FUNCTION get_available_rooms(
    start_date DATE, end_date DATE
    ) RETURNS TABLE(rid INTEGER, capacity INTEGER, day DATE, avail_hours TIMESTAMP[]) AS $$

/*10*/
DROP PROCEDURE IF EXISTS add_course_offering;
CREATE OR REPLACE PROCEDURE add_course_offering(
    fees DOUBLE PRECISION, launch_date DATE, regis_deadline DATE, target_regis INTEGER, 
    admin_id INTEGER, session_date DATE[], session_start_hour TIME[], room_id INTEGER[]
    ) AS $$
DECLARE
    rid INTEGER;
    valid BOOLEAN := FALSE;
    curr_seats INTEGER;
    total_seats INTEGER := 0;
    duration INTEGER;
    instructor_id INTEGER;
BEGIN   
    IF (admin_id NOT IN (SELECT eid FROM Administrators)) THEN
    	RAISE EXCEPTION 'Invalid input, invalid administrator ID';
    ELSIF (course_id NOT IN (SELECT course_id FROM Courses)) THEN
		RAISE EXCEPTION 'Invalid input, invalid course ID';
    ELSIF (array_length(session_date, 1) IS NULL OR array_length(session_start_hour, 1) IS NULL OR array_length(room_id, 1) IS NULL) THEN
        RAISE EXCEPTION 'Invalid input, invalid session information';
    ELSE
        FOREACH rid IN ARRAY room_id 
        LOOP
            IF ((SELECT seating_capacity FROM Rooms R WHERE R.rid=rid) < target_regis) THEN
                RAISE EXCEPTION 'Invalid input, room has insufficient seating capacity';
            END IF;
        END LOOP;
    END IF;

    FOR i in 1..array_length(session_date,1) 
        LOOP
        IF (find_instructors(course_id, session_date[i], session_start_hour[i]) IS NULL) THEN
            RAISE EXCEPTION 'There is no instructor available to teach a session';
        ELSIF (room_id[i] NOT IN (SELECT rid FROM find_rooms(sessions_date[i], session_start_hour, (SELECT duration FROM Courses C WHERE C.course_id=course_id)))) THEN   
            RAISE EXCEPTION 'There is no room available for a session';
        ELSIF (i=array_length(session_date,1)-1) THEN
            valid := TRUE;
        END IF;
    END LOOP;

    IF (valid=TRUE) THEN
        FOREACH rid IN ARRAY room_id
        LOOP
            SELECT seating_capacity INTO curr_seats
            FROM Rooms R
            WHERE R.rid=rid;
            total_seats= total_seats+curr_seats;
        END LOOP;

        INSERT INTO CourseOfferings
        VALUES (launch_date, MIN(session_date), MAX(session_date), regis_deadline, target_regis,
        total_seats, fees, course_id, admin_id);

        SELECT C.duration INTO duration
        FROM Courses C
        WHERE C.course_id = course_id;

        FOR i in 1..array_length(session_date,1) 
        LOOP 
            SELECT I.eid INTO instructor_id
    	    FROM find_instructors(course_id, session_date[i], session_start_hour[i]) I
            LIMIT 1;

            INSERT INTO Sessions VALUES (i, session_date[i], session_start_hour[i], 
            (session_start_hour[i] + TIME '00:00' + INTERVAL '1 HOUR' * (duration)), course_id, launch_date, room_id, instructor_id);
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql;
