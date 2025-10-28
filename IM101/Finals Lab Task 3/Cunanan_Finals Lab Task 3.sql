CREATE DATABASE mlcDb;

USE mlcDb;

CREATE TABLE employees (
    employee_id int AUTO_INCREMENT PRIMARY KEY,
    UNIQUE (employee_id),
    employee_name varchar(255) NOT NULL,
    manager_id int,
    FOREIGN KEY (manager_id) REFERENCES employees(employee_id)
);

CREATE TABLE departments (
    department_id int AUTO_INCREMENT PRIMARY KEY,
    UNIQUE (department_id),
    department_name varchar(255) NOT NULL
);

CREATE TABLE employee_departments (
    employee_id int,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    department_id int,
    FOREIGN KEY (department_id) REFERENCES departments(department_id),
    PRIMARY KEY(employee_id, department_id)
);

CREATE TABLE employee_projects (
    employee_id int,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    project_name varchar(255) NOT NULL
);

CREATE TABLE managers (
    manager_id int AUTO_INCREMENT PRIMARY KEY,
    UNIQUE (manager_id),
    employee_id int,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);
