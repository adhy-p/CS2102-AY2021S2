DROP DATABASE IF EXISTS IT_course_trainer;
CREATE DATABASE IT_course_trainer;

DROP TABLE IF EXISTS Customers;
CREATE TABLE Customers (
    cust_id integer GENERATED ALWAYS AS IDENTITY,
    name varchar(50) NOT NULL,
    email varchar(50),
    address varchar(100),
    phone varchar(8),
    PRIMARY KEY (cust_id)
);

DROP TABLE IF EXISTS Credit_Cards;
CREATE TABLE Credit_Cards ( /* owns + credit_cards */
    card_number varchar(16), 
    cvv integer NOT NULL,
    expiry_date date NOT NULL,
    from_date date NOT NULL,
    cust_id integer NOT NULL, 
    FOREIGN KEY (cust_id) REFERENCES Customers,
    CHECK (from_date <= expiry_date),
    PRIMARY KEY (card_number) /* each credit card must have a distinct owner */
);

DROP TABLE IF EXISTS Employees; 
CREATE TABLE Employees (
    eid integer GENERATED ALWAYS AS IDENTITY,
    name varchar(50) NOT NULL,
    address varchar(100),
    email varchar(50),
    phone integer,
    depart_date date, /* NULL if the employee is still employed */
    join_date date NOT NULL,
    PRIMARY KEY (eid)
);

DROP TABLE IF EXISTS Part_Time_Employees;
CREATE TABLE Part_Time_Employees (
    eid integer,
    hourly_rate integer,
    FOREIGN KEY (eid) REFERENCES Employees ON DELETE CASCADE,
    PRIMARY KEY (eid)
);

DROP TABLE IF EXISTS Full_Time_Employees;
CREATE TABLE Full_Time_Employees (
    eid integer,
    monthly_salary integer,
    FOREIGN KEY (eid) REFERENCES Employees ON DELETE CASCADE,
    PRIMARY KEY (eid)
);

DROP TABLE IF EXISTS Administrators;
CREATE TABLE Administrators (
    eid integer,
    PRIMARY KEY (eid),
    FOREIGN KEY (eid) REFERENCES Full_Time_Employees ON DELETE CASCADE
);

DROP TABLE IF EXISTS Managers;
CREATE TABLE Managers (
    eid integer,
    PRIMARY KEY (eid),
    FOREIGN KEY (eid) REFERENCES Full_Time_Employees ON DELETE CASCADE
);

DROP TABLE IF EXISTS Instructors;
CREATE TABLE Instructors ( /* there must be at least one hour of break between two course sessions */
    eid integer,
    PRIMARY KEY (eid),
    FOREIGN KEY (eid) REFERENCES Employees ON DELETE CASCADE
);

DROP TABLE IF EXISTS Full_Time_Instructors;
CREATE TABLE Full_Time_Instructors (
    eid integer,
    eid_emp integer,
    FOREIGN KEY (eid_emp) REFERENCES Full_Time_Employees (eid) ON DELETE CASCADE,
    FOREIGN KEY (eid) REFERENCES Instructors ON DELETE CASCADE,
    PRIMARY KEY (eid), 
    CHECK (eid = eid_emp)
);

DROP TABLE IF EXISTS Part_Time_Instructors;
CREATE TABLE Part_Time_Instructors ( /* must not teach more than 30 hours for each month */
    eid integer,
    eid_emp integer,
    FOREIGN KEY (eid_emp) REFERENCES Part_Time_Employees (eid) ON DELETE CASCADE,
    FOREIGN KEY (eid) REFERENCES Instructors ON DELETE CASCADE,
    PRIMARY KEY (eid),
    CHECK (eid = eid_emp)
);
    
DROP TABLE IF EXISTS Rooms;
CREATE TABLE Rooms (
    rid integer GENERATED ALWAYS AS IDENTITY,
    location varchar(50),
    seating_capacity integer,
    PRIMARY KEY (rid)
);

DROP TABLE IF EXISTS Course_Packages;
CREATE TABLE Course_Packages (
    package_id integer GENERATED ALWAYS AS IDENTITY, 
    sale_start_date date NOT NULL,
    sale_end_date date NOT NULL,
    name varchar(50) NOT NULL,
    num_free_registration integer
        CHECK (num_free_registration >= 0),
    price double precision NOT NULL
        CHECK (price >= 0),
    CHECK (sale_start_date <= sale_end_date),
    PRIMARY KEY (package_id)
);

DROP TABLE IF EXISTS Buys;
CREATE TABLE Buys (
    purchase_date date NOT NULL,
    package_id integer NOT NULL,
    card_number varchar(16) NOT NULL,
    num_remaining_redemptions integer
        CHECK (num_remaining_redemptions >= 0),
    FOREIGN KEY (card_number) REFERENCES Credit_cards,
    FOREIGN KEY (package_id) REFERENCES Course_packages,
    PRIMARY KEY (purchase_date, card_number, package_id)
);

DROP TABLE IF EXISTS Course_Areas;
CREATE TABLE Course_Areas ( /* combined with manages */
    name varchar(50),
    eid integer NOT NULL,
    PRIMARY KEY (name),
    FOREIGN KEY (eid) REFERENCES Managers ON DELETE CASCADE
);

DROP TABLE IF EXISTS Courses;
CREATE TABLE Courses (
    course_id integer GENERATED ALWAYS AS IDENTITY,
    title varchar(50) UNIQUE NOT NULL,
    name varchar(50) NOT NULL,
    duration integer NOT NULL /* in hours */
        CHECK (duration >= 0),
    description text,
    FOREIGN KEY (name) REFERENCES Course_Areas ON DELETE CASCADE,
    PRIMARY KEY (course_id)
);

DROP TABLE IF EXISTS Offerings;
CREATE TABLE Offerings ( /* weak entity set, courses is the identifying relationship */
    launch_date date,
    start_date date,
    end_date date,
    registration_deadline date, /* must be at least 10 days before its start date */
    target_number_registrations integer
        CHECK (target_number_registrations >= 0),
    seating_capacity integer /* sum of the seating capacities of its sessions */
        CHECK (seating_capacity >= 0),
    fees double precision
        CHECK (fees >= 0),
    course_id integer,
    eid integer NOT NULL,
    FOREIGN KEY (course_id) REFERENCES Courses
        ON DELETE CASCADE,
    FOREIGN KEY (eid) REFERENCES Administrators 
        ON DELETE CASCADE,
    CHECK (start_date <= end_date),
    CHECK (start_date - registration_deadline >= 10),
    PRIMARY KEY (course_id, launch_date)
);

DROP TABLE IF EXISTS Sessions;
CREATE TABLE Sessions ( /* weak entity set, offerings is the identifying relationship */
    sid integer,
    session_date date, 
    start_time timestamp, /* earliest: 9am, must end by 6pm, no sessions between 12-2pm */
    end_time timestamp,
    course_id integer,
    launch_date date,
    rid integer NOT NULL,
    eid integer NOT NULL,
    FOREIGN KEY (course_id, launch_date) REFERENCES Offerings
        ON DELETE CASCADE,
    FOREIGN KEY (rid) REFERENCES Rooms ON DELETE CASCADE,
    FOREIGN KEY (eid) REFERENCES Instructors ON DELETE CASCADE,
    CHECK(EXTRACT(DOW FROM session_date) >= 1 and EXTRACT(DOW FROM session_date) <= 5), /* Monday to Friday */
    UNIQUE (session_date, start_time, course_id, launch_date), /* No two sessions for the same course offering can be conducted on the same day and at the same time. */
    PRIMARY KEY (sid, course_id, launch_date)
);

DROP TABLE IF EXISTS Redeems;
CREATE TABLE Redeems ( 
    redeem_date date,
    package_id integer NOT NULL,
    card_number varchar(16) NOT NULL,
    purchase_date date NOT NULL,
    sid integer,
    course_id integer,
    launch_date date,
    FOREIGN KEY (sid, course_id, launch_date) REFERENCES Sessions,
    FOREIGN KEY (purchase_date, card_number, package_id) REFERENCES Buys,
    PRIMARY KEY (redeem_date, purchase_date, card_number, package_id, sid, course_id, launch_date)
);

DROP TABLE IF EXISTS Registers;
CREATE TABLE Registers ( 
    registration_date date,
    card_number varchar(16),
    sid integer,
    course_id integer,
    launch_date date,
    FOREIGN KEY (card_number) REFERENCES Credit_cards,
    FOREIGN KEY (sid, course_id, launch_date) REFERENCES Sessions,
    PRIMARY KEY (registration_date, card_number, sid, course_id, launch_date)
);

DROP TABLE IF EXISTS Cancels;
CREATE TABLE Cancels ( 
    cancel_date date,
    refund_amt integer
        CHECK (refund_amt >= 0),
    package_credit integer
        CHECK (package_credit >= 0),
    cust_id integer NOT NULL,
    sid integer,
    course_id integer,
    launch_date date,
    FOREIGN KEY (cust_id) REFERENCES Customers,
    FOREIGN KEY (sid, course_id, launch_date) REFERENCES Sessions,
    PRIMARY KEY (cancel_date, cust_id, sid, course_id, launch_date)
);

DROP TABLE IF EXISTS Pay_Slips;
CREATE TABLE Pay_Slips (
    payment_date date,
    amount double precision NOT NULL CHECK (amount >= 0),
    num_work_hours integer CHECK (num_work_hours >= 0),
    num_work_days integer CHECK (num_work_days >= 0), /* last_work_day - first_work_day + 1 */
    eid integer,
    PRIMARY KEY (payment_date, eid),
    FOREIGN KEY (eid) REFERENCES Employees ON DELETE CASCADE
);

DROP TABLE IF EXISTS Specializes;
CREATE TABLE Specializes (
    eid integer NOT NULL,
    name varchar(50),
    FOREIGN KEY (eid) REFERENCES Instructors ON DELETE CASCADE,
    FOREIGN KEY (name) REFERENCES Course_Areas ON DELETE CASCADE,
    PRIMARY KEY (eid, name)
);

CREATE OR REPLACE FUNCTION can_redeems() RETURNS TRIGGER AS $$
BEGIN
    IF NOW() <= (SELECT registration_deadline FROM Offerings WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date)
    AND (SELECT seating_capacity 
    FROM Sessions NATURAL JOIN Rooms 
    WHERE NEW.sid = sid AND NEW.course_id = course_id AND NEW.launch_date = launch_date) >
    (SELECT COUNT(*) FROM Redeems R WHERE NEW.sid = R.sid AND NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date)::integer
    + (SELECT COUNT(*) FROM Registers R WHERE NEW.sid = R.sid AND NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date)::integer
    - (SELECT COUNT(*) FROM Cancels C WHERE NEW.sid = C.sid AND NEW.course_id = C.course_id AND NEW.launch_date = C.launch_date)::integer
    AND NOT EXISTS(SELECT 1 FROM Redeems R WHERE NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date AND (SELECT cust_id FROM Credit_Cards WHERE card_number = NEW.card_number) = (SELECT cust_id FROM Credit_Cards WHERE card_number = R.card_number))
    AND NOT EXISTS(SELECT 1 FROM Registers R WHERE NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date AND (SELECT cust_id FROM Credit_Cards WHERE card_number = NEW.card_number) = (SELECT cust_id FROM Credit_Cards WHERE card_number = R.card_number))
    AND (SELECT(EXTRACT(EPOCH from AGE((SELECT session_date FROM Sessions 
        WHERE NEW.sid = sid AND NEW.course_id = course_id AND NEW.launch_date = launch_date), 
        NEW.redeem_date) / 86400)))::integer >= 10
     THEN
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER can_redeems
BEFORE INSERT ON Redeems
FOR EACH ROW EXECUTE FUNCTION can_redeems();

CREATE OR REPLACE FUNCTION can_registers() RETURNS TRIGGER AS $$
BEGIN
    IF NOW() <= (SELECT registration_deadline FROM Offerings WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date)
    AND (SELECT seating_capacity 
    FROM Sessions NATURAL JOIN Rooms 
    WHERE NEW.sid = sid AND NEW.course_id = course_id AND NEW.launch_date = launch_date) >
    (SELECT COUNT(*) FROM Redeems R WHERE NEW.sid = R.sid AND NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date)::integer
    + (SELECT COUNT(*) FROM Registers R WHERE NEW.sid = R.sid AND NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date)::integer
    - (SELECT COUNT(*) FROM Cancels C WHERE NEW.sid = C.sid AND NEW.course_id = C.course_id AND NEW.launch_date = C.launch_date)::integer
    AND NOT EXISTS(SELECT 1 FROM Redeems R WHERE NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date AND (SELECT cust_id FROM Credit_Cards WHERE card_number = NEW.card_number) = (SELECT cust_id FROM Credit_Cards WHERE card_number = R.card_number))
    AND NOT EXISTS(SELECT 1 FROM Registers R WHERE NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date AND (SELECT cust_id FROM Credit_Cards WHERE card_number = NEW.card_number) = (SELECT cust_id FROM Credit_Cards WHERE card_number = R.card_number))
    AND (SELECT(EXTRACT(EPOCH from AGE((SELECT session_date FROM Sessions 
        WHERE NEW.sid = sid AND NEW.course_id = course_id AND NEW.launch_date = launch_date), 
        NEW.registration_date) / 86400)))::integer >= 10
     THEN
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER can_registers
BEFORE INSERT ON Registers
FOR EACH ROW EXECUTE FUNCTION can_registers();

CREATE OR REPLACE FUNCTION update_redeems() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT seating_capacity 
    FROM Sessions NATURAL JOIN Rooms 
    WHERE NEW.sid = sid AND NEW.course_id = course_id AND NEW.launch_date = launch_date) >
    (SELECT COUNT(*) FROM Redeems R WHERE NEW.sid = R.sid AND NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date)::integer
    + (SELECT COUNT(*) FROM Registers R WHERE NEW.sid = R.sid AND NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date)::integer
    - (SELECT COUNT(*) FROM Cancels C WHERE NEW.sid = C.sid AND NEW.course_id = C.course_id AND NEW.launch_date = C.launch_date)::integer
     THEN
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_redeems
BEFORE UPDATE OF sid ON Redeems
FOR EACH ROW EXECUTE FUNCTION update_redeems();

CREATE OR REPLACE FUNCTION update_registers() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT seating_capacity 
    FROM Sessions NATURAL JOIN Rooms 
    WHERE NEW.sid = sid AND NEW.course_id = course_id AND NEW.launch_date = launch_date) >
    (SELECT COUNT(*) FROM Redeems R WHERE NEW.sid = R.sid AND NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date)::integer
    + (SELECT COUNT(*) FROM Registers R WHERE NEW.sid = R.sid AND NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date)::integer
    - (SELECT COUNT(*) FROM Cancels C WHERE NEW.sid = C.sid AND NEW.course_id = C.course_id AND NEW.launch_date = C.launch_date)::integer
     THEN
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_registers
BEFORE UPDATE OF sid ON Registers
FOR EACH ROW EXECUTE FUNCTION update_registers();

CREATE OR REPLACE FUNCTION cant_update_redeems() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Can not change course offering.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cant_update_redeems
BEFORE UPDATE OF course_id, launch_date ON Redeems
FOR EACH ROW EXECUTE FUNCTION cant_update_redeems();

CREATE OR REPLACE FUNCTION cant_update_registers() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Can not change course offering.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cant_update_registers
BEFORE UPDATE OF course_id, launch_date ON Registers
FOR EACH ROW EXECUTE FUNCTION cant_update_registers();

CREATE OR REPLACE FUNCTION can_cancels() RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS(SELECT 1 FROM Redeems NATURAL JOIN Credit_Cards 
    WHERE NEW.cust_id = cust_id AND NEW.sid = sid AND NEW.course_id = course_id AND NEW.launch_date = launch_date)
    AND (SELECT(EXTRACT(EPOCH from AGE((SELECT redeem_date FROM Redeems NATURAL JOIN Credit_Cards 
    WHERE NEW.cust_id = cust_id AND NEW.sid = sid AND NEW.course_id = course_id AND NEW.launch_date = launch_date), NEW.cancel_date)) / 86400))::integer <= 7 THEN
        UPDATE Course_Packages
        SET num_free_registration = num_free_registration + 1
        FROM Course_Packages NATURAL JOIN Redeems NATURAL JOIN Credit_Cards 
        WHERE NEW.sid = sid AND NEW.course_id = course_id AND NEW.launch_date = launch_date;
        new.package_credit = 1;
        new.refund_amt = 0;
        RETURN NEW;
    END IF;
    IF EXISTS(SELECT 1 FROM Registers NATURAL JOIN Credit_Cards 
    WHERE NEW.cust_id = cust_id AND NEW.sid = sid AND NEW.course_id = course_id AND NEW.launch_date = launch_date)
    AND (SELECT(EXTRACT(EPOCH from AGE((SELECT registration_date FROM Registers NATURAL JOIN Credit_Cards 
    WHERE NEW.cust_id = cust_id AND NEW.sid = sid AND NEW.course_id = course_id AND NEW.launch_date = launch_date), NEW.cancel_date)) / 86400))::integer <= 7 THEN
        new.package_credit = 0;
        new.refund_amt = 0.9 * (SELECT fees FROM Offerings WHERE NEW.course_id = course_id AND NEW.launch_date = launch_date);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER can_cancels
BEFORE INSERT ON Cancels
FOR EACH ROW EXECUTE FUNCTION can_cancels();

CREATE OR REPLACE FUNCTION cant_update_delete_cancels() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Can not update or delete cancels.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cant_update_delete_cancels
BEFORE UPDATE OR DELETE ON Cancels
FOR EACH ROW EXECUTE FUNCTION cant_update_delete_cancels();

CREATE OR REPLACE FUNCTION update_instructor() RETURNS TRIGGER AS $$
BEGIN
    IF NOW() <= OLD.session_date
    AND EXISTS(SELECT 1 FROM Specializes WHERE eid = NEW.eid AND name =
    (SELECT name FROM Courses WHERE course_id = NEW.course_id))
    AND NOT EXISTS(SELECT 1 FROM Sessions WHERE eid = NEW.eid AND 
    session_date = NEW.session_date AND
    (SELECT(EXTRACT(EPOCH from AGE(GREATEST(NEW.start_time, start_time), LEAST(NEW.end_time, end_time))) / 3600)::integer < 1 ))
    AND (EXISTS(SELECT 1 FROM Full_Time_Instructors WHERE eid = NEW.eid) 
        OR COALESCE((SELECT SUM(duration) FROM Sessions NATURAL JOIN Courses WHERE eid = NEW.eid AND date_part('month', session_date) = date_part('month', NOW())
                    AND date_part('year', session_date) = date_part('year', NOW())), 0)
        + (SELECT duration FROM Courses WHERE course_id = NEW.course_id) <= 30)
    THEN
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_instructor
BEFORE UPDATE OF eid ON Sessions
FOR EACH ROW EXECUTE FUNCTION update_instructor();

CREATE OR REPLACE FUNCTION update_room() RETURNS TRIGGER AS $$
BEGIN
    IF NOW() <= OLD.session_date
    AND (SELECT seating_capacity FROM  Rooms WHERE NEW.rid = rid) >=
    (SELECT COUNT(*) FROM Redeems R WHERE NEW.sid = R.sid AND NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date)::integer
    + (SELECT COUNT(*) FROM Registers R WHERE NEW.sid = R.sid AND NEW.course_id = R.course_id AND NEW.launch_date = R.launch_date)::integer
    - (SELECT COUNT(*) FROM Cancels C WHERE NEW.sid = C.sid AND NEW.course_id = C.course_id AND NEW.launch_date = C.launch_date)::integer
    THEN
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_room
BEFORE UPDATE OF rid ON Sessions
FOR EACH ROW EXECUTE FUNCTION update_room();

CREATE OR REPLACE FUNCTION delete_session() RETURNS TRIGGER AS $$
BEGIN
    IF NOW() <= OLD.session_date
    AND 0 =
    (SELECT COUNT(*) FROM Redeems R WHERE OLD.sid = R.sid AND OLD.course_id = R.course_id AND OLD.launch_date = R.launch_date)::integer
    + (SELECT COUNT(*) FROM Registers R WHERE OLD.sid = R.sid AND OLD.course_id = R.course_id AND OLD.launch_date = R.launch_date)::integer
    - (SELECT COUNT(*) FROM Cancels C WHERE OLD.sid = C.sid AND OLD.course_id = C.course_id AND OLD.launch_date = C.launch_date)::integer
    THEN
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_session
BEFORE DELETE ON Sessions
FOR EACH ROW EXECUTE FUNCTION delete_session();

CREATE OR REPLACE FUNCTION insert_session() RETURNS TRIGGER AS $$
BEGIN
    IF NOW() <= (SELECT registration_deadline FROM Offerings WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date)
    AND EXISTS(SELECT 1 FROM Specializes WHERE eid = NEW.eid AND name =
    (SELECT name FROM Courses WHERE course_id = NEW.course_id))
    AND NOT EXISTS(SELECT 1 FROM Sessions WHERE eid = NEW.eid AND 
    session_date = NEW.session_date AND
    (SELECT(EXTRACT(EPOCH from AGE(GREATEST(NEW.start_time, start_time), LEAST(NEW.end_time, end_time))) / 3600)::integer < 1 ))
    AND (EXISTS(SELECT 1 FROM Full_Time_Instructors WHERE eid = NEW.eid) 
        OR COALESCE((SELECT SUM(duration) FROM Sessions NATURAL JOIN Courses WHERE eid = NEW.eid AND date_part('month', session_date) = date_part('month', NOW())
                    AND date_part('year', session_date) = date_part('year', NOW())), 0)
        + (SELECT duration FROM Courses WHERE course_id = NEW.course_id) <= 30)
    AND NEW.sid = COALESCE((SELECT MAX(sid) FROM Sessions WHERE NEW.course_id = course_id AND NEW.launch_date = launch_date), 0) + 1
    THEN
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER insert_session
BEFORE INSERT ON Sessions
FOR EACH ROW EXECUTE FUNCTION insert_session();

CREATE OR REPLACE FUNCTION insert_payslip() RETURNS TRIGGER AS $$
DECLARE
end_of_month DATE;
start_of_month DATE;
BEGIN
    end_of_month := (SELECT (date_trunc('month', NOW()) + interval '1 month' - interval '1 day'))::date;
    start_of_month := (SELECT (date_trunc('month', NOW())));
    IF EXISTS(SELECT 1 FROM Full_Time_Employees WHERE eid = NEW.eid)
    AND NEW.num_work_hours IS NULL
    AND NEW.num_work_days = ( 
        LEAST((SELECT depart_date FROM Employees WHERE eid = NEW.eid), end_of_month) -
        GREATEST((SELECT join_date FROM Employees WHERE eid = NEW.eid), start_of_month) + 1)
    AND NEW.num_work_days > 0
    AND ABS(NEW.amount - NEW.num_work_days::double precision *  (SELECT monthly_salary FROM Full_Time_Employees WHERE eid = NEW.eid)::double precision / 31.0) < 1
    THEN
        RETURN NEW;
    END IF;

    IF EXISTS(SELECT 1 FROM Part_Time_Employees WHERE eid = NEW.eid)
    AND NEW.num_work_days IS NULL
    AND NEW.num_work_hours = (SELECT SUM(duration)
                    FROM (Sessions NATURAL JOIN Courses)S WHERE S.eid = NEW.eid 
                    AND date_part('month', session_date) = date_part('month', NOW())
                    AND date_part('year', session_date) = date_part('year', NOW()))
    AND ABS(NEW.amount - NEW.num_work_hours * (SELECT hourly_rate FROM Part_Time_Employees WHERE eid = NEW.eid)) < 1
    THEN
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER insert_payslip
BEFORE INSERT ON Pay_Slips
FOR EACH ROW EXECUTE FUNCTION insert_payslip();

CREATE OR REPLACE FUNCTION cant_update_delete_payslip() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Can not update or delete payslip.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cant_update_delete_payslip
BEFORE UPDATE OR DELETE ON Pay_Slips
FOR EACH ROW EXECUTE FUNCTION cant_update_delete_payslip();

CREATE OR REPLACE FUNCTION update_offering() RETURNS TRIGGER AS $$
BEGIN
    UPDATE Offerings
    SET seating_capacity = (
        SELECT SUM(seating_capacity) 
        FROM Sessions NATURAL JOIN Rooms 
        WHERE rid = NEW.rid AND course_id = NEW.course_id AND launch_date = NEW.launch_date),
    start_date = (
        SELECT MIN(session_date)
        FROM Sessions
        WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date),
    end_date = (
        SELECT MAX(session_date)
        FROM Sessions
        WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date)
    WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_offering
AFTER INSERT OR UPDATE ON Sessions
FOR EACH ROW EXECUTE FUNCTION update_offering();

CREATE TRIGGER check_manager_role_trigger
BEFORE INSERT ON Managers
FOR EACH ROW EXECUTE FUNCTION check_manager_role();

CREATE OR REPLACE FUNCTION check_manager_role()
RETURNS TRIGGER AS $$
BEGIN
    IF (
        EXISTS(SELECT * FROM Instructors WHERE eid = NEW.eid) OR
        EXISTS(SELECT * FROM Administrators WHERE eid = NEW.eid)
    ) THEN
        RAISE EXCEPTION 'No duplicate roles are allowed.';
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER check_administrator_role_trigger
BEFORE INSERT ON Administrators
FOR EACH ROW EXECUTE FUNCTION check_administrator_role();

CREATE OR REPLACE FUNCTION check_administrator_role()
RETURNS TRIGGER AS $$
BEGIN
    IF (
        EXISTS(SELECT * FROM Instructors WHERE eid = NEW.eid) OR
        EXISTS(SELECT * FROM Managers WHERE eid = NEW.eid)
    ) THEN
        RAISE EXCEPTION 'No duplicate roles are allowed.';
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER check_ft_instructor_role_trigger
BEFORE INSERT ON Full_Time_Instructors
FOR EACH ROW EXECUTE FUNCTION check_ft_instructor_role();

CREATE OR REPLACE FUNCTION check_ft_instructor_role()
RETURNS TRIGGER AS $$
BEGIN
    IF (
        EXISTS(SELECT * FROM Administrators WHERE eid = NEW.eid) OR
        EXISTS(SELECT * FROM Managers WHERE eid = NEW.eid) OR
        EXISTS(SELECT * FROM Part_Time_Instructors WHERE eid = NEW.eid)
    ) THEN
        RAISE EXCEPTION 'No duplicate roles are allowed.';
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER check_pt_instructor_role_trigger
BEFORE INSERT ON Part_Time_Instructors
FOR EACH ROW EXECUTE FUNCTION check_pt_instructor_role();

CREATE OR REPLACE FUNCTION check_pt_instructor_role()
RETURNS TRIGGER AS $$
BEGIN
    IF (
        EXISTS(SELECT * FROM Administrators WHERE eid = NEW.eid) OR
        EXISTS(SELECT * FROM Managers WHERE eid = NEW.eid) OR
        EXISTS(SELECT * FROM Full_Time_Instructors WHERE eid = NEW.eid)
    ) THEN
        RAISE EXCEPTION 'No duplicate roles are allowed.';
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER check_employees_insertion_trigger
BEFORE INSERT ON Employees
FOR EACH ROW EXECUTE FUNCTION check_employees_insertion();

CREATE OR REPLACE FUNCTION check_employees_insertion()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Please specify the roles.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER check_instructors_insertion_trigger
BEFORE INSERT ON Instructors
FOR EACH ROW EXECUTE FUNCTION check_instructors_insertion();

CREATE OR REPLACE FUNCTION check_instructors_insertion()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Please specify the roles.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER check_ft_employees_insertion_trigger
BEFORE INSERT ON Full_Time_Employees
FOR EACH ROW EXECUTE FUNCTION check_ft_employees_insertion();

CREATE OR REPLACE FUNCTION check_ft_employees_insertion()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Please specify the roles.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER check_pt_employees_insertion_trigger
BEFORE INSERT ON Part_Time_Employees
FOR EACH ROW EXECUTE FUNCTION check_pt_employees_insertion();

CREATE OR REPLACE FUNCTION check_pt_employees_insertion()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Please specify the roles.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


