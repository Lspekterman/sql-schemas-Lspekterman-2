
--departments
DROP TABLE IF EXISTS gleaming_dragonfly.departments CASCADE;
CREATE TABLE gleaming_dragonfly.departments (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT UNIQUE NOT NULL CHECK (char_length(name) > 0 AND char_length(name) < 100),
    abbreviation TEXT UNIQUE NOT NULL CHECK (abbreviation ~ '^[A-Z]{3,4}$')
);



INSERT INTO gleaming_dragonfly.departments (name, abbreviation) VALUES 
    ('Management', 'MGT'),
    ('Computer Science', 'CPSC'),
    ('Drama', 'DRAM')
;

--roles
DROP TABLE IF EXISTS gleaming_dragonfly.roles CASCADE;
CREATE TABLE gleaming_dragonfly.roles (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text UNIQUE NOT NULL CHECK (char_length(name) > 0 AND char_length(name) <25 AND (name ~ '^[a-z]{1,24}$')))
;

INSERT INTO gleaming_dragonfly.roles (name) VALUES 
    ('faculty'),
    ('student')
;

--users
DROP TABLE IF EXISTS gleaming_dragonfly.users CASCADE;
CREATE TABLE gleaming_dragonfly.users (
    netid text CHECK (
        char_length(netid) > 2 
        AND 
        char_length(netid) <10 
        AND 
        netid ~ '^[a-z][a-z0-9]{2,9}$'),
    name text NOT NULL CHECK (
        char_length(name) > 0 
        AND 
        char_length(name) < 100),
    email text UNIQUE NOT NULL CHECK (
        email ~ '^[a-zA-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
        AND
        char_length(email) < 100),
    updated_at timestamptz NOT NULL DEFAULT NOW(),
    role_id INT NOT NULL,
    PRIMARY KEY (netid),
    CONSTRAINT fk_customer FOREIGN KEY (role_id) REFERENCES gleaming_dragonfly.roles (id))
;


CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON gleaming_dragonfly.users
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp ON gleaming_dragonfly.users;



INSERT INTO gleaming_dragonfly.users (name, netid, email, role_id)
SELECT 
    name, netid, email,
    (SELECT id FROM gleaming_dragonfly.roles WHERE name = 'student')
FROM (
    VALUES 
    ('Kwame Abara', 'ka234', 'kwame.abara@yale.edu'),
    ('Hua Zhi Ruo', 'hzr98', 'zhirho.hua@yale.edu'),
    ('Magnus Hansen', 'mh99', 'magnus.hansen@yale.edu'),
    ('Saanvi Ahuja', 'ska299', 'saanvi.ahuja@yale.edu'),
    ('Isabella Torres', 'ift12', 'isabella.torres@yale.edu')
) AS users(name, netid, email);


INSERT INTO gleaming_dragonfly.users (name, netid, email, role_id)
SELECT 
    name, netid, email,
    (SELECT id FROM gleaming_dragonfly.roles WHERE name = 'faculty')
FROM (
    VALUES 
    ('Kyle Jensen', 'klj39', 'kyle.jensen@yale.edu'),
    ('Judy Chevalier', 'jc288', 'judith.chevalier@yale.edu'),
    ('Huang Zeqiong', 'zh44', 'zeqiong.huang@yale.edu')
) AS users(name, netid, email);


-- term
DROP TABLE IF EXISTS gleaming_dragonfly.terms CASCADE;
CREATE TABLE gleaming_dragonfly.terms (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    label TEXT NOT NULL CHECK (char_length(label) > 3 AND char_length(label) < 20),
    dates DATERANGE NOT NULL,
    EXCLUDE USING gist (dates WITH &&)
);

INSERT INTO gleaming_dragonfly.terms (label, dates) VALUES 
    ('Spring 2021', '[2021-01-19, 2021-05-13)'),
    ('Fall 2021', '[2021-08-01, 2021-12-13)');

-- courses
DROP TABLE IF EXISTS gleaming_dragonfly.courses CASCADE;

CREATE TABLE IF NOT EXISTS gleaming_dragonfly.courses (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department_id INT NOT NULL,
    number INT NOT NULL CHECK (number > 99 AND number < 1000),
    name TEXT NOT NULL CHECK (char_length(name) > 5 AND char_length(name) < 100),
    faculty_netid TEXT NOT NULL,
    term_id INT NOT NULL,
    CONSTRAINT fk_department FOREIGN KEY (department_id) REFERENCES gleaming_dragonfly.departments(id),
    CONSTRAINT fk_faculty FOREIGN KEY (faculty_netid) REFERENCES gleaming_dragonfly.users(netid),
    CONSTRAINT fk_term FOREIGN KEY (term_id) REFERENCES gleaming_dragonfly.terms(id),
    CONSTRAINT unique_course_per_term UNIQUE (term_id, department_id, number)
);

INSERT INTO gleaming_dragonfly.courses (department_id, number, name, faculty_netid, term_id)
VALUES 
    (
        (SELECT id FROM gleaming_dragonfly.departments WHERE abbreviation = 'CPSC'), 213, 'Apps, Programming, and Entrepreneurship', 'klj39', 
        (SELECT id FROM gleaming_dragonfly.terms WHERE label = 'Spring 2021')
    ),
    (
        (SELECT id FROM gleaming_dragonfly.departments WHERE abbreviation = 'MGT'), 527, 'Strategic Management of Nonprofit Organizations', 'jc288', 
        (SELECT id FROM gleaming_dragonfly.terms WHERE label = 'Fall 2021')
    );


-- enrollments
CREATE TABLE gleaming_dragonfly.enrollments (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    course_id INT NOT NULL,
    student_netid TEXT NOT NULL,
    grade TEXT CHECK (grade ~ '[ABCDF][+-]?' AND grade !~ '(A\+|F\+|F\-)'),
    CONSTRAINT fk_course FOREIGN KEY (course_id) REFERENCES gleaming_dragonfly.courses(id),
    CONSTRAINT fk_student FOREIGN KEY (student_netid) REFERENCES gleaming_dragonfly.users(netid),
    CONSTRAINT unique_enrollment UNIQUE (course_id, student_netid)
);

-- Kyle's course
INSERT INTO gleaming_dragonfly.enrollments (course_id, student_netid, grade)
VALUES 
    (3, 'ka234', 'A'),
    (3, 'hzr98', 'A');

-- Kyle's course
INSERT INTO gleaming_dragonfly.enrollments (course_id, student_netid, grade)
VALUES 
    (4, 'hzr98', 'A'),
    (4, 'mh99', 'A');

-- Final roster view
DROP VIEW IF EXISTS gleaming_dragonfly.roster;

CREATE VIEW roster AS
SELECT 
    gleaming_dragonfly.courses.number AS course_number,
    gleaming_dragonfly.departments.name AS department, 
    gleaming_dragonfly.terms.label AS term, 
    gleaming_dragonfly.users.name AS name,
    gleaming_dragonfly.users.email AS email
FROM gleaming_dragonfly.courses
JOIN gleaming_dragonfly.departments ON gleaming_dragonfly.courses.department_id = gleaming_dragonfly.departments.id
JOIN gleaming_dragonfly.terms ON gleaming_dragonfly.courses.term_id = gleaming_dragonfly.terms.id
JOIN gleaming_dragonfly.enrollments ON gleaming_dragonfly.courses.id = gleaming_dragonfly.enrollments.course_id
JOIN gleaming_dragonfly.users ON gleaming_dragonfly.enrollments.student_netid = gleaming_dragonfly.users.netid
;

SELECT * FROM gleaming_dragonfly.roster;
