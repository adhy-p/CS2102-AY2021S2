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
        -- DROP TABLE IF EXISTS registered_offerings;
        CREATE TEMP TABLE registered_offerings AS (
            SELECT O.launch_date, O.start_date, O.course_id, count(*) as num_registrations
            FROM (registers R NATURAL JOIN sessions S) 
            INNER JOIN Offerings O ON (S.course_id, S.launch_date) = (O.course_id, O.launch_date)
            GROUP BY O.launch_date, O.course_id
            ORDER BY O.course_id, O.launch_date
        );
        -- DROP TABLE IF EXISTS registered_offerings_course;
        CREATE TEMP TABLE registered_offerings_course as (
            SELECT reg.course_id, c.title, c.name as area, reg.num_registrations
            FROM registered_offerings reg INNER JOIN courses c on reg.course_id = c.course_id
            ORDER BY reg.course_id, reg.start_date
        );
        OPEN curs FOR (SELECT * FROM registered_offerings);
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
                prev_count := r.num_registrations;
                is_increasing := TRUE;
            ELSE
                IF prev_count >= r.num_registrations THEN
                    is_increasing := FALSE;
                END IF;
                prev_id := r.course_id;
                prev_count := r.num_registrations;
            END IF;
        END LOOP;
        CLOSE curs;
        RETURN QUERY
        SELECT roc.course_id, roc.title, roc.area, cast(count(roc.course_id) as integer) as num_offerings, cast(max(roc.num_registrations) as integer) as num_registrations
        FROM registered_offerings_course roc
        GROUP BY roc.course_id, roc.title, roc.area
        HAVING (count(roc.course_id) >= 2)
        ORDER BY num_offerings DESC, course_id ASC;
        DROP TABLE registered_offerings;
        DROP TABLE registered_offerings_course;
    END;
$$ LANGUAGE plpgsql;

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