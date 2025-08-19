import java.util.Scanner;

public class Ex24GradeEvaluation {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Input: Ask the user for the student's grade
        System.out.print("Enter the student's grade (0-100): ");
        int grade = scanner.nextInt();

        // Evaluate the grade using if-else if with nested conditions
        if (grade >= 90) {
            System.out.println("The student has an A.");
            if (grade >= 95) {
                System.out.println("The student qualifies for High Honors.");
            } else {
                System.out.println("The student qualifies for Honors.");
            }
        } else if (grade >= 80) {
            System.out.println("The student has a B.");
            if (grade >= 85) {
                System.out.println("The student qualifies for Honors.");
            } else {
                System.out.println("The student is doing well.");
            }
        } else if (grade >= 70) {
            System.out.println("The student has a C.");
            if (grade >= 75) {
                System.out.println("The student needs to improve.");
            } else {
                System.out.println("The student is at risk of failing.");
            }
        } else if (grade >= 60) {
            System.out.println("The student has a D.");
            if (grade >= 65) {
                System.out.println("The student is close to failing.");
            } else {
                System.out.println("The student needs significant improvement.");
            }
        } else {
            System.out.println("The student has an F.");
            System.out.println("The student has failed and needs to retake the course.");
        }

        // Close the scanner
        scanner.close();
    }
}