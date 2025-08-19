public class Ex16ComparisonExample {
    public static void main(String[] args) {
        int a = 5;
        int b = 10;
        
        // Greater than
        boolean isAGreaterThanB = (a > b);  // false
        
        // Less than
        boolean isALessThanB = (a < b);  // true
        
        System.out.println("a > b: " + isAGreaterThanB);  // Output: a > b: false
        System.out.println("a < b: " + isALessThanB);     // Output: a < b: true
    }
}
