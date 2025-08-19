import java.util.Scanner;

public class Ex36NumberSignChecker {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Input: Ask the user for the number of numbers to check
        System.out.print("Enter the number of numbers to check: ");
        int numberOfNumbers = scanner.nextInt();

        // Loop through each number to determine if it's positive, negative, or zero
        for (int i = 1; i <= numberOfNumbers; i++) {
            System.out.print("Enter number " + i + ": ");
            int number = scanner.nextInt();

            // Use ternary operator to determine if the number is positive, negative, or zero
            String result = (number > 0) ? "Positive" :
                            (number < 0) ? "Negative" :
                            "Zero";

            // Output the result
            System.out.println("Number " + i + " is " + result + ".");
        }

        // Close the scanner
        scanner.close();
    }
}
