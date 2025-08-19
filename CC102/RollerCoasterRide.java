import java.util.Scanner;

public class RollerCoasterRide {
    public static void main(String [] args) {
        try(Scanner input = new Scanner(System.in)) {

        System.out.println("Welcome to RollerCoasterRide.java!");
        System.out.println("Let me have your name and height!");
        System.out.println();

        System.out.print("Name: ");
        String name = input.next();

            if (name.contains(name)) {

                System.out.print("Height (cm): ");
                double h = input.nextDouble();
                System.out.println();

                if (h < 121) {
                    System.out.println("Sorry, " + name + " you are too short!");
                    System.out.println("Patangkad ka muna!");
                } else if (h > 213) {
                    System.out.println("Sorry, " + name + " you are too high!");
                    System.out.println("Patabas mo muna paa mo!");
                } else {
                    System.out.println(name + ", You\'re valid to ride!");
                    System.out.println("Enjoy the ride!");
                }

            } else {
                System.out.print("Who are you? ");
            }
        }
    }
}