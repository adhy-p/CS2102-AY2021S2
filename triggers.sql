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
