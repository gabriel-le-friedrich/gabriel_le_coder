import java.util.Scanner;

public class OddsEven {

    static void countEvenOdd(int count) {
        try(Scanner input = new Scanner(System.in)) {
            int odd = 0;
            int even = 0;
            
            for(int i = 0; i < count; i++) {
                System.out.print("Number " + (i+1) + ": ");
                int number = input.nextInt();

                if(number % 2 == 0) {
                    even += 1;
                } else {
                    odd += 1;
                }
            }

            System.out.println("Odd: " + odd);
            System.out.println("Even: " + even);
        }
    }
    public static void main(String[] args) {
        try(Scanner input = new Scanner(System.in)) {

            System.out.print("How many numbers? ");
            int count = input.nextInt();

            countEvenOdd(count);
        }
    }
}