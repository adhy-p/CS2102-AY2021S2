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
    ORDER BY eid DESC 
    LIMIT 1
    INTO employee_id;

    IF (monthly_salary IS NOT NULL AND hourly_rate IS NULL) THEN
        INSERT INTO Full_time_employees VALUES(employee_id, monthly_salary);
    
--         IF  (category='Administrator') THEN
--             INSERT INTO Administrators VALUES (employee_id);
    
--         ELSIF (category='Manager') THEN
--             INSERT INTO Managers VALUES (employee_id);

--         ELSIF (category='Instructor') THEN
--             INSERT INTO Instructors VALUES (employee_id);
--             INSERT INTO Full_time_instructors VALUES (employee_id);

--         ELSE
--     	    RAISE EXCEPTION 'Invalid input';
--         END IF;
        
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
    employee_id integer, departure_date DATE
    ) AS $$
BEGIN
    UPDATE Employees
    SET depart_date = departure_date 
    WHERE eid = employee_id;
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
    cid INTEGER, cc_num VARCHAR(16), cc_expiry DATE, cc_cvv INTEGER
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
        WHERE cust_id = cid;
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
    course_id INTEGER, session_date DATE, session_start_hour TIME
    ) RETURNS TABLE(eid INTEGER, name VARCHAR(50)) AS $$
DECLARE
    course_duration TIME;
BEGIN
    IF (course_id NOT IN (SELECT C.course_id FROM Courses C)) THEN
		RAISE EXCEPTION 'Invalid input, invalid course ID';
    END IF;

    SELECT C.duration INTO course_duration
    FROM Courses C
    WHERE C.course_id = course_id;

    WITH Busy_instructors AS(
        SELECT SE.eid, SE.name
        FROM Sessions NATURAL JOIN Employees SE
        WHERE SE.course_id = course_id
        AND SE.session_date = session_date
        AND (SE.start_time, SE.end_time) OVERLAPS (TIME '00:00' + INTERVAL '1 HOUR' * (session_start_hour) - INTERVAL '1 HOUR', 
        TIME '00:00' + INTERVAL '1 HOUR' * (session_start_hour + session_duration) + INTERVAL '1 HOUR')),

    Other_unavail_instructors AS(
        SELECT SE.eid, SE.name
        FROM (Specializes S INNER JOIN Employees E ON S.eid=E.eid) SE
        HAVING INTERVAL '30 hours' - course_duration >= (
            SELECT SUM(duration)
            FROM ((Part_Time_Instructors NATURAL JOIN Sessions) INNER JOIN Courses ON course_id) PSC
            WHERE PSC.eid = eid
            AND PSC.course_id = course_id))
    
    SELECT eid, name
    FROM Specializes INNER JOIN Employees 
    ON S.eid=E.eid
    EXCEPT
    SELECT eid, name FROM Busy_instructors
    EXCEPT
    SELECT eid, name FROM Other_unavail_instructors;
END;
$$ LANGUAGE plpgsql;

/*7*/
CREATE OR REPLACE FUNCTION get_available_instructors(
    course_id_in INTEGER, start_date DATE, end_date DATE
    ) RETURNS TABLE(eid INTEGER, name VARCHAR(50), teaching_hours INTEGER, day DATE, avail_hours TIME[]) AS $$
DECLARE
all_hours TIME[] = array[time '09:00', time '10:00', time '11:00', time '14:00', time '15:00', time '16:00', time '17:00', time '18:00'];
cur_date DATE;
curs CURSOR FOR (SELECT * FROM Instructors I 
    WHERE EXISTS(SELECT 1 FROM Specializes S WHERE I.eid = S.eid 
    AND S.name = (SELECT C.name FROM Courses C WHERE C.course_id = course_id_in))) ORDER BY I.eid;
r RECORD;
BEGIN

    IF (course_id_in NOT IN (SELECT C.course_id FROM Courses C)) THEN
		RAISE EXCEPTION 'Invalid input, invalid course ID';
    END IF;
    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        cur_date = start_date;
        LOOP
            EXIT WHEN cur_date > end_date;
            eid := r.eid;
            name := (SELECT E.name FROM Employees E WHERE E.eid = r.eid);
            teaching_hours := COALESCE((SELECT SUM(duration)
                            FROM (Sessions NATURAL JOIN Courses)S WHERE S.eid = r.eid 
                            AND date_part('month', session_date) = date_part('month', cur_date)
                            AND date_part('year', session_date) = date_part('year', cur_date)), 0);
            day := cur_date;
            avail_hours := array(SELECT * FROM UNNEST(all_hours) AS hour
                WHERE NOT EXISTS(SELECT 1 FROM Sessions S WHERE S.eid = r.eid AND S.session_date = cur_date AND
                (SELECT(EXTRACT(EPOCH from (GREATEST(S.start_time::time, hour) - LEAST(S.end_time::time, hour + INTERVAL '1 HOUR'))) / 3600)::integer < 1 )));
            cur_date = cur_date + INTERVAL '1 DAY';
            IF EXISTS(SELECT 1 FROM Full_Time_Employees F WHERE F.eid = r.eid) OR + (SELECT duration FROM Courses WHERE course_id = course_id_in) <= 30 THEN
                RETURN NEXT;
            END IF;
        
        END LOOP;
    END LOOP;
    CLOSE curs;

END;
$$ LANGUAGE plpgsql;

-- /*8*/
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

-- /*9*/
CREATE OR REPLACE FUNCTION get_available_rooms(
    start_date DATE, end_date DATE
    ) RETURNS TABLE(rid INTEGER, capacity INTEGER, day DATE, avail_hours TIME[]) AS $$
DECLARE
all_hours TIME[] = array[time '09:00', time '10:00', time '11:00', time '14:00', time '15:00', time '16:00', time '17:00', time '18:00'];
cur_date DATE;
curs CURSOR FOR (SELECT * FROM Rooms) order by rid;
r RECORD;
BEGIN

    OPEN curs;
    LOOP
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        cur_date = start_date;
        LOOP
            EXIT WHEN cur_date > end_date;
            rid := r.rid;
            capacity := r.seating_capacity;
            day := cur_date;
            avail_hours := array(SELECT * FROM UNNEST(all_hours) AS hour
                WHERE NOT EXISTS(SELECT 1 FROM Sessions S WHERE S.rid = r.rid AND S.session_date = cur_date AND
                (SELECT(EXTRACT(EPOCH from (GREATEST(S.start_time::time, hour) - LEAST(S.end_time::time, hour + INTERVAL '1 HOUR'))) / 3600)::integer < 0)));
            cur_date = cur_date + INTERVAL '1 DAY';
            RETURN NEXT;        
        END LOOP;
    END LOOP;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;

/*10*/
DROP PROCEDURE IF EXISTS add_course_offering;
CREATE OR REPLACE PROCEDURE add_course_offering(
    fees DOUBLE PRECISION, launch_date DATE, regis_deadline DATE, target_regis INTEGER, 
    admin_id INTEGER, session_date DATE[], session_start_hour TIME[], room_id INTEGER[]
    ) AS $$
DECLARE
    rid INTEGER;
    valid BOOLEAN := FALSE;
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
        IF ((SELECT SUM(seating_capacity) FROM Rooms R, UNNEST(room_id) AS roid WHERE R.rid=roid) < target_regis) THEN
                RAISE EXCEPTION 'Invalid input, rooms have insufficient seating capacity';
        END IF;
        IF ((SELECT SUM(seating_capacity) FROM Rooms R, UNNEST(room_id) AS roid WHERE R.rid=roid) < target_regis) THEN
                RAISE EXCEPTION 'Invalid input, rooms have insufficient seating capacity';
        END IF;
    END IF;


    INSERT INTO CourseOfferings
    VALUES (launch_date, MIN(session_date), MAX(session_date), regis_deadline, target_regis,
    (SELECT SUM(seating_capacity) FROM Rooms R, UNNEST(room_id) AS roid WHERE R.rid=roid), fees, course_id, admin_id);

    SELECT C.duration INTO duration
    FROM Courses C
    WHERE C.course_id = course_id;

    FOR i in 1..array_length(session_date, 1) 
    LOOP 
        SELECT I.eid INTO instructor_id
        FROM find_instructors(course_id, session_date[i], session_start_hour[i]) I
        LIMIT 1;

        IF instructor_id == NULL OR room_id[i] NOT IN (SELECT rid FROM find_rooms(session_date[i], session_start_hour[i], duration)) THEN
            RAISE EXCEPTION 'No instructors or rooms available.';
        END IF;

        INSERT INTO Sessions VALUES (i, session_date[i], session_start_hour[i], 
        (session_start_hour[i] + TIME '00:00' + INTERVAL '1 HOUR' * (duration)), course_id, launch_date, room_id[i], instructor_id);
    END LOOP;
END;
$$ LANGUAGE plpgsql;
