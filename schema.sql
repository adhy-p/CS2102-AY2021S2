DROP DATABASE IF EXISTS IT_course_trainer;
CREATE DATABASE IT_course_trainer;

-- DROP TABLE IF EXISTS table_name;
CREATE TABLE Customers (
    cust_id integer,
    name varchar(50) NOT NULL,
    email varchar(50),
    address varchar(100),
    phone varchar(8),
    PRIMARY KEY (cust_id)
);

CREATE TABLE Credit_cards ( /* owns + credit_cards */
    card_number varchar(16), 
    cvv integer NOT NULL,
    expiry_date date NOT NULL,
    from_date date NOT NULL,
    cust_id integer NOT NULL, 
    FOREIGN KEY (cust_id) REFERENCES Customers,
    CHECK (from_date <= expiry_date),
    PRIMARY KEY (card_number) /* each credit card must have a distinct owner */
);

CREATE TABLE Course_packages (
    package_id integer, 
    sale_start_date date NOT NULL,
    sale_end_date date NOT NULL,
    name varchar(50) NOT NULL,
    num_free_registration integer
        CHECK (num_free_registration >= 0),
    price integer NOT NULL
        CHECK (price >= 0),
    PRIMARY KEY (package_id)
);


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

CREATE TABLE Courses (
    course_id integer,
    title varchar(50) NOT NULL,
    duration integer NOT NULL /* in hours */
        CHECK (duration >= 0),
    description text,
    PRIMARY KEY (course_id)
);

CREATE TABLE Offerings ( /* weak entity set, courses is the identifying relationship */
    launch_date date,
    start_date date,
    end_date date,
    registration_deadline date,
    target_number_registrations integer
        CHECK (target_number_registrations >= 0),
    seating_capacity integer
        CHECK (seating_capacity >= 0),
    fees integer
        CHECK (fees >= 0),
    course_id integer,
    FOREIGN KEY (course_id) REFERENCES Courses
        on delete cascade,
    CHECK (start_date <= end_date),
    PRIMARY KEY (course_id, launch_date)
);

CREATE TABLE Sessions ( /* weak entity set, offerings is the identifying relationship */
    sid integer,
    session_date date,
    start_time timestamp,
    end_time timestamp,
    course_id integer,
    launch_date date,
    FOREIGN KEY (course_id, launch_date) REFERENCES Offerings
        on delete cascade,
    PRIMARY KEY (sid, course_id, launch_date)
);

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
    

