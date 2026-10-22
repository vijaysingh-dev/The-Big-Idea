## 1. Order of Execution of a Query

| Written order | Executed order |
|---|---|
| `SELECT [DISTINCT] cols, AGG(col)` | 1. `FROM` + `JOIN` |
| `FROM mytable` | 2. `WHERE` |
| `JOIN othertable ON a.col = b.col` | 3. `GROUP BY` |
| `WHERE condition` | 4. `HAVING` |
| `GROUP BY col` | 5. `SELECT` |
| `HAVING condition` | 6. `DISTINCT` |
| `ORDER BY col ASC/DESC` | 7. `ORDER BY` |
| `LIMIT n OFFSET m` | 8. `LIMIT / OFFSET` |

- **Why it matters:** a column alias created in `SELECT` (step 5) **can't be used in `WHERE`** (step 2), but **can be used in `ORDER BY`** (step 7).
- `WHERE` filters rows *before* grouping. `HAVING` filters groups *after* grouping. Put every filter you can in `WHERE`, because fewer rows reach the grouping step.
- This is the *logical* order. The query optimizer (the DB component that picks the actual execution strategy) may physically reorder steps, for example by pushing filters down into joins.

---

## 2. SQL Command Categories

| Category                                              | Commands                                                                              |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **DDL** (Data Definition Language): defines structure | `CREATE`, `ALTER`, `DROP`, `RENAME`, `TRUNCATE`, `COMMENT`                            |
| **DML** (Data Manipulation Language): works on data   | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `CALL`, `EXPLAIN PLAN`, `LOCK TABLE` |
| **TCL** (Transaction Control Language)                | `COMMIT`, `ROLLBACK`, `SAVEPOINT`, `SET TRANSACTION`                                  |
| **DCL** (Data Control Language): permissions          | `GRANT`, `REVOKE`                                                                     |

- Many references split `SELECT` into its own category, **DQL** (Data Query Language).

---

## 3. Basics

- **Schema:** information about the database and table layout and properties.
- `DISTINCT` applies to **all selected columns together**, not just the first one. `SELECT DISTINCT a, b` gives unique `(a, b)` pairs.

### Limiting results
```sql
SELECT prod_name FROM Products
LIMIT 3 OFFSET 5;     -- skip 5 rows, return the next 3
```
- `OFFSET` is where fetching starts. The first row is **0**, not 1.
- MySQL shorthand `LIMIT x, y` means **offset x, limit y** (reversed). So `LIMIT 3 OFFSET 5` = `LIMIT 5, 3`, **not** `LIMIT 3, 5`.
- Syntax differs by DB: SQL Server uses `TOP n` or `OFFSET … FETCH NEXT n ROWS ONLY`; Oracle 12c+ uses `FETCH FIRST n ROWS ONLY`.
- **Pagination pitfall:** large `OFFSET` values are slow, because the DB still reads and discards every skipped row. Production systems use **keyset pagination** instead (also called seek pagination: remember the last seen key and query `WHERE id > :last_id ORDER BY id LIMIT 20`).

### Comments
```sql
-- single-line comment
#  single-line comment (MySQL only)
/* multi-line
   comment */
```

---

## 4. Sorting

- `ORDER BY` must be the **last clause** in a `SELECT` (except `LIMIT`/`OFFSET`/`FETCH`).
- `ORDER BY` can use a column that isn't in the `SELECT` list.
```sql
SELECT prod_id, prod_price, prod_name FROM Products
ORDER BY 2, 3 DESC;
```
- `DESC` only applies to the column it directly follows (here, column 3 = `prod_name`). Put `DESC` after **every** column you want descending.
- Ordering by position number (`2, 3`) breaks silently when someone changes the select list. Use column names in real code.
- Without `ORDER BY`, row order is **not guaranteed**, even if results look sorted.
- Where NULLs sort (first or last) depends on the DB. Postgres and Oracle support `NULLS FIRST / NULLS LAST`.

---

## 5. Filtering (WHERE)

- `col BETWEEN val1 AND val2` includes both `val1` and `val2`.
- NULL check: `WHERE cust_email IS NULL` (never `= NULL`).
- Use parentheses `()` when mixing `AND` and `OR`. `AND` binds tighter than `OR`.
- Single quotes are used for strings **and date literals**; numbers don't take quotes.
- Prefer `IN (...)` over a chain of `OR`s: it's cleaner and lets you embed a subquery. Speed is usually identical on modern optimizers.
- `WHERE NOT vend_id = 'DLL01'` is the same as `vend_id <> 'DLL01'`.

### NULL and three-valued logic
- SQL logic has three values: TRUE, FALSE and **UNKNOWN**. Any comparison with NULL (`= NULL`, `<> NULL`, `> NULL`) is UNKNOWN, and `WHERE` keeps only TRUE rows.
- **Classic bug:** `WHERE id NOT IN (SELECT x FROM t)` returns **zero rows** if `t.x` contains even one NULL. Use `NOT EXISTS` instead.
- `COALESCE(a, b, c)` returns the first non-NULL argument. `NULLIF(a, b)` returns NULL when `a = b` (useful to avoid divide-by-zero: `x / NULLIF(y, 0)`).

---

## 6. Wildcards (with LIKE)

Wildcards are special characters used to match parts of a value. They only work with `LIKE`.

- `%` matches any number (including 0) of any characters. It can sit anywhere: `'b%@forta.com'`.
  - `'Fish%'` ≠ `'fish%'` only in **case-sensitive** DBs/collations (Postgres, Oracle). MySQL and SQL Server are case-insensitive by default.
  - `'%bean bag%'` matches the text anywhere.
  - `'F%y'` won't match `'Fish bean bag toy  '` if trailing spaces are stored (fixed-width `CHAR`). Use `'F%y%'` or `TRIM()`.
  - `'%'` will **not** match NULL.
- `_` matches exactly one character.
- `[]` character sets (`'[JM]%'`) work only in SQL Server.
- A **leading** wildcard (`'%abc'`) can't use a normal index, so it causes a full table scan (reading every row). For heavy text search, use full-text search features.
- To match a literal `%` or `_`: `LIKE '50\%' ESCAPE '\'`.

---

## 7. Calculated Fields and Functions

- Concatenation: `+` in SQL Server; `||` in Oracle, SQLite and Postgres; `CONCAT(a, b, …)` in MySQL (and most others).
- Trimming: `RTRIM()`, `LTRIM()`, `TRIM()`.
- Aliases: `AS` names a column or derived column. `AS` is optional in many DBs.
- Function names and behavior vary a lot across DBs. Check the documentation.
- Common function families: string (`UPPER`, `LOWER`, `SUBSTRING`, `LENGTH`, `REPLACE`), date (`CURRENT_DATE`, `EXTRACT(YEAR FROM d)`, `DATE_TRUNC`), numeric (`ROUND`, `ABS`, `MOD`), conversion (`CAST(x AS INTEGER)`).
- **Wrapping an indexed column in a function** (`WHERE YEAR(order_date) = 2024`) usually stops the index from being used. Rewrite as a range: `WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'`. This kind of rewrite is called keeping the predicate **sargable** (Search-ARGument-able, meaning the DB can use an index to evaluate it).

---

## 8. Aggregate Functions

- `COUNT(col)` ignores rows where `col` is NULL. `COUNT(*)` counts every row.
- `AVG`, `COUNT(col)`, `MIN`, `MAX` and `SUM` ignore NULLs. The exception is `COUNT(*)`.
```sql
SELECT SUM(item_price * quantity) AS total_price
FROM OrderItems
WHERE order_num = 20005;

SELECT AVG(DISTINCT prod_price) AS avg_price FROM Products;

SELECT COUNT(*)        AS num_items,
       MIN(prod_price) AS price_min,
       MAX(prod_price) AS price_max,
       AVG(prod_price) AS price_avg
FROM Products;
```
- `AVG` of an integer column may do integer division in some DBs (Postgres doesn't; SQL Server does). Cast first if needed.
- `SUM` over zero rows returns NULL, not 0. Wrap in `COALESCE(SUM(x), 0)`.

---

## 9. GROUP BY and HAVING

GROUP BY rules:
1. Every column in `GROUP BY` must be a retrieved column or a valid expression (not an aggregate). If you use an expression in `SELECT`, specify the same expression in `GROUP BY`. The note "aliases can't be used" is standard SQL; MySQL and Postgres do allow aliases in `GROUP BY`.
2. Apart from aggregates, every column in `SELECT` must appear in `GROUP BY`. Postgres relaxes this when you group by a primary key. Old MySQL modes silently returned a random value, which is a source of real bugs.
3. NULLs in the grouping column form **one** group.

- `HAVING` supports all of `WHERE`'s operators.
- A subquery used with `IN` or `=` must return **one column**. A subquery in `FROM` (a "derived table") or inside `EXISTS` can return many columns.

---

## 10. Joins

```sql
-- Equijoin (old style; avoid)
SELECT vend_name, prod_name, prod_price
FROM Vendors, Products
WHERE Vendors.vend_id = Products.vend_id;

-- Preferred: explicit INNER JOIN
SELECT vend_name, prod_name, prod_price
FROM Vendors
INNER JOIN Products ON Vendors.vend_id = Products.vend_id;
```
- Oracle doesn't allow `AS` for table aliases: write `Customers C`, not `Customers AS C`.
- Why the explicit syntax is preferred: in the old comma style, forgetting the `WHERE` produces a **Cartesian product** (every row paired with every row), which silently explodes the result size.

| Join | Returns |
|---|---|
| `(INNER) JOIN` | Rows with matching values in both tables |
| `LEFT (OUTER) JOIN` | All rows from the left table + matches from the right (NULL where no match) |
| `RIGHT (OUTER) JOIN` | All rows from the right table + matches from the left |
| `FULL (OUTER) JOIN` | All rows from both, matched where possible (MySQL has no `FULL JOIN`; emulate it with `LEFT JOIN UNION RIGHT JOIN`) |

### Joins that were missing
- **Self join:** a table joined to itself, e.g. employees and their managers: `FROM emp e JOIN emp m ON e.manager_id = m.id`.
- **CROSS JOIN:** every combination of rows. Useful for generating grids (all dates × all products).
- **Anti join** (rows with no match): `LEFT JOIN … WHERE right.id IS NULL`, or `NOT EXISTS`.
- **Pitfall:** filtering the right table of a `LEFT JOIN` in `WHERE` (`WHERE p.status = 'active'`) turns it back into an inner join. Put that condition in `ON` instead.
- **Pitfall:** joining one-to-many and then `SUM`ming duplicates values. Aggregate in a subquery first, then join.

---

## 11. UNION (Combining Queries)

1. Each query in a `UNION` must have the same number of columns, with compatible types, in the same order.
2. Column **names** come from the first `SELECT`. Queries with a different number of columns cause an error.
3. Only one `ORDER BY`, placed after the last `SELECT`, and it sorts the whole combined result.

- `UNION` removes duplicate rows. Use `UNION ALL` to keep all rows; it's also faster because it skips the de-duplication step.
- `INTERSECT` returns rows in both results; `EXCEPT` (`MINUS` in Oracle) returns rows in the first but not the second.

---

## 12. Inserting Data

```sql
-- 1. Complete rows (values in column order; use NULL for no value)
INSERT INTO table_name
VALUES (val_first_col, …, val_last_col);

-- 2. Partial rows (preferred: survives table changes)
INSERT INTO Customers (cust_id, cust_name, cust_address)
VALUES (1000000006, 'Toy Land', '123 Any Street');

-- 3. Retrieved data
INSERT INTO Customers (cust_id, cust_contact, cust_email)
SELECT cust_id, cust_contact, cust_email FROM NewCust;
```
- In `INSERT … SELECT`, column **position** is used, not the name.
- Copying a table: `CREATE TABLE CustCopy AS SELECT * FROM Customers;` (SQL Server: `SELECT * INTO CustCopy FROM Customers;`). This copies data, but **not** indexes, constraints or defaults.
- **Always list columns explicitly.** Form 1 breaks the day someone adds a column.
- **Upsert** (insert, or update if the row already exists):
  - Postgres/SQLite: `INSERT … ON CONFLICT (id) DO UPDATE SET …`
  - MySQL: `INSERT … ON DUPLICATE KEY UPDATE …`
  - SQL Server/Oracle: `MERGE`
- Multi-row insert: `VALUES (…), (…), (…)` is far faster than many single inserts.

---

## 13. Updating and Deleting Data

**Always use `WHERE`** with `UPDATE` and `DELETE`, or you change or delete every row.
```sql
UPDATE Customers
SET cust_email = 'kim@thetoystore.com', cust_contact = 'Sam Roberts'
WHERE cust_id = 1000000005;

-- Delete a column's value: set it to NULL (empty string '' is not recommended)
UPDATE Customers SET cust_email = NULL WHERE cust_id = 1000000005;

DELETE FROM Customers WHERE cust_id = 1000000006;
```
- Safe habit: run the same `WHERE` as a `SELECT` first, and run risky changes inside a transaction.
- `DELETE` vs `TRUNCATE` vs `DROP`:

| | Removes | WHERE? | Speed | Notes |
|---|---|---|---|---|
| `DELETE` | Rows | Yes | Slow (logs every row) | Fires triggers |
| `TRUNCATE` | All rows | No | Fast | Resets auto-increment; usually no triggers |
| `DROP` | The whole table | No | Fast | Structure is gone too |

- Large production deletes are done **in batches** (e.g. 10,000 rows at a time) to avoid long locks and huge transaction logs.

---

## 14. Creating, Altering and Dropping Tables

```sql
CREATE TABLE OrderItems (
    order_num   INTEGER       NOT NULL,
    order_item  INTEGER       NOT NULL,
    prod_id     CHAR(10)      NOT NULL,
    quantity    INTEGER       NOT NULL DEFAULT 1,
    item_price  DECIMAL(8,2)  NOT NULL,
    PRIMARY KEY (order_num, order_item)
);

ALTER TABLE Vendors ADD vend_phone CHAR(20);
ALTER TABLE Vendors DROP COLUMN vend_phone;

ALTER TABLE table_name RENAME TO new_table_name;
ALTER TABLE table_name RENAME COLUMN old_name TO new_name;

DROP TABLE CustCopy;
```
- In your notes `order_num` was the sole `PRIMARY KEY`, but an order has many items, so the key must be **composite** (`order_num, order_item`).
- `DECIMAL(8,2)` = 8 digits total, 2 after the decimal point. Use `DECIMAL` for money, never `FLOAT` (floats can't represent 0.1 exactly).
- `CHAR(n)` is fixed width and padded with spaces; `VARCHAR(n)` is variable width. Prefer `VARCHAR` unless lengths are truly fixed.
- In production, schema changes go through **migrations** (versioned, reviewed scripts run by a tool such as Flyway, Liquibase, Alembic or Prisma Migrate). On big tables, some `ALTER`s lock the table for minutes.

---

## 15. Views

A view is a virtual table: a saved query, re-run every time it's used (dynamic).
```sql
CREATE VIEW view_name AS SELECT …;
DROP VIEW view_name;
```
- To update a view, most DBs support `CREATE OR REPLACE VIEW` (SQL Server: `CREATE OR ALTER VIEW`), so you don't have to drop and recreate it.
- Uses: hide complex joins, expose a limited set of columns for security.
- **Materialized view:** stores the result physically and is refreshed on demand. Fast reads, stale data.

---

## 16. Stored Procedures

```sql
-- Execute
EXECUTE AddNewProduct('JTS01', 'Stuffed Eiffel Tower', 6.49);

-- Create (Oracle)
CREATE PROCEDURE MailingListCount (
    ListCount OUT INTEGER        -- OUT: value passed back to the caller
)
IS
    v_rows INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_rows
    FROM Customers
    WHERE NOT cust_email IS NULL;
    ListCount := v_rows;
END;

-- Call it (Oracle)
var ReturnValue NUMBER
EXEC MailingListCount(:ReturnValue);
SELECT ReturnValue;
```
- Parameter modes: `IN` (input, the default), `OUT` (output), `IN OUT` (both).
- Syntax is very DB-specific (PL/SQL for Oracle, T-SQL for SQL Server, PL/pgSQL for Postgres).
- Tradeoff: they reduce network round trips and keep logic close to the data, but they're harder to version, test and debug than app code. Many modern teams keep business logic in the application.
- **Triggers:** code the DB runs automatically on `INSERT`/`UPDATE`/`DELETE` (e.g. for audit logs). Powerful, but logic hidden in triggers surprises people.

---

## 17. Transactions

1. **Transaction:** a block of SQL statements that succeeds or fails as one unit.
2. **Rollback:** undoing the specified statements.
3. **Commit:** writing unsaved statements to the database.
4. **Savepoint:** a temporary placeholder inside a transaction that you can roll back to.

- `INSERT`, `UPDATE` and `DELETE` can be rolled back.
- Whether `CREATE`/`DROP` can be rolled back **depends on the DB**: Oracle and MySQL auto-commit DDL (no rollback), but **Postgres and SQL Server DDL is transactional** and can be rolled back.

```sql
-- Oracle
SET TRANSACTION;
DELETE FROM OrderItems WHERE order_num = 12345;
DELETE FROM Orders     WHERE order_num = 12345;
COMMIT;

DELETE FROM Orders;
ROLLBACK;

SAVEPOINT delete1;
ROLLBACK TO delete1;
```
- Starting a transaction: `BEGIN` (Postgres), `START TRANSACTION` (MySQL), `BEGIN TRANSACTION` (SQL Server).
- **ACID**, the guarantees a transaction gives:
  - **Atomicity:** all or nothing.
  - **Consistency:** constraints hold before and after.
  - **Isolation:** concurrent transactions don't see each other's half-done work.
  - **Durability:** once committed, data survives a crash.
- **Isolation levels** (from weakest to strongest): Read Uncommitted → Read Committed (Postgres/Oracle default) → Repeatable Read (MySQL InnoDB default) → Serializable. Higher isolation means fewer anomalies but more blocking or retries.
  - Anomalies: **dirty read** (seeing uncommitted data), **non-repeatable read** (the same row changes between two reads), **phantom read** (new rows appear in a repeated query).
- Keep transactions **short**. A long transaction holds locks and blocks other queries.
- `SELECT … FOR UPDATE` locks the selected rows, so two requests can't both read "balance = 100" and both spend it.

---

## 18. Cursors

A cursor lets you step through a result set **row by row**.
```sql
DECLARE CURSOR CustCursor IS
SELECT * FROM Customers WHERE cust_email IS NULL;

OPEN CustCursor;
FETCH CustCursor INTO …;     -- the missing step: reads one row
CLOSE CustCursor;
```
- It's `OPEN CustCursor`, not `OPEN CURSOR CustCursor`.
- Cursors are slow (row-by-row processing). Prefer set-based SQL (one statement over all rows) whenever possible.

---

## 19. Constraints

```sql
-- Primary key
ALTER TABLE Vendors ADD CONSTRAINT pk_vendors PRIMARY KEY (vend_id);

-- Foreign key
CREATE TABLE Orders (
    order_num   INTEGER   NOT NULL PRIMARY KEY,
    order_date  DATETIME  NOT NULL,
    cust_id     CHAR(10)  NOT NULL REFERENCES Customers(cust_id)
);
ALTER TABLE Orders
ADD CONSTRAINT fk_orders_cust FOREIGN KEY (cust_id) REFERENCES Customers(cust_id);

-- Check
quantity INTEGER NOT NULL CHECK (quantity > 0),
ALTER TABLE Customers ADD CONSTRAINT chk_gender CHECK (gender IN ('M', 'F'));
```
- `LIKE '[MF]'` only works in SQL Server. `IN ('M','F')` works everywhere.
- `UNIQUE`: no duplicates allowed, but (unlike a primary key) NULLs are allowed, and a table can have many.
- Foreign key actions: `ON DELETE CASCADE` (deleting a parent deletes its children), `ON DELETE SET NULL`, `ON DELETE RESTRICT` (block the delete).
- Name your constraints (`pk_`, `fk_`, `chk_`). Error messages become readable and they're easy to drop later.

---

## 20. Indexes

```sql
CREATE INDEX prod_name_ind ON Products (prod_name);
```
- An index is a sorted lookup structure (usually a **B-tree**, a balanced tree that finds a value in a few steps) that avoids scanning the whole table.
- Tradeoff: faster reads, slower writes (every `INSERT`/`UPDATE` must update the index), plus extra storage.
- **Composite index** `(a, b, c)` follows the **leftmost prefix rule**: it helps queries filtering on `a`, `a+b` or `a+b+c`, but **not** `b` alone.
- **Covering index:** contains every column the query needs, so the DB never reads the table itself.
- Index columns used in `WHERE`, `JOIN` and `ORDER BY`. Columns with few distinct values (like a boolean) rarely benefit.
- Check whether the index is used with `EXPLAIN` (Postgres: `EXPLAIN ANALYZE` actually runs the query and shows real timings).

---

## 21. CASE

```sql
-- 1. Simple CASE (compares one value)
SELECT CASE status
         WHEN 'A' THEN 'Active'
         WHEN 'I' THEN 'Inactive'
         ELSE 'Unknown'
       END AS status_label
FROM t;

-- 2. Searched CASE (any condition)
SELECT CASE
         WHEN price < 10  THEN 'cheap'
         WHEN price < 100 THEN 'mid'
         ELSE 'premium'
       END AS price_band
FROM t;
```
- No comma between `WHEN` branches.
- The first matching branch wins. Without `ELSE`, no match gives NULL.
- Conditional aggregation (pivoting rows into columns): `SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END) AS paid_total`.

---

## 22. CTEs (Common Table Expressions)

A named temporary result defined with `WITH`, readable top to bottom instead of nested subqueries.
```sql
WITH monthly AS (
    SELECT cust_id, DATE_TRUNC('month', order_date) AS m, SUM(amount) AS total
    FROM Orders
    GROUP BY cust_id, DATE_TRUNC('month', order_date)
)
SELECT * FROM monthly WHERE total > 1000;
```
- **Recursive CTE** walks hierarchies (org charts, category trees):
```sql
WITH RECURSIVE chain AS (
    SELECT id, manager_id, name FROM emp WHERE id = 1
    UNION ALL
    SELECT e.id, e.manager_id, e.name
    FROM emp e JOIN chain c ON e.manager_id = c.id
)
SELECT * FROM chain;
```

---

## 23. Window Functions

Like aggregates, but they **don't collapse rows**: each row keeps its identity and gets a value computed over a "window" of related rows. This is the most-asked advanced SQL topic in interviews.
```sql
SELECT emp_name, dept, salary,
       ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn,
       RANK()       OVER (PARTITION BY dept ORDER BY salary DESC) AS rnk,
       SUM(salary)  OVER (PARTITION BY dept)                     AS dept_total,
       LAG(salary)  OVER (ORDER BY hire_date)                    AS prev_salary
FROM emp;
```
- `PARTITION BY` is like `GROUP BY`, but without collapsing rows. `ORDER BY` inside `OVER` orders rows within each partition.
- `ROW_NUMBER` gives 1,2,3,4. `RANK` gives 1,2,2,4 (gaps after ties). `DENSE_RANK` gives 1,2,2,3.
- `LAG`/`LEAD` read the previous/next row (great for day-over-day change).
- Running total: `SUM(amount) OVER (ORDER BY order_date)`.
- **Top-N per group** (very common): wrap it, then filter, because window functions are computed after `WHERE`:
```sql
SELECT * FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn FROM emp
) t WHERE rn <= 3;
```

---

## 24. EXISTS vs IN

```sql
SELECT * FROM Customers c
WHERE EXISTS (SELECT 1 FROM Orders o WHERE o.cust_id = c.cust_id);
```
- `EXISTS` stops at the first match and handles NULLs safely.
- Prefer `NOT EXISTS` over `NOT IN` (see the NULL bug in section 5).

---

## 25. Normalization (in brief)

Organizing tables to avoid storing the same fact twice.
- **1NF:** atomic values, no repeating groups (no `phone1, phone2, phone3` columns).
- **2NF:** every non-key column depends on the **whole** composite key.
- **3NF:** non-key columns depend only on the key, not on other non-key columns.
- Production reality: OLTP systems (Online Transaction Processing, the live app database) are normalized. Analytics warehouses are deliberately **denormalized** (star schema) to avoid joins at read time.

---

## 26. Security: SQL Injection

Never build SQL by string concatenation with user input:
```python
# vulnerable
cur.execute("SELECT * FROM users WHERE name = '" + name + "'")
# safe: parameterized query
cur.execute("SELECT * FROM users WHERE name = %s", (name,))
```
- **Parameterized queries** send data separately from the SQL text, so input can never be interpreted as SQL.
- Give app accounts the minimum permissions they need (`GRANT SELECT, INSERT` only, never superuser).

---

## Quick Pitfall Checklist
- [ ] = NULL instead of IS NULL
- [ ] `NOT IN` with a subquery that can return NULL
- [ ] `UPDATE`/`DELETE` without `WHERE`
- [ ] Filtering the right table of a `LEFT JOIN` in `WHERE`
- [ ] A function on an indexed column in `WHERE`
- [ ] Large `OFFSET` pagination
- [ ] `SUM` after a one-to-many join (double counting)
- [ ] Relying on row order without `ORDER BY`
- [ ] `FLOAT` for money
