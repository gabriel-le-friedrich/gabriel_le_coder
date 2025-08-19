import java.util.Scanner;

public class Ex25NumberClassification {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Input: Ask the user for a number
        System.out.print("Enter a number: ");
        int number = scanner.nextInt();

        // Classify the number as positive, negative, or zero
        if (number > 0) {
            System.out.println("The number is positive.");
            
            // Nested condition: Check if the number is even or odd
            if (number % 2 == 0) {
                System.out.println("The number is also even.");
            } else {
                System.out.println("The number is also odd.");
            }
        } else if (number < 0) {
            System.out.println("The number is negative.");
            
            // Nested condition: Check if the number is even or odd
            if (number % 2 == 0) {
                System.out.println("The number is also even.");
            } else {
                System.out.println("The number is also odd.");
            }
        } else {
            System.out.println("The number is zero.");
            System.out.println("Zero is neither positive nor negative, and it is even.");
        }

        // Close the scanner
        scanner.close();
    }
}
