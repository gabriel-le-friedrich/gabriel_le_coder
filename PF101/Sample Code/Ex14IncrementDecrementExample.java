public class Ex14IncrementDecrementExample {
    public static void main(String[] args) {
        int a = 10;
        
        // Pre-increment
        int preIncrement = ++a;  // a becomes 11, preIncrement is 11
        System.out.println("Pre-Increment: " + preIncrement);  // Output: Pre-Increment: 11
        
        // Post-increment
        int postIncrement = a++;  // postIncrement is 11, a becomes 12
        System.out.println("Post-Increment: " + postIncrement);  // Output: Post-Increment: 11
        System.out.println("a after Post-Increment: " + a);      // Output: a after Post-Increment: 12
        
        // Pre-decrement
        int preDecrement = --a;  // a becomes 11, preDecrement is 11
        System.out.println("Pre-Decrement: " + preDecrement);  // Output: Pre-Decrement: 11
        
        // Post-decrement
        int postDecrement = a--;  // postDecrement is 11, a becomes 10
        System.out.println("Post-Decrement: " + postDecrement);  // Output: Post-Decrement: 11
        System.out.println("a after Post-Decrement: " + a);      // Output: a after Post-Decrement: 10
    }
}
