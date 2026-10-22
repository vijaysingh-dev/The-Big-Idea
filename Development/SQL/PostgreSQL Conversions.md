
# PostgreSQL Data Types and Their Conversions (Within PostgreSQL)

This document outlines how PostgreSQL data types can be converted or cast into one another using explicit or implicit casting.

---

## Numeric Type Conversions

| From Type        | To Type            | Cast Method   | Notes                            |
|------------------|--------------------|---------------|----------------------------------|
| `SMALLINT`       | `INTEGER`          | Implicit      | Safe widening                    |
| `INTEGER`        | `BIGINT`           | Implicit      | Safe widening                    |
| `SMALLINT`       | `BIGINT`           | Implicit      | Safe widening                    |
| `NUMERIC`        | `INTEGER`/`REAL`   | Explicit      | May lose precision               |
| `INTEGER`        | `NUMERIC`          | Implicit      | Safe                             |
| `REAL`           | `DOUBLE PRECISION` | Implicit      | Safe                             |
| `REAL`/`DOUBLE`  | `NUMERIC`          | Explicit      | May round                       |
| `DECIMAL`        | `NUMERIC`          | Implicit      | Treated as equivalent types      |

---

## Character Type Conversions

| From Type     | To Type      | Cast Method   | Notes                          |
|---------------|--------------|---------------|--------------------------------|
| `CHAR(n)`     | `VARCHAR(n)` | Implicit      | Safe                           |
| `VARCHAR(n)`  | `TEXT`       | Implicit      | Safe, TEXT has no length limit |
| `TEXT`        | `VARCHAR(n)` | Explicit      | May truncate if n is small     |
| `VARCHAR(n)`  | `CHAR(n)`    | Explicit      | May pad                        |

---

## Date/Time Type Conversions

| From Type         | To Type             | Cast Method   | Notes                                |
|-------------------|---------------------|---------------|--------------------------------------|
| `TIMESTAMP`       | `DATE`              | Explicit      | Extracts only the date part          |
| `TIMESTAMP`       | `TIME`              | Explicit      | Extracts only the time part          |
| `TIMESTAMPTZ`     | `TIMESTAMP`         | Explicit      | Drops timezone info                  |
| `TIMESTAMP`       | `TIMESTAMPTZ`       | Implicit      | Adds timezone (based on settings)    |
| `DATE`            | `TIMESTAMP`         | Implicit      | Time part becomes 00:00:00           |
| `INTERVAL`        | `TEXT`              | Explicit      | Converts to string format            |

---

## Boolean Conversions

| From Type   | To Type      | Cast Method   | Notes                             |
|-------------|--------------|---------------|-----------------------------------|
| `BOOLEAN`   | `TEXT`       | Implicit      | Converts to 't' or 'f'            |
| `TEXT`      | `BOOLEAN`    | Explicit      | Accepts 'true', 'false', 't', etc |
| `INTEGER`   | `BOOLEAN`    | Explicit      | 0 = false, non-zero = true        |

---

## UUID Conversions

| From Type | To Type | Cast Method | Notes                     |
|-----------|---------|-------------|---------------------------|
| `UUID`    | `TEXT`  | Implicit    | UUID to string            |
| `TEXT`    | `UUID`  | Explicit    | Must match UUID format    |

---

## JSON Conversions

| From Type | To Type | Cast Method | Notes                               |
|-----------|---------|-------------|-------------------------------------|
| `JSON`    | `JSONB` | Implicit    | Automatic                          |
| `JSONB`   | `JSON`  | Explicit    | Manual if needed                   |
| `TEXT`    | `JSON`  | Explicit    | Input must be valid JSON string    |

---

## Array Conversions

| From Type | To Type         | Cast Method | Notes                        |
|-----------|------------------|-------------|------------------------------|
| `TEXT[]`  | `VARCHAR[]`      | Implicit    | Compatible string types      |
| `INTEGER[]` | `TEXT[]`       | Explicit    | Via string representation    |

---

## Casting Syntax

```sql
-- Explicit cast
SELECT '123'::INTEGER;

-- OR using CAST()
SELECT CAST('2024-01-01' AS DATE);
```

---

## Notes

- Use `\d <table>` in `psql` to see column types.
- Use `pg_typeof()` to confirm runtime data types.
- Implicit casts are automatic; explicit ones require `CAST()` or `::`.

