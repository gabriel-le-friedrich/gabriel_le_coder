import java.util.Scanner;

public class HandsOn5 {

    public static void main(String []args) {
        try (Scanner input = new Scanner(System.in)) {
            
            System.out.print("Enter your name: ");
            String name = input.next();

            System.out.print("Enter your grade in HCI: ");
            int Grade1 = input.nextInt();

            System.out.print("Enter your grade in CC101: ");
            int Grade2 = input.nextInt();

            System.out.print("Enter your grade in CC102: ");
            int Grade3 = input.nextInt();

            double result = (Grade1 + Grade2 + Grade3)/3;

            System.out.println("Hello " + name + "!");
            System.out.println("Congratulations! Your average is: " + result + "!");
        }
    }
}