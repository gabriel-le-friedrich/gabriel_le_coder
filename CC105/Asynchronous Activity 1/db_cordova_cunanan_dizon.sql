CREATE DATABASE db_cordova_cunanan_dizon;
USE db_cordova_cunanan_dizon;

CREATE TABLE tb_Customers (
	CustomerID INT AUTO_INCREMENT PRIMARY KEY,
	CustomerName VARCHAR(50) NOT NULL,
	ContactName VARCHAR(50) NOT NULL,
	Address VARCHAR(100) NOT NULL,
	City VARCHAR(50) NOT NULL,
	PostalCode VARCHAR(20) NOT NULL,
	Country VARCHAR(50) NOT NULL 
);

INSERT INTO tb_Customers (CustomerName, ContactName, Address, City, PostalCode, Country) VALUES
	('Juan Reason P. Tadeo', 'Maria Juana P. Tadeo', 'Block 1 Lot 1 Phase 1, Greenfield City', 'Magalang', '2011', 'Philippines'),
	('John Doe', 'Jane Doe', '123 Main St', 'Anytown', '12345', 'USA'),
	('Alice Smith', 'Bob Smith', '456 Elm St', 'Sometown', '67890', 'Canada'),
	('Carlos Rodriguez', 'Ana Rodriguez', '789 Oak St', 'Bigcity', '54321', 'Mexico'),
	('Emily Johnson', 'David Johnson', '321 Pine St', 'Smallville', '98765', 'USA'),
	('Luis Garcia', 'Maria Garcia', 'Unit 101, Greenhills Plaza', 'Mandaluyong', '1100', 'Philippines'),
	('Nina Tan', 'Peter Tan', '2345 Ortigas Ave', 'Pasig', '1600', 'Philippines'),
	('Oscar Reyes', 'Patricia Reyes', '3456 EDSA Blvd', 'Makati', '1200', 'Philippines'),
	('Paula Lim', 'Quentin Lim', '4567 Ayala Ave', 'Cebu City', '6000', 'Philippines'),
	('Rafael Santos', 'Sofia Santos', '5678 Mabini St', 'Davao City', '8000', 'Philippines');

CREATE TABLE tb_Categories (  
	CategoryID INT AUTO_INCREMENT PRIMARY KEY,
	CategoryName VARCHAR(50) NOT NULL,
	Description VARCHAR(255) NOT NULL 
);

INSERT INTO tb_Categories(CategoryName, Description) VALUES 
	('Beverages', 'Soft drinks, coffees, teas, beers, and ales'),
	('Condiments', 'Sweet and savory sauces, relishes, spreads, and seasonings'),
	('Confections', 'Desserts, candies, and sweet breads'),
	('Dairy Products', 'Cheeses'),
	('Grains/Cereals', 'Breads, crackers, pasta, and cereal'),
	('Meat/Poultry', 'Prepared meats'),
	('Produce', 'Dried fruit and bean curd'),
	('Seafood', 'Seaweed and fish');

CREATE TABLE tb_Employees (
	EmployeeID INT AUTO_INCREMENT PRIMARY KEY,
	FirstName VARCHAR(50) NOT NULL,
	MiddleName VARCHAR(50) NOT NULL,
	LastName VARCHAR(100) NOT NULL,
	Gender VARCHAR(6) NOT NULL,
	Age INT NOT NULL
);

INSERT INTO tb_Employees (FirstName, MiddleName, LastName, Gender, Age) VALUES
	('Juana', 'Toyo', 'Datu Puti', 'Female', 22),
	('Maria', 'Juana', 'Santos', 'Female', 30),
	('Jose', 'Pascual', 'Smith', 'Male', 35),
	('Ana', 'Maria', 'Rodriguez', 'Female', 40),
	('Carlos', 'Ignacio', 'Garcia', 'Male', 45),
	('Luisa', 'Juana', 'Tan', 'Female', 50),
	('Pedro', 'Pio', 'Reyes', 'Male', 55),
	('Elena', 'Luisa', 'Lim', 'Female', 28),
	('Francisco', 'Pilar', 'Santos', 'Male', 32),
	('Gloria', 'Josefa', 'Santos', 'Female', 42);
	
CREATE TABLE tb_OrderDetails (
    OrderDetailID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL
);

INSERT INTO tb_OrderDetails (OrderID, ProductID, Quantity) VALUES
	(10248, 11, 12),
	(10248, 42, 10),
	(10248, 72, 5),
	(10249, 14, 9),
	(10249, 51, 40),
	(10250, 41, 10),
	(10250, 51, 35),
	(10250, 65, 15),
	(10251, 22, 6);
	
CREATE TABLE tb_OrderID (
    OrderID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    EmployeeID INT NOT NULL,
    OrderDate DATE NOT NULL,
    ShipperID INT NOT NULL
);

INSERT INTO tb_OrderID (OrderID, CustomerID, EmployeeID, OrderDate, ShipperID) VALUES
	(10248, 90, 5, '1996-07-04', 3),
	(10249, 81, 6, '1996-07-05', 1),
	(10250, 34, 4, '1996-07-08', 2),
	(10251, 84, 3, '1996-07-08', 1),
	(10252, 76, 4, '1996-07-09', 2),
	(10253, 34, 3, '1996-07-10', 2),
	(10254, 14, 5, '1996-07-11', 2),
	(10255, 68, 9, '1996-07-12', 3),
	(10256, 88, 3, '1996-07-15', 2),
	(10257, 35, 4, '1996-07-16', 3);
	
CREATE TABLE tb_Products (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(100) NOT NULL,
    SupplierID INT NOT NULL,
    CategoryID INT NOT NULL,
    Unit VARCHAR(100) NOT NULL,
    Price DECIMAL(10, 2) NOT NULL
);

INSERT INTO tb_Products (ProductID, ProductName, SupplierID, CategoryID, Unit, Price) VALUES
	(1, 'Chais', 1, 1, '10 boxes x 20 bags', 18.00),
	(2, 'Chang', 1, 1, '24 - 12 oz bottles', 19.00),
	(3, 'Aniseed Syrup', 1, 2, '12 - 550 ml bottles', 10.00),
	(4, 'Chef Anton\'s Cajun Seasoning', 2, 2, '48 - 6 oz jars', 22.00),
	(5, 'Chef Anton\'s Gumbo Mix', 2, 2, '36 boxes', 21.35),
	(6, 'Grandma\'s Boysenberry Spread', 3, 2, '12 - 8 oz jars', 25.00),
	(7, 'Uncle Bob\'s Organic Dried Pears', 3, 7, '12 - 1 lb pkgs.', 30.00),
	(8, 'Northwoods Cranberry Sauce', 3, 2, '12 - 12 oz jars', 40.00),
	(9, 'Mishi Kobe Niku', 4, 6, '18 - 500g pkgs.', 97.00),
	(10, 'Ikura', 4, 8, '12 - 200 ml jars', 31.00);
	
CREATE TABLE tb_Shippers (
    ShipperID INT PRIMARY KEY,
    ShipperName VARCHAR(100) NOT NULL,
    Phone VARCHAR(20) NOT NULL
);

INSERT INTO tb_Shippers (ShipperID, ShipperName, Phone) VALUES
	(1, 'Speedy Express', '(503) 555-9831'),
	(2, 'United Package', '(503) 555-3199'),
	(3, 'Federal Shipping', '(503) 555-9931');

CREATE TABLE tb_Suppliers (
    SupplierID INT PRIMARY KEY,
    SupplierName VARCHAR(100) NOT NULL,
    ContactName VARCHAR(100) NOT NULL,
    Address VARCHAR(100) NOT NULL,
    City VARCHAR(100) NOT NULL,
    PostalCode VARCHAR(20) NOT NULL,
    Country VARCHAR(50) NOT NULL,
    Phone VARCHAR(20) NOT NULL
);

INSERT INTO tb_Suppliers (SupplierID, SupplierName, ContactName, Address, City, PostalCode, Country, Phone) VALUES
	(1, 'Exotic Liquid', 'Charlotte Cooper', '49 Gilbert St.', 'Londona', 'EC1 4SD', 'UK', '(171) 555-2222'),
	(2, 'New Orleans Cajun Delights', 'Shelley Burke', 'P.O. Box 78934', 'New Orleans', '70117', 'USA', '(100) 555-4822'),
	(3, 'Grandma Kelly\'s Homestead', 'Regina Murphy', '707 Oxford Rd.', 'Ann Arbor', '48104', 'USA', '(313) 555-5735'),
	(4, 'Tokyo Traders', 'Yoshi Nagase', '9-8 Sekimai Musashino-shi', 'Tokyo', '100', 'Japan', '(03) 3555-5011'),
	(5, 'Cooperativa de Quesos \'Las Cabras\'', 'Antonio del Valle Saavedra', 'Calle del Rosal 4', 'Oviedo', '33007', 'Spain', '(98) 598 76 54'),
	(6, 'Mayumi\'s', 'Mayumi Ohno', '92 Setsuko Chuo-ku', 'Osaka', '545', 'Japan', '(06) 431-7877'),
	(7, 'Pavlova, Ltd.', 'Ian Devling', '74 Rose St. Moonie Ponds', 'Melbourne', '3058', 'Australia', '(03) 444-2343'),
	(8, 'Specialty Biscuits, Ltd.', 'Peter Wilson', '29 King\'s Way', 'Manchester', 'M14 GSD', 'UK', '(161) 555-4448'),
	(9, 'PB Knäckebröd AB', 'Lars Peterson', 'Kaloadaga tan 13', 'Göteborg', 'S-345 67', 'Sweden', '031-987 65 43'),
	(10, 'Refrescos Americanas LTDA', 'Carlos Diaz', 'Av. das Americanas 12.890', 'São Paulo', '5442', 'Brazil', '(11) 555 4640');