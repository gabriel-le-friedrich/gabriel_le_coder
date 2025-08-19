public class Ex18StringComparisonExample {
    public static void main(String[] args) {
        String str1 = "Hello";
        String str2 = "Hello";
        String str3 = "World";
        
        // Equality
        boolean isStr1EqualToStr2 = str1.equals(str2);  // true
        boolean isStr1EqualToStr3 = str1.equals(str3);  // false
        
        // Inequality
        boolean isStr1NotEqualToStr2 = !str1.equals(str2);  // false
        boolean isStr1NotEqualToStr3 = !str1.equals(str3);  // true
        
        System.out.println("str1 equals str2: " + isStr1EqualToStr2);  // Output: str1 equals str2: true
        System.out.println("str1 equals str3: " + isStr1EqualToStr3);  // Output: str1 equals str3: false
        System.out.println("str1 not equals str2: " + isStr1NotEqualToStr2);  // Output: str1 not equals str2: false
        System.out.println("str1 not equals str3: " + isStr1NotEqualToStr3);  // Output: str1 not equals str3: true
    }
}
