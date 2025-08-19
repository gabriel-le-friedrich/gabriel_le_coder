public class Ex15EqualityExample {
    public static void main(String[] args) {
        int a = 5;
        int b = 10;
        int c = 5;
        
        // Equality
        boolean isEqualAB = (a == b);  // false
        boolean isEqualAC = (a == c);  // true
        
        // Inequality
        boolean isNotEqualAB = (a != b);  // true
        boolean isNotEqualAC = (a != c);  // false
        
        System.out.println("a == b: " + isEqualAB);      // Output: a == b: false
        System.out.println("a == c: " + isEqualAC);      // Output: a == c: true
        System.out.println("a != b: " + isNotEqualAB);  // Output: a != b: true
        System.out.println("a != c: " + isNotEqualAC);  // Output: a != c: false
    }
}
