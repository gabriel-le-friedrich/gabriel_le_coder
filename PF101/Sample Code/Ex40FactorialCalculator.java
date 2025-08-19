import java.util.Scanner;

public class Ex40FactorialCalculator {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        int number;

        // Use a while loop to continuously prompt the user
        while (true) {
            System.out.print("Enter a positive integer (0 to quit): ");
            number = scanner.nextInt();

            // Check if the number is 0 to exit the loop
            if (number == 0) {
                System.out.println("Exiting...");
                break;
            }

            // Check if the number is positive
            if (number > 0) {
                int factorial = 1;

                // Calculate the factorial using a nested while loop
                int i = 1;
                while (i <= number) {
                    factorial *= i;
                    i++;
                }

                // Output the result
                System.out.println("The factorial of " + number + " is " + factorial + ".");
            } else {
                // Handle invalid input
                System.out.println("Please enter a positive integer.");
            }
        }

        // Close the scanner
        scanner.close();
    }
}
