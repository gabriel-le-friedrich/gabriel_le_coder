import java.util.Scanner;

public class midterm_Demo {
    public static void main(String[] args) {
        try (Scanner input = new Scanner(System.in)) {

            System.out.print("Name: ");
            String name = input.next();

            System.out.print("Allowance: ");
            int ma = input.nextInt();

            System.out.print("For how many days: ");
            int d = input.nextInt();

            System.out.print("Project: ");
            int p = input.nextInt();

            System.out.print("Savings: ");
            int s = input.nextInt();

            System.out.print("Extra Allowance: ");
            int ea = input.nextInt();

            double db = (ma - (p + s + ea))/d;

            if (db <= 200) {
                if (db <= 100) {
                    System.out.println("Hi, " + name + "! Your daily budget is " + db + ", you need to find more income!");
                    System.out.println();
                } else {
                    System.out.println("Hi, " + name + "! Your daily budget is " + db + ", you need to save more!");
                    System.out.println();
                }
            } else if (db >= 300) {
                System.out.println("Hi, " + name + "! Your daily budget is " + db + ", you have more savings!");
                System.out.println();
            } else {
                System.out.println("Hi, " + name + "! Your daily budget is " + db + ", you have enough budget!");
                System.out.println();
            }
        }
    }
}
