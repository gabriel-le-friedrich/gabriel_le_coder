import java.util.Scanner;

public class Program {
    public static void main (String [] args) {
        try(Scanner input = new Scanner(System.in)) {
            System.out.println("Hello!");
            System.out.println("Welcome to Program.java!");
            System.out.print("Enter your name: ");
            String name = input.next();
            System.out.println();

            System.out.println("Hello, " + name + "!");
            System.out.println("To unlock my commands, please enter the password.");
            System.out.print("Password: ");
            int pass = input.nextInt();

            if (pass == 1234) {
                while (pass == 1234) {
                    System.out.println("Access Granted!");
                    System.out.println();
                    System.out.println("Here are my commands: ");
                    System.out.println("(1) Guessing Game");
                    System.out.println("(2) Grade Calculator");
                    System.out.println("(3) Star Dispenser");
                    System.out.println("(0) Exit");
                    System.out.println();
                    System.out.print("Command: ");
                    int cmd = input.nextInt();

                    if (cmd == 1) {
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
                    } else if (cmd == 2) {
                        System.out.print("Enter your Midterm Grade: ");
                        double mg = input.nextDouble();

                        System.out.print("Enter your Final Grade: ");
                        double fg = input.nextDouble();

                        double avg = (mg*0.3) + (fg*0.7);

                        if (avg >= 90 && avg <= 100) {
                            int i = 10;
                            for (i=1;i<=10;i++) {
                                System.out.println(i + ": *");
                            }

                        } else if (avg >= 80 && avg <= 89) {
                            int i = 5;
                            for (i=1;i<=5;i++) {
                                System.out.println(i + ": *");
                            }

                        } else if (avg >= 75 && avg <= 79) {
                            int i = 3;
                            for (i=1;i<=3;i++) {
                                System.out.println(i + ": *");
                            }

                        } else {
                            System.out.println("Sorry your grade is failed");
                        }
                    } else if (cmd == 3) {
                        for (int a=1;a<=3;a++) {
                            System.out.print("How many stars do you want (1-10)? ");
                            int s = input.nextInt();
                
                            if (s <= 10) {
                                for (int i=1;i<=s;i++) {
                                    System.out.print("*");
                                } break;
                            } else {
                                System.out.println("Over 10 Stars is invalid! Please enter a new number again.");
                                System.out.println();
                            }
                        }
                    } else if (cmd == 0) {
                        System.out.println("Goodbye :)");
                        System.out.println();
                        break;
                    } else {
                        System.out.println("Invalid Command!");
                        System.out.println();
                    }
                }
            } else {
                System.out.println("Password Incorrect!");
                System.out.println("Systems Shutting Down...");
                System.out.println();
            }

        }
    }
}
