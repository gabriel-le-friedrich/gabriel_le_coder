import java.util.Scanner;

public class Assignment {
    // Create a single Scanner object for the entire class
    private static final Scanner input = new Scanner(System.in);

    public static void main(String[] args) {
        // Get values once and store them
        double num1 = value1();
        double num2 = value2();
        
        // Calculate and display result using stored values
        double sum = num1 + num2;
        System.out.println("The sum is " + sum);
        
        input.close();
    }

    static double value1() {
        double num1 = 0;
        boolean validInput = false;

        while (!validInput) {
            System.out.print("Enter the first number: ");
            if (input.hasNextDouble()) {
                num1 = input.nextDouble();
                validInput = true;
            } else {
                System.out.println("Invalid input! Please enter a valid number.");
                input.next(); // Clear invalid input
            }
        }
        return num1;
    }

    static double value2() {
        double num2 = 0;
        boolean validInput = false;

        while (!validInput) {
            System.out.print("Enter the second number: ");
            if (input.hasNextDouble()) {
                num2 = input.nextDouble();
                validInput = true;
            } else {
                System.out.println("Invalid input! Please enter a valid number.");
                input.next(); // Clear invalid input
            }
        }
        return num2;
    }
}