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
    INSERT INTO Sessions(sid, session_date, start_time, end_time, course_id, launch_date, rid, eid) values (sid_in, session_date_in, start_time_in,  start_time_in + (SELECT duration FROM Courses WHERE course_id = course_id_in), course_id_in, launch_date_in,  rid_in, eid_in);
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
                num_work_hours := (SELECT SUM(duration)
                    FROM (Sessions NATURAL JOIN Courses)S WHERE S.eid = r.eid 
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
/* Routine no. 26 */
CREATE OR REPLACE FUNCTION promote_courses()
RETURNS TABLE(
    cust_id integer,
    name varchar(50),
    area varchar(50),
    course_id integer,
    title varchar(50),
    launch_date date,
    registration_deadline date,
    fees double precision
    ) AS $$
    BEGIN
        RETURN QUERY
        WITH last_registration AS (
            SELECT min(age(registration_date)), C.cust_id 
            FROM Registers R JOIN Credit_cards C ON R.card_number = C.card_number 
            GROUP BY C.cust_id
        ),
        inactive_customers AS (
            SELECT *
            FROM customers C
            WHERE C.cust_id not in (
                SELECT L.cust_id
                FROM last_registration L
                WHERE min < '6 mons'
                )
        ),
        inactive_cust_recent_courses AS (
        SELECT R.cust_id, R.name, R.course_id, R.registration_date
        FROM (
            SELECT C.cust_id, I.name, coalesce(R.course_id, 0) as course_id, registration_date, RANK() OVER (PARTITION BY C.cust_id ORDER BY registration_date DESC) as date_rank
            FROM (inactive_customers I LEFT OUTER JOIN Credit_cards C ON I.cust_id = C.cust_id) LEFT OUTER JOIN Registers R ON R.card_number = C.card_number
            ) as R
        WHERE date_rank <= 3
        ),
        inactive_cust_areas AS (
            SELECT DISTINCT I.cust_id, I.name, C.name as area
            FROM inactive_cust_recent_courses I, courses C 
            WHERE I.course_id = C.course_id OR I.course_id = 0
            ORDER BY I.cust_id
        )
        SELECT I.cust_id, I.name, I.area, C.course_id, C.title, O.launch_date, O.registration_deadline, O.fees
        FROM (inactive_cust_areas I INNER JOIN Courses C ON I.area = C.name) INNER JOIN Offerings O ON C.course_id = O.course_id
        WHERE O.registration_deadline >= CURRENT_DATE
        ORDER BY I.cust_id, O.registration_deadline;

    END;
$$ LANGUAGE plpgsql;

/* Routine no. 27 */
CREATE OR REPLACE FUNCTION top_packages(N integer)
RETURNS TABLE(
    package_id integer,
    num_free_registration integer,
    price double precision,
    start_date date,
    end_date date,
    num_packages_sold integer
    ) AS $$
    BEGIN
        RETURN QUERY
        WITH package_sold AS (
            SELECT B.package_id, CAST(count(*) as integer) as num_packages_sold
            FROM buys B
            WHERE EXTRACT (YEAR FROM (purchase_date)) = EXTRACT(YEAR FROM (CURRENT_DATE))
            GROUP BY B.package_id
        )
        SELECT R.package_id, R.num_free_registration, R.price, R.sale_start_date, R.sale_end_date, R.num_packages_sold
        FROM (
            SELECT P.package_id, C.num_free_registration, C.price, C.sale_start_date, C.sale_end_date, P.num_packages_sold, DENSE_RANK() OVER (ORDER BY P.num_packages_sold DESC) as package_rank
            FROM package_sold P INNER JOIN Course_Packages C ON P.package_id = C.package_id
        ) as R
        WHERE package_rank <= N
        ORDER BY num_packages_sold DESC, price DESC;
    END;
$$ LANGUAGE plpgsql;

/* Routine no. 28 */
CREATE OR REPLACE FUNCTION popular_courses()
RETURNS TABLE(
    course_id integer,
    title varchar(50),
    area varchar(50),
    num_offerings integer,
    num_registrations integer
    ) AS $$
    DECLARE 
        curs refcursor;
        r RECORD;
        prev_count INT;
        prev_id INT;
        is_increasing BOOLEAN;
    BEGIN
        CREATE TEMP TABLE registered_offerings AS (
            SELECT O.launch_date, O.start_date, O.course_id, count(*) as num_registrations
            FROM (registers R NATURAL JOIN sessions S) 
            INNER JOIN Offerings O ON (S.course_id, S.launch_date) = (O.course_id, O.launch_date)
            GROUP BY O.launch_date, O.course_id
            ORDER BY O.course_id, O.launch_date
        );
        CREATE TEMP TABLE redeemed_offerings AS (
            SELECT O.launch_date, O.start_date, O.course_id, count(*) as num_redeemed
            FROM (redeems R NATURAL JOIN sessions S) 
            INNER JOIN Offerings O ON (S.course_id, S.launch_date) = (O.course_id, O.launch_date)
            GROUP BY O.launch_date, O.course_id
            ORDER BY O.course_id, O.launch_date
        );
        CREATE TEMP TABLE registered_and_redeemed_offerings AS (
            SELECT res.launch_date, res.start_date, res.course_id, coalesce(res.num_registrations,0) + coalesce(res.num_redeemed,0) as total_registration
            FROM (registered_offerings reg NATURAL FULL OUTER JOIN redeemed_offerings red) as res
            ORDER BY res.course_id, res.launch_date
        );
        CREATE TEMP TABLE registered_offerings_course as (
            SELECT c.course_id, c.title, c.name as area, coalesce(reg.num_registrations,0) + coalesce(red.num_redeemed,0) as total_registration
            FROM registered_offerings reg RIGHT OUTER JOIN courses c on reg.course_id = c.course_id
            LEFT OUTER JOIN redeemed_offerings red on red.course_id = c.course_id
            WHERE coalesce(reg.num_registrations,0) + coalesce(red.num_redeemed,0) <> 0
            ORDER BY c.course_id, reg.start_date
        );
        OPEN curs FOR (SELECT * FROM registered_and_redeemed_offerings);
        prev_id := 0;
        prev_count := 0;
        is_increasing := TRUE;
        LOOP
            FETCH curs INTO r;
            IF NOT FOUND THEN
                IF is_increasing = FALSE THEN
                    DELETE FROM registered_offerings_course reg WHERE reg.course_id = prev_id;
                END IF;
                EXIT;
            END IF;
            IF prev_id <> r.course_id THEN
                IF is_increasing = FALSE THEN
                    IF prev_id <> 0 THEN
                        DELETE FROM registered_offerings_course reg WHERE reg.course_id = prev_id;
                     END IF;
                END IF;
                prev_id := r.course_id;
                prev_count := r.total_registration;
                is_increasing := TRUE;
            ELSE
                IF prev_count >= r.total_registration THEN
                    is_increasing := FALSE;
                END IF;
                prev_id := r.course_id;
                prev_count := r.total_registration;
            END IF;
        END LOOP;
        CLOSE curs;
        RETURN QUERY
        SELECT roc.course_id, roc.title, roc.area, cast(count(roc.course_id) as integer) as num_offerings, cast(max(roc.total_registration) as integer) as num_registrations
        FROM registered_offerings_course roc
        GROUP BY roc.course_id, roc.title, roc.area
        HAVING (count(roc.course_id) >= 2)
        ORDER BY num_offerings DESC, course_id ASC;

        DROP TABLE registered_offerings;
        DROP TABLE redeemed_offerings;
        DROP TABLE registered_and_redeemed_offerings;
        DROP TABLE registered_offerings_course;
    END;
$$ LANGUAGE plpgsql;

/* Routine no. 29 */
CREATE OR REPLACE FUNCTION view_summary_report(N integer)
RETURNS TABLE(
    month_and_year varchar(50),
    total_salary double precision,
    total_packages_sold integer,
    total_paid_fee double precision, -- total, without considering whether it will be cancelled or not
    total_refund double precision,
    total_redeemed_course integer -- excluding the canceled sessions
    ) AS $$
    DECLARE
        iter_date date;
    BEGIN
        iter_date = CURRENT_DATE;
        for counter in 1..N
        LOOP
            month_and_year:= to_char(iter_date, 'YYYY-MM');
            total_salary:= coalesce((SELECT sum(amount) FROM Pay_slips WHERE date_trunc('month', payment_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', payment_date)), 0);
            total_packages_sold:= coalesce((SELECT count(*) FROM Buys WHERE date_trunc('month', purchase_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', purchase_date)), 0);
            total_paid_fee:= coalesce((SELECT sum(fees) FROM (registers R NATURAL JOIN sessions S) INNER JOIN Offerings O ON (S.course_id, S.launch_date) = (O.course_id, O.launch_date)
                            WHERE date_trunc('month', registration_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', registration_date)
                            ), 0);
            total_refund:= coalesce((SELECT sum(refund_amt) FROM Cancels WHERE date_trunc('month', cancel_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', cancel_date)), 0);
            total_redeemed_course:= coalesce((SELECT count(*) FROM Buys WHERE date_trunc('month', purchase_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', purchase_date)), 0)
                                    - coalesce((SELECT count(*) FROM Cancels WHERE date_trunc('month', cancel_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', cancel_date)), 0);
            RETURN NEXT;
            iter_date:= iter_date - interval '1 month';
        END LOOP;
    END;
$$ LANGUAGE plpgsql;

/* Routine no. 30 */
CREATE OR REPLACE FUNCTION view_manager_report()
RETURNS TABLE(
    name varchar(50),
    num_course_area integer,
    num_offerings_managed integer,
    net_registration_fees double precision,
    highest_paying_course varchar(50)
    ) AS $$
    BEGIN
        RETURN QUERY
        WITH eid_name_count as (
            select m.eid, e.name, count(distinct c.eid) as num_course_area 
            from (managers m natural join employees e) left outer join course_areas c on c.eid = m.eid 
            group by m.eid, e.name order by m.eid
        ),
        eid_course_id_count as (
            select ca.eid, cc.course_id, count(ca.eid)
            from (course_areas ca natural join courses cc) join offerings o on cc.course_id = o.course_id
            -- where date_trunc('year', o.end_date) = date_trunc('year', CURRENT_DATE) 
            group by ca.eid, cc.course_id
        ),
        eid_sum_offerings as (
            select eid, coalesce(sum(count), 0) as sum
            from eid_course_id_count
            group by eid
        ),
        course_id_regis_fees as (
            select r.course_id, coalesce(sum(o.fees), 0) as sum_regis_fees 
            from registers r natural join offerings o 
            -- where date_trunc('year', o.end_date) = date_trunc('year', CURRENT_DATE) 
            group by r.course_id
        ),
        course_id_redeem_fees as (
            select r.course_id, sum(c.price / c.num_free_registration) as sum_redeem_fees 
            from course_packages c natural join redeems r
            group by course_id
        ),
        course_id_net_fees as (
            select res.course_id, coalesce(sum_regis_fees, 0) + coalesce(sum_redeem_fees, 0) as sum_fees
            from (course_id_regis_fees cirf natural full outer join course_id_redeem_fees) as res
        ),
        auxilliary as (
            select enc.eid, max(sum_fees)
            from ((eid_name_count enc left outer join eid_course_id_count ecic on enc.eid = ecic.eid) 
            left outer join course_id_net_fees cinf on ecic.course_id = cinf.course_id) 
            group by enc.eid
            order by enc.eid
        ),
        final_without_title as (
            select distinct enc.eid, enc.name, enc.num_course_area, coalesce(eso.sum, 0) as sum, cinf.course_id, cinf.sum_fees as sum_fees
            from (((eid_name_count enc left outer join eid_course_id_count ecic on enc.eid = ecic.eid) 
            left outer join auxilliary aux on enc.eid = aux.eid) 
            left outer JOIN course_id_net_fees cinf on cinf.course_id = ecic.course_id)
            left outer join eid_sum_offerings eso on eso.eid = enc.eid
            where cinf.sum_fees = aux.max or (cinf.sum_fees is null and aux.max is null)
            order by enc.eid
        )
        select f.name, cast(f.num_course_area as integer), cast(f.sum as integer), f.sum_fees, c.title
        from final_without_title f
        left outer join courses c on f.course_id = c.course_id
        order by f.name;

    END;
$$ LANGUAGE plpgsql;

