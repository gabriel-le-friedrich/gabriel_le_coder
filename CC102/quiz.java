import java.util.Scanner;

public class quiz {
    public static void main(String [] args) {
        try (Scanner input = new Scanner(System.in)) {

            System.out.println("Welcome to quiz.java!");
            System.out.println("This will determine if you will pass or drop.");
            System.out.println();

            System.out.print("Name: ");
            String name = input.next();

            if (name.contains(name)) {
                System.out.print("Grade in CC101: ");
                double CC101 = input.nextDouble();
                
                if (CC101 >= 90) {
                    System.out.print("Grade in CC102: ");
                    double CC102 = input.nextDouble();

                    if (CC102 >= 95) {
                        System.out.println("Congratulations, " + name + "!");
                        System.out.println("You passed!");
                    } else {
                        System.out.println("Sorry, better luck next time!");
                    }

                } else {
                    System.out.println("Dropped!");
                }
            }
        }
    }
}
