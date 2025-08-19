import java.util.Scanner;

public class Ex34StudentPassFail {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Define the passing grade
        final int PASSING_GRADE = 60;

        // Input: Ask the user for the number of students
        System.out.print("Enter the number of students: ");
        int numberOfStudents = scanner.nextInt();

        // Loop through each student to get their score and determine pass/fail
        for (int i = 1; i <= numberOfStudents; i++) {
            System.out.print("Enter the score for student " + i + ": ");
            int score = scanner.nextInt();

            // Use ternary operator to determine if the student passed or failed
            String result = (score >= PASSING_GRADE) ? "Passed" : "Failed";

            // Output the result
            System.out.println("Student " + i + " has " + result + ".");
        }

        // Close the scanner
        scanner.close();
    }
}
