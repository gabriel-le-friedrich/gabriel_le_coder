import java.util.Scanner;

public class Act1v2 {
    public static void main(String[] args) {
        try (Scanner input = new Scanner(System.in)) {
            Double subject1, subject2, subject3, average;

            System.out.print("Subject 1: ");
            subject1 = input.nextDouble();
            System.out.print("Subject 2: ");
            subject2 = input.nextDouble();
            System.out.print("Subject 3: ");
            subject3 = input.nextDouble();

            average = (subject1 + subject2 + subject3)/3;

            if (average >= 75) {
                System.out.println("Passed!");
            } else {
                System.out.println("Failed!");
            }
        }
    }
}
