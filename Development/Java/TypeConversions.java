import java.util.*;

public class TypeConversions {

    public static void main(String[] args) {
        // Primitive to Wrapper
        int intVal = 42;
        Integer intObj = Integer.valueOf(intVal);  // Manual boxing
        Integer intObj2 = intVal; // Autoboxing

        float floatVal = 3.14f;
        Float floatObj = Float.valueOf(floatVal);  // Manual boxing

        char charVal = 'A';
        Character charObj = Character.valueOf(charVal);

        // Wrapper to Primitive
        int intVal2 = intObj.intValue();
        float floatVal2 = floatObj.floatValue();
        char charVal2 = charObj.charValue();

        // Primitive/Wrapper to String
        String strFromInt = Integer.toString(intVal);
        String strFromFloat = Float.toString(floatVal);
        String strFromChar = Character.toString(charVal);

        // String to Primitive/Wrapper
        int intFromStr = Integer.parseInt("123");
        float floatFromStr = Float.parseFloat("3.14");
        char charFromStr = "Z".charAt(0);  // No parseChar in Java

        // Character to String and back
        Character character = 'X';
        String strChar = character.toString();
        Character charFromString = strChar.charAt(0);

        // Arrays to Lists
        String[] strArray = {"A", "B", "C"};
        List<String> strList = Arrays.asList(strArray);

        int[] intArray = {1, 2, 3};
        // List<Integer> intList = Arrays.asList(intArray); // ❌ won't work as expected
        
        // Integer[] integerArray = {1, 2, 3};
        Integer[] integerArray = Arrays.stream(intArray).boxed().toArray(Integer[]::new);
        List<Integer> intList = Arrays.asList(integerArray);

        // Lists to Arrays
        String[] newArray = strList.toArray(new String[0]);
        Integer[] newIntArray = intList.toArray(new Integer[0]);

        // List to Set
        List<String> fruits = Arrays.asList("apple", "banana", "apple");
        Set<String> fruitSet = new HashSet<>(fruits); // removes duplicates

        // Set to List
        List<String> uniqueFruits = new ArrayList<>(fruitSet);

        // Printing all for verification
        System.out.println("int to Integer: " + intObj);
        System.out.println("Integer to int: " + intVal2);
        System.out.println("float to Float: " + floatObj);
        System.out.println("Float to float: " + floatVal2);
        System.out.println("char to Character: " + charObj);
        System.out.println("Character to char: " + charVal2);
        System.out.println("int to String: " + strFromInt);
        System.out.println("String to int: " + intFromStr);
        System.out.println("char to String: " + strFromChar);
        System.out.println("String to char: " + charFromStr);
        System.out.println("Array to List: " + strList);
        System.out.println("List to Array: " + Arrays.toString(newArray));
        System.out.println("List to Array: " + Arrays.toString(newIntArray));
        System.out.println("List to Set: " + fruitSet);
        System.out.println("Set to List: " + uniqueFruits);
    }
}
