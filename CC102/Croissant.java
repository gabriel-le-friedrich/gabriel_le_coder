import java.util.Scanner;

public class Croissant {
    public static void main(String []args) {
        try (Scanner input = new Scanner(System.in)) {
            
            System.out.print("Username: ");
            String Un = input.next();

            System.out.print("Password: ");
            String P = input.next();

            if (P.contains("Croissant")) {
                System.out.println("Hello, " + Un + "!");
            } else {
                System.out.println("SIKE! TRAITOROUS BAGUETTE! TRAITOROUS BAGUETTE!");
            }

        }
    }
}
