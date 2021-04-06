DROP DATABASE IF EXISTS IT_course_trainer;
CREATE DATABASE IT_course_trainer;

DROP TABLE IF EXISTS Customers;
CREATE TABLE Customers (
    cust_id integer,
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
    FOREIGN KEY (cust_id) REFERENCES Customers NOT NULL,
    CHECK (from_date <= expiry_date),
    PRIMARY KEY (card_number) /* each credit card must have a distinct owner */
);

DROP TABLE IF EXISTS Employees; 
CREATE TABLE Employees (
    eid integer,
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
    rid integer,
    location varchar(50),
    seating_capacity integer,
    PRIMARY KEY (rid)
);

DROP TABLE IF EXISTS Course_Packages;
CREATE TABLE Course_Packages (
    package_id integer, 
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
    eid integer NOT NULL UNIQUE,
    PRIMARY KEY (name),
    FOREIGN KEY (eid) REFERENCES Managers ON DELETE CASCADE
);

DROP TABLE IF EXISTS Courses;
CREATE TABLE Courses (
    course_id integer,
    title varchar(50) UNIQUE NOT NULL,
    name varchar(50) NOT NULL UNIQUE,
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
    eid integer UNIQUE NOT NULL,
    FOREIGN KEY (course_id) REFERENCES Courses
        ON DELETE CASCADE,
    FOREIGN KEY (eid) REFERENCES Administrators 
        ON DELETE CASCADE,
    CHECK (start_date <= end_date),
    PRIMARY KEY (course_id, launch_date)
);

DROP TABLE IF EXISTS Sessions;
CREATE TABLE Sessions ( /* weak entity set, offerings is the identifying relationship */
    /* No two sessions for the same course offering can be conducted on the same day and at the same time. */
    sid integer,
    session_date date, /* Monday to Friday */
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
    UNIQUE (rid, eid),
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
    payment_date integer,
    amount integer NOT NULL CHECK (amount >= 0),
    num_work_hours integer NOT NULL CHECK (num_work_hours >= 0),
    num_work_days integer NOT NULL CHECK (num_work_days >= 0), /* last_work_day - first_work_day + 1 */
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
