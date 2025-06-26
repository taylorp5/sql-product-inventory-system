# 🧮 SQL Product Inventory System

This project simulates a basic **product inventory system** using PostgreSQL and pgAdmin 4. It demonstrates how raw product, shipment, and inventory data can be transformed into meaningful business insights using SQL.

---

## 📌 Business Objective

A small-to-midsize retail company wants to better understand its **inventory trends**, **supplier reliability**, and **product movement**. The objective of this analysis is to:

- Track current inventory levels
- Identify low-stock and high-performing products
- Evaluate supplier contributions and shipment flows
- Measure current inventory value to guide decision-making

---

## 🗂️ Data Structure

Two layers of tables were created:

| Table Name              | Type      | Description                                                       |
|--------------------------|-----------|-------------------------------------------------------------------|
| `staging_*` tables       | Temporary | Raw imports from `.csv` files before validation/transformation    |
| `Products`               | Final     | Basic product info (name, category, unit price)                   |
| `Suppliers`              | Final     | Supplier details and locations                                    |
| `Shipments`              | Final     | Inventory received from suppliers                                 |
| `Inventory_Log`          | Final     | Product inflow/outflow by date and quantity                       |

---

## ⚙️ Data Pipeline Overview

```sql
-- Load from staging to final tables
INSERT INTO Products (...) SELECT ... FROM staging_products;
INSERT INTO Suppliers (...) SELECT ... FROM staging_suppliers;
INSERT INTO Shipments (...) SELECT ... FROM staging_shipments;
INSERT INTO Inventory_Log (...) SELECT ... FROM staging_inventory_log;

-- Clean up staging
DROP TABLE IF EXISTS staging_products;
DROP TABLE IF EXISTS staging_suppliers;
DROP TABLE IF EXISTS staging_shipments;
DROP TABLE IF EXISTS staging_inventory_log;
```

---

## 📊 Business Questions & SQL Insights

## 📦 Q1: What are the current inventory levels for each product?

```sql
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
```

✅ *Get a snapshot of stock levels per product to support reordering decisions.*

---

## ⚠️ Q2: Which products are running low and may need restocking?

```sql
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
```

📉 *Helps flag products that may soon be out of stock.*

---

## 📈 Q3: What are the most frequently shipped products (received from suppliers)?

```sql
SELECT p.product_name AS product,
  SUM(s.quantity) AS total_shipped
FROM Shipments AS s
JOIN Products AS p on s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_shipped DESC;
```

🚚 *Identifies high-demand items frequently restocked by suppliers.*

---

## 🤝 Q4: What suppliers are providing the most inventory?

```sql
SELECT 
  s.name as supplier,
  SUM(sh.quantity) AS total_units_supplied
FROM Shipments AS sh
JOIN Suppliers AS s ON sh.supplier_id = s.supplier_id
GROUP BY s.name
ORDER BY total_units_supplied DESC;
```

📦 *Understand which vendors play the largest roles in inventory supply.*

---

## 📆 Q5: What is the total inventory change (IN and OUT) for each product over time?

```sql
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
```

📊 *Track stock trends across time for each product.*

---

## ❌ Q6: Which products have never been restocked?

```sql
SELECT p.product_name AS product,
il.change_type
FROM Products AS p
LEFT JOIN Inventory_Log AS il 
  ON p.product_id = il.product_id AND il.change_type = 'IN'
WHERE il.product_id IS NULL;
```

🚨 *These may be discontinued or neglected products.*

---

## 🏆 Q7: Which suppliers have shipped the highest quantity of products?

```sql
SELECT
  s.name AS supplier,
  SUM(sh.quantity) AS total_quantity_shipped
FROM Shipments AS sh
JOIN Suppliers AS s ON sh.supplier_id = s.supplier_id
GROUP BY s.name
ORDER BY total_quantity_shipped DESC;
```

📈 *Evaluate supplier volume contribution to operations.*

---

## 📤 Q8: Which products have had the highest total quantity removed from inventory?

```sql
SELECT 
  p.product_name AS product,
  SUM(il.quantity) AS total_removed
FROM Inventory_Log AS il
JOIN Products AS p ON il.product_id = p.product_id
WHERE il.change_type = 'OUT'
GROUP BY p.product_name
ORDER BY total_removed DESC;
```

🛒 *Uncover products with high sales or usage volume.*

---

## 🔄 Q9: What is the current stock level for each product (based on INs and OUTs)?

```sql
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
```

📌 *Real-time inventory visibility after adjustments and outflows.*

---

## 💰 Q10: What is the total value of current stock per product?

```sql
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
```

📦 *Quantifies capital tied up in each product’s current stock.*

---
🧰 Tools Used
| Tool           | Purpose                                             |
| -------------- | --------------------------------------------------- |
| **PostgreSQL** | Relational database used to store and query data    |
| **pgAdmin 4**  | Graphical interface for managing PostgreSQL         |
| **Excel**      | Prepared and formatted CSV files for data import    |
| **SQL**        | Core language used for writing queries and analysis |

