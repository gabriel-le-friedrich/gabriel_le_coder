import java.util.Scanner;

public class Ex22Scanner2 {
    public static void main(String[] args) {
        // Create a Scanner object to read input
        Scanner scanner = new Scanner(System.in);

        // Prompt the user to enter four numbers
        System.out.print("Enter the first number: ");
        double num1 = scanner.nextDouble();

        System.out.print("Enter the second number: ");
        double num2 = scanner.nextDouble();

        System.out.print("Enter the third number: ");
        double num3 = scanner.nextDouble();

        System.out.print("Enter the fourth number: ");
        double num4 = scanner.nextDouble();

        // Calculate the average
        double average = (num1 + num2 + num3 + num4 )/ 4;

        // Display the average
        System.out.println("\nThe average of the four numbers is: " + average);

        // Close the scanner
        scanner.close();
    }
}
