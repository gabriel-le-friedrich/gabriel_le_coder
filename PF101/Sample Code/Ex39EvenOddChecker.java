import java.util.Scanner;

public class Ex39EvenOddChecker {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        int number;

        // Use a while loop to continuously prompt the user
        while (true) {
            System.out.print("Enter a number (negative number to quit): ");
            number = scanner.nextInt();

            // Check if the number is negative to exit the loop
            if (number < 0) {
                System.out.println("Exiting...");
                break;
            }

            // Nested condition to check if the number is even or odd
            if (number % 2 == 0) {
                System.out.println("The number " + number + " is Even.");
            } else {
                System.out.println("The number " + number + " is Odd.");
            }
        }

        // Close the scanner
        scanner.close();
    }
}
