import java.util.Scanner;

public class LBU {
    public static void main(String []args) {
        try (Scanner input = new Scanner(System.in)) {

            System.out.print("Enter your First Name: ");
            String Fn = input.next();

            System.out.print("Enter your Last Name: ");
            String Ln = input.next();

            System.out.print("Are you Mr./Ms.? ");
            String title = input.next();

            System.out.println("Welcome, " + title + " " + Fn + " " + Ln + "!");
            System.out.println("I am LBU, acronym for London Bridge University.");
            System.out.println("At your service," + " " + title + " " + Ln + "!");

        }
    }
}




