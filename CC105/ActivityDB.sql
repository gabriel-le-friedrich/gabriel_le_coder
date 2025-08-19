CREATE DATABASE ActivityDB;

USE DATABASE ActivityDB;

CREATE TABLE tbl_Employees (
    id INT(11) AUTO_INCREMENT NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    department VARCHAR(255) NOT NULL,
    salary DECIMAL(10,2) NOT NULL
);

INSERT INTO tbl_Employees(name, department, salary) VALUES
    ('John Doe', 'HR', 900),
    ('Frederick Gabrielle Cunanan', 'COECS', 10000),
    ('Lorem Ipsum', 'COED', 500);

SELECT * FROM tbl_Employees
ORDER BY id;

UPDATE tbl_Employees
SET salary = 5000
WHERE id = 1;

DELETE FROM tbl_Employees
WHERE department = 'HR';

SELECT AVG(salary)
FROM tbl_Employees;

SELECT MAX(salary)
FROM tbl_Employees;