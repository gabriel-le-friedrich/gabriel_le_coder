import java.util.Scanner;

public class Game {
    public static void main (String [] args) {
        try(Scanner input = new Scanner(System.in)) {
            System.out.println("Guess the number from 1-10!");
            System.out.println();
            System.out.println("Mechanics:");
            System.out.println("1. You only have 3 attempts.");
            System.out.println("2. Enter a number from 1-10.");
            System.out.println("3. Enter the number 0 to exit.");
            System.out.println("4. Enjoy.");
            System.out.println();

            for (int i=1;i<=3;i++) {
                System.out.print("Your Guess? ");
                int g = input.nextInt();

                if (g == 5) {
                    System.out.println("Congratulations! You've Guessed the Right Number!");
                    break;
                } else if (g == 0) {
                    System.out.println("Goodbye!");
                    break;
                } else {
                    System.out.println("Wrong!");
                    System.out.println();
                }
            }
        }
    }
}