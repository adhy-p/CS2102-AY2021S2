CREATE OR REPLACE FUNCTION get_available_course_sessions(course_id_in integer, launch_date_in date) 
RETURNS Table(session_date date, start_time timestamp, instructor_name varchar(50), remaining_seats integer) AS $$
    SELECT session_date, start_time, name, seating_capacity 
    - (SELECT COUNT(*) FROM Redeems R WHERE CS.sid = R.sid AND CS.course_id = R.course_id AND CS.launch_date = R.launch_date)::integer
    - (SELECT COUNT(*) FROM Registers R WHERE CS.sid = R.sid AND CS.course_id = R.course_id AND CS.launch_date = R.launch_date)::integer
    + (SELECT COUNT(*) FROM Cancels C WHERE CS.sid = C.sid AND CS.course_id = C.course_id AND CS.launch_date = C.launch_date)::integer
    FROM (((Sessions NATURAL JOIN Instructors) NATURAL JOIN Employees) NATURAL JOIN Rooms) CS
    WHERE CS.course_id = course_id_in AND CS.launch_date = launch_date_in
    ORDER BY session_date, start_time
$$ LANGUAGE sql;

CREATE OR REPLACE PROCEDURE register_session(cust_id_in integer, course_id_in integer, launch_date_in date, sid_in integer, card_number_in varchar(16), package_id_in integer, purchase_date_in date) AS $$
BEGIN
    IF card_number_in IS NOT NULL THEN
        IF EXISTS(SELECT 1 FROM Credit_Cards NATURAL JOIN Customers WHERE cust_id = cust_id_in AND card_number = card_number_in) THEN
            INSERT INTO Registers (registration_date, card_number, sid, course_id, launch_date) 
                values ((SELECT CURRENT_DATE), card_number_in, sid_in, course_id_in, launch_date_in);
        END IF;
    ELSE
        IF EXISTS(SELECT 1 FROM Buys WHERE package_id = package_id_in AND purchase_date = purchase_date_in AND card_number = card_number_in) THEN
            INSERT INTO Redeems (redeem_date, package_id, card_number, purchase_date, sid, course_id, launch_date) values ((SELECT CURRENT_DATE), package_id_in, purchase_date_in, card_number_in, sid_in, course_id_in, launch_date_in);
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_my_registrations(cust_id_in integer) 
RETURNS Table(course_name varchar(50), course_fees integer, session_date date, session_start timestamp, session_duration integer, instructor_name varchar(50)) AS $$
SELECT name, fees, session_date, start_time, duration, insName
FROM (((((Redeems NATURAL JOIN Credit_Cards) NATURAL JOIN Sessions) NATURAL JOIN (SELECT fees, course_id, launch_date, end_date FROM Offerings) O) NATURAL JOIN Courses) NATURAL JOIN Instructors) NATURAL JOIN (SELECT eid, name AS insName FROM Employees) Ins
WHERE cust_id = cust_id_in AND (SELECT CURRENT_DATE) <= end_date
UNION
SELECT name, fees, session_date, start_time, duration, insName
FROM (((((Registers NATURAL JOIN Credit_Cards) NATURAL JOIN Sessions) NATURAL JOIN (SELECT fees, course_id, launch_date, end_date FROM Offerings) O) NATURAL JOIN Courses) NATURAL JOIN Instructors) NATURAL JOIN (SELECT eid, name AS insName FROM Employees) Ins
WHERE cust_id = cust_id_in AND (SELECT CURRENT_DATE) <= end_date
ORDER BY session_date, start_time
$$ LANGUAGE sql;

CREATE OR REPLACE PROCEDURE update_course_session(cust_id_in integer, course_id_in integer, launch_date_in date, sid_in integer)
AS $$
BEGIN
    IF EXISTS(SELECT 1 FROM Redeems WHERE NEW.course_id = course_id AND NEW.launch_date = launch_date) THEN
        UPDATE Redeems
        SET sid = sid_in
        FROM Redeems NATURAL JOIN Credit_Cards NATURAL JOIN Sessions
        WHERE cust_id = cust_id_in AND course_id = course_id_in AND launch_date = launch_date_in;
    END IF;
    IF EXISTS(SELECT 1 FROM Registers WHERE NEW.course_id = course_id AND NEW.launch_date = launch_date) THEN
        UPDATE Registers
        SET sid = sid_in
        FROM Registers NATURAL JOIN Credit_Cards NATURAL JOIN Sessions
        WHERE cust_id = cust_id_in AND course_id = course_id_in AND launch_date = launch_date_in;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE cancel_registration(cust_id_in integer, course_id_in integer, launch_date_in date)
AS $$
BEGIN
    IF EXISTS(SELECT 1 FROM Redeems WHERE NEW.course_id = course_id AND NEW.launch_date = launch_date) THEN
        INSERT INTO Cancels(cancel_date, refund_amt, package_credit, cust_id, sid, course_id, launch_date) 
        values ((SELECT CURRENT_DATE), 0, 0, cust_id_in, (SELECT sid FROM Redeems WHERE NEW.course_id = course_id AND NEW.launch_date = launch_date), course_id_in, launch_date_in);
    END IF;

    IF EXISTS(SELECT 1 FROM Registers WHERE NEW.course_id = course_id AND NEW.launch_date = launch_date) THEN
        INSERT INTO Cancels(cancel_date, refund_amt, package_credit, cust_id, sid, course_id, launch_date) 
        values ((SELECT CURRENT_DATE), 0, 0, cust_id_in, (SELECT sid FROM Registers WHERE NEW.course_id = course_id AND NEW.launch_date = launch_date), course_id_in, launch_date_in);
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE update_instructor(course_id_in integer, launch_date_in date, sid_in integer, eid_in integer)
AS $$
BEGIN
    UPDATE Sessions
    SET eid = eid_in
    WHERE course_id = course_id_in AND launch_date = launch_date_in AND sid_in = sid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE update_room(course_id_in integer, launch_date_in date, sid_in integer, rid_in integer)
AS $$
BEGIN
    UPDATE Sessions
    SET rid = rid_in
    WHERE course_id = course_id_in AND launch_date = launch_date_in AND sid_in = sid;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE remove_session(course_id_in integer, launch_date_in date, sid_in integer)
AS $$
BEGIN
    DELETE FROM Sessions
    WHERE course_id = course_id_in AND launch_date = launch_date_in AND sid_in = sid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE add_session(session_date_in date, session_start_time_in timestamp, course_id_in integer, launch_date_in date, sid_in integer, eid_in integer, rid_in integer)
AS $$
BEGIN
    INSERT INTO Sessions(sid, session_date, start_time, end_time, course_id, launch_date, rid, eid) values (sid_in, session_date_in, start_time_in,  start_time_in + interval '1h', course_id_in, launch_date_in,  rid_in, eid_in);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pay_salary()
RETURNS TABLE (eid integer, name varchar(50), status varchar(50), num_work_days integer, num_work_hours integer, hourly_rate integer, monthly_salary integer, amount integer)
AS $$
DECLARE
    curs CURSOR FOR (SELECT * FROM Employees ORDER BY eid);
    r RECORD;
    end_of_month DATE;
    start_of_month DATE;
BEGIN
    end_of_month := (SELECT (date_trunc('month', NOW()::date) + interval '1 month' - interval '1 day'))::date;
    start_of_month := (SELECT (date_trunc('month', NOW()::date)));
    OPEN curs;
        LOOP
            FETCH curs INTO r;
            EXIT WHEN NOT FOUND;
            eid := r.eid;
            name := r.name;
            IF EXISTS(SELECT 1 FROM Full_Time_Employees E WHERE E.eid = r.eid) THEN
                status := 'Full-time';
                num_work_hours := NULL;
                hourly_rate := NULL;
                num_work_days := LEAST(r.depart_date, end_of_month) - GREATEST(r.join_date, start_of_month) + 1;
                monthly_salary := (SELECT E.monthly_salary FROM Full_Time_Employees E WHERE E.eid = r.eid);
                amount := num_work_days::double precision * monthly_salary::double precision / 31.0;
            ELSE 
                status := 'Part-time';
                num_work_hours := (SELECT COUNT(*) 
                    FROM Sessions S WHERE S.eid = r.eid 
                    AND date_part('month', session_date) = date_part('month', NOW())
                    AND date_part('year', session_date) = date_part('year', NOW()));
                hourly_rate := (SELECT E.hourly_rate FROM Part_Time_Employees E WHERE E.eid = r.eid);
                num_work_days := NULL;
                monthly_salary := NULL;
                amount := num_work_hours * hourly_rate;
            END IF;
            INSERT INTO Pay_slips (payment_date, amount, num_work_hours, num_work_days, eid) values (NOW(), amount,  num_work_hours, num_work_days, eid);
            RETURN NEXT;
        END LOOP;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;
