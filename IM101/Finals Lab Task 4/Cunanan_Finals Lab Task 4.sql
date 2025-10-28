CREATE DATABASE studentAssignmentDB;

USE studentAssignmentDB;

CREATE TABLE student (
    username varchar(50) PRIMARY KEY
);

CREATE TABLE assignment (
    shortname varchar(50) PRIMARY KEY,
    due_date date NOT NULL,
    url varchar(255)
);

CREATE TABLE submission (
    username varchar(50),
    shortname varchar(50),
    version int,
    submit_date date NOT NULL,
    data text,
    PRIMARY KEY(username, shortname, version),
    FOREIGN KEY (username) REFERENCES student(username)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
    FOREIGN KEY (shortname) REFERENCES assignment(shortname)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);