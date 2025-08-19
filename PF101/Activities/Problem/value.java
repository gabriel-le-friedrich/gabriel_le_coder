import java.util.Scanner;

public class value {
    private static final Scanner input = new Scanner(System.in);
    
    static double value1() {
        while (true) {
            try {
                System.out.print("Enter first number: ");
                return input.nextDouble();
            } catch (Exception e) {
                System.out.println("Incorrect input! Please try again!");
                input.next(); // Clear the invalid input
            }
        }
    }
    
    static double value2() {
        while (true) {
            try {
                System.out.print("Enter second number: ");
                return input.nextDouble();
                
            } catch (Exception e) {
                System.out.println("Incorrect input! Please try again!");
                input.next(); // Clear the invalid input
            }
        }
    }
}
