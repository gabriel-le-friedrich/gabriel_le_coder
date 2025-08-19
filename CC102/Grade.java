import java.util.Scanner;

public class Grade {
    public static void main(String[] args) {
        try(Scanner input = new Scanner(System.in)) {

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
        }
    }
}