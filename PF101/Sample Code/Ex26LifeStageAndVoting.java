import java.util.Scanner;

public class Ex26LifeStageAndVoting {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Input: Ask the user for their age
        System.out.print("Enter your age: ");
        int age = scanner.nextInt();

        // Determine the life stage based on age
        if (age >= 0 && age <= 12) {
            System.out.println("You are a child.");

            // Nested condition: Check voting eligibility (not eligible for children)
            if (age >= 18) {
                System.out.println("You are eligible to vote.");
            } else {
                System.out.println("You are not eligible to vote.");
            }
        } else if (age >= 13 && age <= 19) {
            System.out.println("You are a teenager.");

            // Nested condition: Check voting eligibility
            if (age >= 18) {
                System.out.println("You are eligible to vote.");
            } else {
                System.out.println("You are not eligible to vote.");
            }
        } else if (age >= 20 && age <= 64) {
            System.out.println("You are an adult.");

            // Nested condition: Check voting eligibility (all adults are eligible)
            System.out.println("You are eligible to vote.");
        } else if (age >= 65) {
            System.out.println("You are a senior citizen.");

            // Nested condition: Check voting eligibility (all seniors are eligible)
            System.out.println("You are eligible to vote.");
        } else {
            System.out.println("Invalid age entered.");
        }

        // Close the scanner
        scanner.close();
    }
}
