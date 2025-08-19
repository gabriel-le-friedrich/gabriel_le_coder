import java.util.Scanner;

public class Ex27DiscountEligibility {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Input: Ask the user for their age
        System.out.print("Enter your age: ");
        int age = scanner.nextInt();

        // Input: Ask the user if they are a student
        System.out.print("Are you a student? (yes/no): ");
        String isStudent = scanner.next();

        // Determine discount eligibility based on age and student status
        if (age <= 12) {
            System.out.println("You are eligible for a child discount.");
        } else if (age >= 60) {
            System.out.println("You are eligible for a senior citizen discount.");
        } else if (age > 12 && age < 60) {
            if (isStudent.equalsIgnoreCase("yes")) {
                System.out.println("You are eligible for a student discount.");
            } else {
                System.out.println("You are not eligible for any discounts.");
            }
        } else {
            System.out.println("Invalid age entered.");
        }

        // Close the scanner
        scanner.close();
    }
}
