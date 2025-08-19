import java.util.Scanner;

public class Ex35AgeCategoryCheck {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Input: Ask the user for the number of people
        System.out.print("Enter the number of people: ");
        int numberOfPeople = scanner.nextInt();

        // Loop through each person to get their age and determine the category
        for (int i = 1; i <= numberOfPeople; i++) {
            System.out.print("Enter the age for person " + i + ": ");
            int age = scanner.nextInt();

            // Use ternary operator to categorize the age
            String category = (age < 13) ? "Child" :
                              (age >= 13 && age < 20) ? "Teenager" :
                              (age >= 20 && age < 65) ? "Adult" :
                              "Senior";

            // Output the category
            System.out.println("Person " + i + " is a " + category + ".");
        }

        // Close the scanner
        scanner.close();
    }
}
