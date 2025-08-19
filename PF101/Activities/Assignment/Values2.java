import java.util.Scanner;

public class Values2 {
    private static final Scanner input = new Scanner(System.in);

    static double value1() {
        double num1 = 0;
        boolean validInput = false;

        while (!validInput) {
            System.out.print("Enter the first number: ");
            if (input.hasNextDouble()) {
                num1 = input.nextDouble();
                validInput = true;
            } else {
                System.out.println("Invalid input! Please enter a valid number.");
                input.next();
            }
        }
        return num1;
    }

    static double value2() {
        double num2 = 0;
        boolean validInput = false;

        while (!validInput) {
            System.out.print("Enter the second number: ");
            if (input.hasNextDouble()) {
                num2 = input.nextDouble();
                validInput = true;
            } else {
                System.out.println("Invalid input! Please enter a valid number.");
                input.next();
            }
        }
        return num2;
    }
}
