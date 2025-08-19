import java.util.Scanner;

public class TempCheck {
    public static void main(String [] args) {
        try(Scanner input = new Scanner(System.in)) {

            System.out.print("Enter your body temperature (in C): ");
            double temp = input.nextDouble();

            if (temp <= 36.1) {
                System.out.println("Damn, you're cold!");

                if (temp <= 25) {
                    System.out.println("You dead dawg?!");
                } else if (temp >= 26) {
                    System.out.println("Ikaw ba nilalamig o siya?");
                }

            } else if (temp >= 38) {
                System.out.println("You have a fever.");

                if (temp >= 50) {
                    System.out.println("Damn, you're hot!");
                }

            } else {
                System.out.println("Your temperature is normal.");
            }
        }
    }
}
