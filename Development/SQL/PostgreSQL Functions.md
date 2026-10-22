## Numeric Types

| **Function** | **Syntax** | **Usage** |
| ------------ | ---------- | --------- |
| `ABS` | `ABS(value)` | Returns absolute value of a number |
| `ROUND` | `ROUND(value, decimal_places)` | Rounds to nearest decimal place |
| `CEIL` / `CEILING` | `CEIL(value)` | Smallest integer ≥ value |
| `FLOOR` | `FLOOR(value)` | Largest integer ≤ value |
| `POWER` | `POWER(x, y)` | x raised to the power y |
| `MOD` | `MOD(x, y)` | Remainder of x / y |
| `TRUNC` | `TRUNC(value, decimal_places)` | Truncates without rounding |

---
<br>

## String Types (`TEXT`, `VARCHAR`, etc.)

| **Function** | **Syntax** | **Usage** |
| ------------ | ---------- | --------- |
| `LENGTH` | `LENGTH(string)` | Number of characters in string |
| `LOWER` / `UPPER` | `LOWER(string)` | Converts to lowercase/uppercase |
| `TRIM` | `TRIM([LEADING | TRAILING | BOTH] chars FROM string)` | Removes characters from ends |
| `SUBSTRING` | `SUBSTRING(string FROM start FOR length)` | Extracts substring |
| `POSITION` | `POSITION(substring IN string)` | Index of substring |
| `REPLACE` | `REPLACE(string, from, to)` | Replaces all occurrences |
| `CONCAT` | `CONCAT(str1, str2, ...)` | Joins multiple strings |
| `LEFT` / `RIGHT` | `LEFT(string, n)` | First/last n characters |

---
<br>

## Date/Time Types

| **Function** | **Syntax** | **Usage** |
| ------------ | ---------- | --------- |
| `NOW()` | `NOW()` | Current timestamp |
| `CURRENT_DATE` | `CURRENT_DATE` | Current date |
| `CURRENT_TIME` | `CURRENT_TIME` | Current time |
| `AGE` | `AGE(timestamp)` | Interval from current time |
| `DATE_TRUNC` | `DATE_TRUNC('unit', timestamp)` | Truncates to unit (e.g., 'month') |
| `EXTRACT` | `EXTRACT(unit FROM timestamp)` | Gets part of date/time |
| `TO_CHAR` | `TO_CHAR(timestamp, format)` | Formats date/time as string |
| `TO_DATE` | `TO_DATE(text, format)` | Converts text to date |

---
<br>

## Boolean

| **Function** | **Syntax** | **Usage** |
| ------------ | ---------- | --------- |
| `NOT` | `NOT value` | Logical negation |
| `TRUE`, `FALSE` | Constants | Boolean true/false values |
| `value IS TRUE/FALSE/UNKNOWN` | `x IS TRUE` | Three-valued logic checks |

---
<br>

## JSON / JSONB

| **Function** | **Syntax** | **Usage** |
| ------------ | ---------- | --------- |
| `->` | `json->key` | Gets JSON object field as JSON |
| `->>` | `json->>key` | Gets JSON object field as text |
| `#>` | `json#>'{path}'` | Extracts JSON object at path |
| `#>>` | `json#>>'{path}'` | Extracts JSON text at path |
| `JSONB_SET` | `JSONB_SET(target, path, new_value)` | Replaces JSONB value at path |
| `TO_JSON`, `TO_JSONB` | `TO_JSON(any)` | Converts to JSON/JSONB |
| `JSON_BUILD_OBJECT` | `JSON_BUILD_OBJECT(k, v, ...)` | Builds JSON object |

---
<br>

## Array

| **Function** | **Syntax** | **Usage** |
| ------------ | ---------- | --------- |
| `ARRAY[]` | `ARRAY[1,2,3]` | Creates an array |
| `UNNEST` | `UNNEST(array)` | Expands array to rows |
| `ARRAY_LENGTH` | `ARRAY_LENGTH(array, dim)` | Length along dimension |
| `CARDINALITY` | `CARDINALITY(array)` | Total number of elements |
| `ARRAY_APPEND` | `ARRAY_APPEND(array, value)` | Appends value |
| `ARRAY_PREPEND` | `ARRAY_PREPEND(value, array)` | Prepends value |
| `ARRAY_TO_STRING` | `ARRAY_TO_STRING(array, sep)` | Joins array with separator |

---
<br>

## UUID

| **Function** | **Syntax** | **Usage** |
| ------------ | ---------- | --------- |
| `GEN_RANDOM_UUID()` | `GEN_RANDOM_UUID()` | Generates a UUID (requires `pgcrypto`) |
| `UUID` | `'uuid-string'::UUID` | Casts a string to UUID |

---
<br>

## Type Checking & Conversion

| **Function** | **Syntax** | **Usage** |
| ------------ | ---------- | --------- |
| `PG_TYPEOF` | `PG_TYPEOF(expression)` | Returns data type of expression |
| `CAST` | `CAST(value AS type)` | Converts between types |
| `::` | `value::type` | Shorthand for CAST |

---
<br>

## PostgreSQL Common Functions

| **Function**     | **Syntax**                              | **Usage**                                      |
| ---------------- | --------------------------------------- | ---------------------------------------------- |
| `COALESCE`       | `COALESCE(val1, val2, ...)`             | Returns the first non-null value               |
| `NULLIF`         | `NULLIF(val1, val2)`                    | Returns NULL if val1 = val2, else val1         |
| `GREATEST`       | `GREATEST(val1, val2, ...)`             | Returns the largest value                      |
| `LEAST`          | `LEAST(val1, val2, ...)`                | Returns the smallest value                     |
| `CASE`           | `CASE WHEN cond THEN val ELSE def END`  | Conditional logic branching                    |
| `CAST`           | `CAST(val AS type)`                     | Converts value to another type                 |
| `IS NULL`        | `val IS NULL`                           | Checks if value is NULL                        |
| `IS NOT NULL`    | `val IS NOT NULL`                       | Checks if value is NOT NULL                    |
| `RANDOM`         | `RANDOM()`                              | Returns a random float between 0 and 1         |
| `SETSEED`        | `SETSEED(seed)`                         | Sets the seed for `RANDOM()`                   |
| `NOW()`          | `NOW()`                                 | Returns current timestamp                      |
| `CURRENT_DATE`   | `CURRENT_DATE`                          | Returns current date                           |
| `CURRENT_TIME`   | `CURRENT_TIME`                          | Returns current time                           |
| `EXTRACT`        | `EXTRACT(unit FROM timestamp)`          | Extracts part of a date/time                   |
| `DATE_TRUNC`     | `DATE_TRUNC('unit', timestamp)`         | Truncates timestamp to specified unit          |
| `TO_CHAR`        | `TO_CHAR(value, format)`                | Formats value (e.g., date or number) as string |
| `TO_DATE`        | `TO_DATE(text, format)`                 | Parses text to date                            |
| `LENGTH`         | `LENGTH(string)`                        | Returns number of characters in a string       |
| `SUBSTRING`      | `SUBSTRING(string FROM start FOR len)`  | Extracts substring                             |
| `POSITION`       | `POSITION(substr IN string)`            | Finds index of substring                       |
| `REPLACE`        | `REPLACE(string, from, to)`             | Replaces substrings                            |
| `REGEXP_MATCHES` | `REGEXP_MATCHES(string, pattern)`       | Returns array of regex matches                 |
| `REGEXP_REPLACE` | `REGEXP_REPLACE(str, pattern, replace)` | Replaces regex matches                         |
| `INITCAP`        | `INITCAP(string)`                       | Capitalizes each word in string                |
| `MD5`            | `MD5(string)`                           | Returns MD5 hash of string                     |
| `ENCODE`         | `ENCODE(bytea, format)`                 | Encodes bytea to base64, hex, etc.             |
| `DECODE`         | `DECODE(text, format)`                  | Decodes base64/hex to bytea                    |
| `ARRAY_AGG`      | `ARRAY_AGG(expression)`                 | Aggregates rows into an array                  |
| `STRING_AGG`     | `STRING_AGG(expression, delimiter)`     | Joins rows into a string                       |
| `ROW_NUMBER`     | `ROW_NUMBER() OVER (ORDER BY col)`      | Assigns unique row numbers                     |
| `RANK`           | `RANK() OVER (ORDER BY col)`            | Ranks with gaps                                |
| `DENSE_RANK`     | `DENSE_RANK() OVER (ORDER BY col)`      | Ranks without gaps                             |
| `NTILE`          | `NTILE(n) OVER (ORDER BY col)`          | Divides rows into `n` groups                   |
| `LAG` / `LEAD`   | `LAG(val) OVER (...)`                   | Access previous or next row                    |
| `CUME_DIST`      | `CUME_DIST() OVER (...)`                | Cumulative distribution                        |
| `PERCENT_RANK`   | `PERCENT_RANK() OVER (...)`             | Relative percent rank                          |

---
<br>

## Example

```sql
SELECT ROUND(POWER(ABS(-5.6), 2), 1); -- Returns 31.4
SELECT TO_CHAR(NOW(), 'YYYY-MM-DD'); -- Formats date
SELECT json_data->>'name' FROM people;
```