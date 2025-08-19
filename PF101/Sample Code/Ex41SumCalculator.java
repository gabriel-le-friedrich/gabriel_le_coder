import java.util.Scanner;

public class Ex41SumCalculator {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        char continueInput;

        // Initialize sum
        int sum = 0;

        do {
            int number;

            // Prompt the user to enter a number
            System.out.print("Enter a positive integer to add to the sum: ");
            number = scanner.nextInt();

            // Check if the number is positive
            if (number > 0) {
                // Add the number to the sum
                sum += number;
                System.out.println("Current sum: " + sum);
            } else if (number < 0) {
                // Handle negative number
                System.out.println("Negative number detected.");
                System.out.print("Do you want to stop? (y/n): ");
                continueInput = scanner.next().charAt(0);

                // Check if the user wants to stop
                if (continueInput == 'y' || continueInput == 'Y') {
                    System.out.println("Exiting...");
                    break;
                }
            } else {
                // Handle zero or invalid input
                System.out.println("Zero is not a valid input for summation.");
            }

        } while (true);

        // Output the final sum
        System.out.println("Final sum: " + sum);

        // Close the scanner
        scanner.close();
    }
}
