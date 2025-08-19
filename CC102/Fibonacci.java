import java.util.Scanner;

public class Fibonacci {
    public static void main(String []args) {
        try (Scanner input = new Scanner(System.in)) {

            System.out.println("Welcome to the Fibonacci Calculator!");

            System.out.print("Please write your command: ");
            String cmd = input.next();

            if (cmd.contains("F")) {

                while (cmd.contains("F")) {

                    System.out.print("Enter the nth term: ");
                    int n = input.nextInt();

                        if (n >= 0) {
                                int result = (int) (((Math.pow(1.618034, n)) + (Math.pow(0.618034, n)))/2.236068);

                                System.out.println(result);
                                System.out.println();

                        } else {
                            System.out.println("Please try again!");
                            System.out.println();
                        }
                }

            } else {
                System.out.print("Invalid Command!");
            }
        }
    }
}
