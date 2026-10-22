
# PostgreSQL Data Types

This document lists common PostgreSQL data types.

## Numeric Types

| PostgreSQL Type | Description                         | Common Conversions          |
|-----------------|-------------------------------------|-----------------------------|
| `SMALLINT`      | 2-byte integer                      | INT, SHORT (Java)           |
| `INTEGER`       | 4-byte integer                      | INT, INT32                  |
| `BIGINT`        | 8-byte integer                      | LONG, INT64                 |
| `DECIMAL(p,s)`  | Exact numeric with precision/scale | NUMERIC, BIGDECIMAL (Java)  |
| `NUMERIC(p,s)`  | Exact numeric                       | DECIMAL                     |
| `REAL`          | 4-byte floating point               | FLOAT32                     |
| `DOUBLE PRECISION` | 8-byte floating point           | FLOAT64, DOUBLE             |
| `SERIAL`        | Auto-incrementing integer           | AUTO_INCREMENT (MySQL)      |
| `BIGSERIAL`     | Auto-incrementing bigint            | BIGAUTO_INCREMENT (MySQL)   |

## Character Types

| PostgreSQL Type | Description                         | Common Conversions          |
|-----------------|-------------------------------------|-----------------------------|
| `CHAR(n)`       | Fixed-length string                 | CHAR                        |
| `VARCHAR(n)`    | Variable-length string              | VARCHAR                     |
| `TEXT`          | Unlimited length text               | STRING, TEXT                |

## Date and Time Types

| PostgreSQL Type     | Description                     | Common Conversions          |
|---------------------|---------------------------------|-----------------------------|
| `DATE`              | Calendar date                   | DATE                        |
| `TIME`              | Time without timezone           | TIME                        |
| `TIMESTAMP`         | Date and time without timezone  | DATETIME                    |
| `TIMESTAMPTZ`       | Date and time with timezone     | DATETIMEOFFSET              |
| `INTERVAL`          | Time span                       | DURATION, TIMEDELTA         |

## Boolean Type

| PostgreSQL Type | Description                         | Common Conversions          |
|-----------------|-------------------------------------|-----------------------------|
| `BOOLEAN`       | True/false                         | BOOL                        |

## UUID Type

| PostgreSQL Type | Description                         | Common Conversions          |
|-----------------|-------------------------------------|-----------------------------|
| `UUID`          | Universally unique identifier       | UUID                        |

## JSON Types

| PostgreSQL Type | Description                         | Common Conversions          |
|-----------------|-------------------------------------|-----------------------------|
| `JSON`          | Textual JSON                        | JSON string                 |
| `JSONB`         | Binary-optimized JSON               | Parsed JSON object/map      |

## Arrays

| PostgreSQL Type | Description                         | Common Conversions          |
|-----------------|-------------------------------------|-----------------------------|
| `type[]`        | Array of any base type              | Lists, Arrays               |

## Geometric Types

| PostgreSQL Type | Description                         | Common Conversions          |
|-----------------|-------------------------------------|-----------------------------|
| `POINT`         | (x, y) coordinate                   | Struct/Record               |
| `LINE`, `LSEG`  | Geometric line                      | Tuple/Record                |
| `BOX`, `CIRCLE` | 2D shapes                           | Shape classes               |

## Network Types

| PostgreSQL Type | Description                         | Common Conversions          |
|-----------------|-------------------------------------|-----------------------------|
| `INET`, `CIDR`  | IP addresses                        | IP address objects          |
| `MACADDR`       | MAC address                         | MAC address string          |

## Binary Data

| PostgreSQL Type | Description                         | Common Conversions          |
|-----------------|-------------------------------------|-----------------------------|
| `BYTEA`         | Binary data                         | BLOB, BYTE ARRAY            |

## Composite & Custom Types

- PostgreSQL supports custom data types using `CREATE TYPE`.
- These map to classes, structs, or records in many programming languages.

---

**Note:** When integrating with ORMs like SQLAlchemy, Django ORM, or Prisma, these types are often abstracted to platform-native types.

