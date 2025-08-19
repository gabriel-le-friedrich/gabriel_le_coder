//Code by Frederick Gabrielle Cunanan
import java.util.Scanner;

public class Trial1 {
    public static void main (String [] args) {
        try (Scanner input = new Scanner (System.in)) {

            //Simple calculator using switch statement
            System.out.print("First Number: ");
            double n1 = input.nextInt();
            System.out.print("Operation (+,-,*,/): ");
            char op = input.next().charAt(0);
            System.out.print("Second Number: ");
            double n2 = input.nextDouble();
            System.out.println("");

            //Switch Statement
            switch (op) {
                case '+':
                    double t = n1 + n2;
                    System.out.println(t);
                    break;
                case '-':
                    double d = n1 - n2;
                    System.out.println(d);
                    break;
                case '*':
                    double p = n1 * n2;
                    System.out.println(p);
                    break;
                case '/':
                    double q = n1 / n2;
                    System.out.println(q);
                    break;
            
                default:
                    System.out.print("Wrong Operator!");
                    break;
            }
        }
    }
}
