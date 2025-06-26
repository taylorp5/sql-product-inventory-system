-- Staging tables (no constraints)
CREATE TABLE staging_products (
    product_id INT,
    product_name TEXT,
    category TEXT,
    unit_price DECIMAL(10,2)
);

CREATE TABLE staging_suppliers (
    supplier_id INT,
    name TEXT,
    location TEXT
);

CREATE TABLE staging_shipments (
    shipment_id INT,
    supplier_id INT,
    product_id INT,
    quantity INT,
    shipment_date DATE
);

CREATE TABLE staging_inventory_log (
    log_id INT,
    product_id INT,
    change_type TEXT,
    quantity INT,
    change_date DATE
);

-- Final Products table
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name TEXT NOT NULL,
    category TEXT,
    unit_price DECIMAL(10,2)
);

-- Final Suppliers table
CREATE TABLE Suppliers (
    supplier_id INT PRIMARY KEY,
    name TEXT,
    location TEXT
);

-- Final Shipments table
CREATE TABLE Shipments (
    shipment_id INT PRIMARY KEY,
    supplier_id INT REFERENCES Suppliers(supplier_id),
    product_id INT REFERENCES Products(product_id),
    quantity INT,
    shipment_date DATE
);

-- Final Inventory_Log table
CREATE TABLE Inventory_Log (
    log_id INT PRIMARY KEY,
    product_id INT REFERENCES Products(product_id),
    change_type TEXT CHECK (change_type IN ('IN', 'OUT')),
    quantity INT,
    change_date DATE
);

-- Transfer from staging to final tables

INSERT INTO Products (product_id, product_name, category, unit_price)
SELECT product_id, product_name, category, unit_price
FROM staging_products;

INSERT INTO Suppliers (supplier_id, name, location)
SELECT supplier_id, name, location
FROM staging_suppliers;

INSERT INTO Shipments (shipment_id, supplier_id, product_id, quantity, shipment_date)
SELECT shipment_id, supplier_id, product_id, quantity, shipment_date
FROM staging_shipments;

INSERT INTO Inventory_Log (log_id, product_id, change_type, quantity, change_date)
SELECT log_id, product_id, change_type, quantity, change_date
FROM staging_inventory_log;

-- Drop staging tables

DROP TABLE IF EXISTS staging_products;
DROP TABLE IF EXISTS staging_suppliers;
DROP TABLE IF EXISTS staging_shipments;
DROP TABLE IF EXISTS staging_inventory_log;

--1. What are the current inventory levels for each product?
SELECT 
  p.product_name,
  SUM(
    CASE 
      WHEN il.change_type = 'IN' THEN il.quantity
      WHEN il.change_type = 'OUT' THEN -il.quantity
      ELSE 0
    END
  ) AS current_stock
FROM Products p
LEFT JOIN Inventory_Log il ON p.product_id = il.product_id
GROUP BY p.product_name
ORDER BY current_stock ASC;


--2. Which products are running low and may need restocking?
SELECT 
  p.product_name AS product,
  SUM(
    CASE 
      WHEN il.change_type = 'IN' THEN il.quantity
      WHEN il.change_type = 'OUT' THEN -il.quantity
      ELSE 0
    END
  ) AS current_stock
FROM Products p
LEFT JOIN Inventory_Log il ON p.product_id = il.product_id
GROUP BY p.product_name
HAVING SUM(
    CASE 
      WHEN il.change_type = 'IN' THEN il.quantity
      WHEN il.change_type = 'OUT' THEN -il.quantity
      ELSE 0
    END
) < 50
ORDER BY current_stock;

--3. What are the most frequently shipped products (recieved from suppliers)?

SELECT p.product_name AS product,
	SUM(s.quantity) AS total_shipped
FROM Shipments AS s
JOIN Products AS p on s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_shipped DESC;


--4. What suppliers are providing the most inventory?

SELECT 
	s.name as supplier,
	SUM(sh.quantity) AS total_units_supplied
FROM Shipments AS sh
JOIN Suppliers AS s ON sh.supplier_id = s.supplier_id
GROUP BY s.name
ORDER BY total_units_supplied DESC;


--5. What is the total inventory change (in and out) for each product over time?

SELECT 
	p.product_name AS product,
	il.change_date,
	SUM(
		CASE
			WHEN il.change_type = 'IN' THEN il.quantity
			WHEN il.change_Type = 'OUT' THEN -il.quantity
			ELSE 0
		END
	) AS net_change
FROM Inventory_log AS il
JOIN Products AS p on il.product_id = p.product_id
GROUP BY p.product_name, il.change_date
ORDER BY net_change;

--6. Which products have never been restocked?

SELECT p.product_name AS product,
il.change_type
FROM Products AS p
LEFT JOIN Inventory_Log AS il 
	ON p.product_id = il.product_id AND il.change_type = 'IN'
WHERE il.product_id IS NULL;

--7. Which suppliers have shipped the highest quantity of products?


SELECT
	s.name AS supplier,
	SUM(sh.quantity) AS total_quantity_shipped
FROM Shipments AS sh
JOIN Suppliers AS s ON sh.supplier_id = s.supplier_id
GROUP BY s.name
ORDER BY total_quantity_shipped DESC;


--8. Which products have had the highest total quantity removed from inventory ('OUT')?

SELECT 
	p.product_name AS product,
	SUM(il.quantity) AS total_removed
FROM Inventory_Log AS il
JOIN Products AS p ON il.product_id = p.product_id
WHERE il.change_type = 'OUT'
GROUP BY p.product_name
ORDER BY total_removed DESC;

--9. What is the current stock level for each product (based on INs and OUTs)?

SELECT
  p.product_name AS product,
  COALESCE(SUM(
    CASE
      WHEN il.change_type = 'IN' THEN il.quantity
      WHEN il.change_type = 'OUT' THEN -il.quantity
      ELSE 0
    END
  ), 0) AS current_stock
FROM Products AS p
LEFT JOIN Inventory_Log AS il ON p.product_id = il.product_id
GROUP BY p.product_name
ORDER BY current_stock ASC;

--10. What is the total value of current stock per product?
SELECT
  p.product_name AS product,
  COALESCE(SUM(
    CASE
      WHEN il.change_type = 'IN' THEN il.quantity
      WHEN il.change_type = 'OUT' THEN -il.quantity
      ELSE 0
    END
  ), 0) AS current_stock,
  p.unit_price,
  ROUND(
    p.unit_price * COALESCE(SUM(
      CASE
        WHEN il.change_type = 'IN' THEN il.quantity
        WHEN il.change_type = 'OUT' THEN -il.quantity
        ELSE 0
      END
    ), 0), 2
  ) AS inventory_value
FROM Products AS p
LEFT JOIN Inventory_Log AS il ON p.product_id = il.product_id
GROUP BY p.product_name, p.unit_price
ORDER BY inventory_value DESC;

