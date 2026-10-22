## Summary of Conversions
| From          | To            | Method/Example                                 |
| ------------- | ------------- | ---------------------------------------------- |
| `int`         | `Integer`     | `Integer.valueOf(int)` or autoboxing           |
| `Integer`     | `int`         | `intObj.intValue()`                            |
| `float`       | `Float`       | `Float.valueOf(float)`                         |
| `Float`       | `float`       | `floatVal.floatValue()`                        |
| `char`        | `Character`   | `Character.valueOf(char)`                      |
| `Character`   | `char`        | `charObj.charValue()`                          |
| `int`/`float` | `String`      | `Integer.toString(i)` / `Float.toString(f)`    |
| `String`      | `int`/`float` | `Integer.parseInt(s)` / `Float.parseFloat(s)`  |
| `char`        | `String`      | `Character.toString(c)`                        |
| `String`      | `char`        | `s.charAt(0)`                                  |
| `Array`       | `List`        | `Arrays.asList(array)`                         |
| `List`        | `Array`       | `list.toArray(new T[0])`                       |
| `List`        | `Set`         | `new HashSet<>(list)`                          |
| `Set`         | `List`        | `new ArrayList<>(set)`                         |
<br>
## Stream Conversions
| From            | To              | Stream Code Example                                       |
| --------------- | --------------- | --------------------------------------------------------- |
| `int[]`         | `Integer[]`     | `Arrays.stream(intArray).boxed().toArray(Integer[]::new)` |
| `Integer[]`     | `int[]`         | `Arrays.stream(integerArray).mapToInt(i -> i).toArray()`  |
| `List<Integer>` | `int[]`         | `list.stream().mapToInt(Integer::intValue).toArray()`     |
| `int[]`         | `List<Integer>` | `Arrays.stream(intArray).boxed().toList()`                |
| `String[]`      | `List<String>`  | `Arrays.stream(strArray).toList()`                        |
| `List<String>`  | `String[]`      | `list.stream().toArray(String[]::new)`                    |
