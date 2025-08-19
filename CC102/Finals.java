import java.util.Scanner;

public class Finals {
    public static void main(String[] args) {
        try(Scanner input = new Scanner(System.in)) {
            for (int i=1;i<=5;i++) {
            System.out.print("Enter your Password: ");
            int pass = input.nextInt();

                if (pass == 12345) {
                    System.out.println("Correct Password");
                    while (pass == 12345) {
                        System.out.println();
                        System.out.print("Please Select Transactions: (1)-Check Balance (2)-Withdraw (3)-Deposit: ");
                        int trans = input.nextInt();

                        int bal = 1000;

                        if (trans == 1) {
                            System.out.println("Your balance is: " + bal);
                            System.out.println();

                            System.out.print("Do you want to do another transaction (y/n): ");
                            String ans = input.next();

                            if (ans.contains("y")) {
                                continue;
                            } else if (ans.contains("n")) {
                                System.exit(0);
                            } else {
                                System.out.println("Invalid Key");
                                System.out.println("Locking Account...");
                                System.out.println();
                                break;
                            }

                        } else if (trans == 2) {
                            System.out.print("Please enter the amount you want to Withdraw: ");
                            int with = input.nextInt();

                            int nb = bal - with;
                            System.out.println("Your balance is: " + nb);
                            System.out.println();

                            System.out.print("Do you want to do another transaction (y/n): ");
                            String ans = input.next();

                            if (ans.contains("y")) {
                                continue;
                            } else if (ans.contains("n")) {
                                System.exit(0);
                            } else {
                                System.out.println("Invalid Key");
                                System.out.println("Locking Account...");
                                System.out.println();
                                break;
                            }

                        } else if (trans == 3) {
                            System.out.print("Please enter the amount you want to Deposit: ");
                            int dep = input.nextInt();

                            int nb = bal + dep;
                            System.out.println("Your balance is: " + nb);
                            System.out.println();

                            System.out.print("Do you want to do another transaction (y/n): ");
                            String ans = input.next();

                            if (ans.contains("y")) {
                                continue;
                            } else if (ans.contains("n")) {
                                System.exit(0);
                            } else {
                                System.out.println("Invalid Key");
                                System.out.println("Locking Account...");
                                System.out.println();
                                break;
                            }

                        } else {
                            System.out.println("Invalid Transaction");
                            System.out.println();

                            System.out.print("Do you want to continue (y/n): ");
                            String ans = input.next();

                            if (ans.contains("y")) {
                                continue;
                            } else if (ans.contains("n")) {
                                break;
                            } else {
                                System.out.println("Invalid Key");
                                System.out.println("Exiting Program...");
                                break;
                            }
                        }
                    }
                } else if (i == 4) {
                    System.out.println("Warning!!!...... Last Attempt...");
                } else if (i == 5) {
                    System.out.println("I'm very sorry you have reached the maximum attempts, your account is temporarily freezed");
                } else {
                    System.out.println("Sorry, wrong password, " + i + " attempt");
                }
            }
        }
    }
}