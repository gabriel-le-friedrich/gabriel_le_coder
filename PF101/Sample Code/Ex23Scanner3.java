import java.util.Scanner;

public class Ex23Scanner3 {
    public static void main(String[] args) {
        // Create a Scanner object to read input
        Scanner scanner = new Scanner(System.in);

        // Prompt the user to enter their name
        System.out.print("Enter your name: ");
        String name = scanner.nextLine();

        // Prompt the user to enter their age
        System.out.print("Enter your age: ");
        int age = scanner.nextInt();

        // Prompt the user to enter four grades
        System.out.print("Enter your first grade: ");
        double grade1 = scanner.nextDouble();

        System.out.print("Enter your second grade: ");
        double grade2 = scanner.nextDouble();

        System.out.print("Enter your third grade: ");
        double grade3 = scanner.nextDouble();

        System.out.print("Enter your fourth grade: ");
        double grade4 = scanner.nextDouble();

        // Calculate the average grade
        double averageGrade = (grade1 + grade2 + grade3 + grade4) / 4;

        // Determine if the user is a minor or an adult
        String status = (age >= 18) ? "Adult" : "Minor";

        // Determine the grade remark
        String remark;
        if (averageGrade >= 90) {
            remark = "Excellent";
        } else if (averageGrade >= 80) {
            remark = "Very Good";
        } else if (averageGrade >= 70) {
            remark = "Good";
        } else if (averageGrade >= 60) {
            remark = "Satisfactory";
        } else {
            remark = "Needs Improvement";
        }

        // Display the results
        System.out.println("\n--- Student Information ---");
        System.out.println("Name: " + name);
        System.out.println("Average Grade: " + averageGrade);
        System.out.println("Remark: " + remark);
        System.out.println("Status: " + status);

        // Close the scanner
        scanner.close();
    }
}
