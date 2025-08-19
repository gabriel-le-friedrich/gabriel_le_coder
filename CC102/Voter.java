//Code by Frederick Gabrielle Cunanan
import java.util.Scanner;

public class Voter {
    public static void main(String [] args) {
        try(Scanner input = new Scanner(System.in)) {

            //Program that ask the user if they are voters
            System.out.println("Hello, Voter!");
            System.out.println("Are you eligible to vote or not? Let's find out!");
            System.out.println();

            //Ask the name of the user
            System.out.print("Name: ");
            String name = input.next();

            if (name.contains(name)) {

                //Ask the age of the user
                System.out.print("Age: ");
                int age = input.nextInt();

                System.out.println("Hello, " + name + "!");

                //Conditional Statement
                if (age >= 15) {
                    
                    if (age <= 17) {
                        System.out.println("You are eligible to vote, but for SK only!");
                        System.out.println();
                    } else if (age >= 18) {
                        System.out.println("You are eligible to vote!");
                        System.out.println();
                    }

                }  else {
                    System.out.println("You are not eligible to vote!");
                    System.out.println();
                }
            } else {
                System.out.println("Invalid Input!");
            }
        }
    }
}
