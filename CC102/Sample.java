import java.util.Scanner;

public class Sample {
    public static void main(String[] args) {
        try(Scanner input = new Scanner(System.in)) {
            
            for (int a=1;a<=3;a++) {
            System.out.print("How many stars do you want (1-10)? ");
            int s = input.nextInt();

                if (s <= 10) {
                    for (int i=1;i<=s;i++) {
                        System.out.print("*");
                    } break;
                } else {
                    System.out.println("Over 10 Stars is invalid! Please enter a new number again.");
                    System.out.println();
                }
            }
        }
    }
}