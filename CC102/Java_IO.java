import java.util.Scanner;

public class Java_IO {

    public static void main(String []args) {
        try (Scanner input = new Scanner(System.in)) {
            System.out.print("Enter your name: ");
            String name = input.next();

            System.out.print("Enter your age: ");
            int age = input.nextInt();

            System.out.println("Hello " + name + "!");
            System.out.println("Your age is: " + age);
        }
    }
}