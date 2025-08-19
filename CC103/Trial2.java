import java.util.Scanner;

public class Trial2 {
    public static void main (String [] args) {
        try (Scanner input = new Scanner (System.in)) {
            System.out.print("CC102 Grade: ");
            double g = input.nextDouble();

            int i = 1;

            if (g <= 1.5) {
                while (i <= 5){
                    System.out.print("*");
                    i++;
                }
            }
            else if (g <= 2) {
                while (i <= 4){
                    System.out.print("*");
                    i++;
                }
            }
            else if (g <= 3) {
                while (i <= 3){
                    System.out.print("*");
                    i++;
                }
            }
            else if (g <= 4) {
                while (i <= 2){
                    System.out.print("*");
                    i++;
                }
            }
            else {
                while (i <= 1){
                    System.out.print("Failed.");
                    i++;
                }
            }
        }
    }
}
