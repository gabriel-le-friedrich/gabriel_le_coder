import java.util.Scanner;

public class Java {
    public static void main(String []args) {
        try (Scanner input = new Scanner(System.in)) {
            System.out.print("Enter your Average Grade: ");
            int avg = input.nextInt();

            if (avg >= 90) {
                
                System.out.print("Enter your Grade in Mathematics: ");
                int Math = input.nextInt();
            
                if (Math >= 94) {

                    System.out.print("Enter your Grade in Science: ");
                    int Sci = input.nextInt();
                    
                    if (Sci >= 94) {
                        System.out.println("Access Granted!");

                    } else {
                        System.out.print("Access Denied!");
                    }

                } else {
                    System.out.print("Access Denied!");
                }

            } else {
                System.out.print("Access Denied!");
            }
        }
    }
}