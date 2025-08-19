public class Ex20ConditionExample {
    public static void main(String[] args) {
        int a = 15;
        int b = 20;
        
        if (a < b) {
            System.out.println("a is less than b");  // Output: a is less than b
        } else {
            System.out.println("a is not less than b");
        }
        
        if (a == b) {
            System.out.println("a is equal to b");
        } else {
            System.out.println("a is not equal to b");  // Output: a is not equal to b
        }
        
        if (a != b) {
            System.out.println("a is not equal to b");  // Output: a is not equal to b
        } else {
            System.out.println("a is equal to b");
        }
    }
}
