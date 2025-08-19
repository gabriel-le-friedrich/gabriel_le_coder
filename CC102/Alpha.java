import java.util.Scanner;

public class Alpha {
    public static void main(String [] args) {
        try (Scanner input = new Scanner(System.in)) {

            // greetings
            System.out.println("Welcome to Alpha.java!");
            System.out.println("This is an experiment.");
            System.out.println("Hello, I am Alpha!");
            System.out.print("And you are? ");
            String name = input.next();
            System.out.println();

            System.out.println("Hello there, " + name + "!");
            System.out.println();

            System.out.println("Enter the password to unlock my commands.");
            System.out.print("Password: "); 
            String password = input.next(); // password: pass
            System.out.println();

            if (password.contains("pass")) {
            System.out.println("Access Granted!");
            System.out.println();

                // this will loop until you command 'Exit'
                while (password.contains("pass")) {

                System.out.println("Here are my commands:");
                System.out.println("(1) Calculator");
                System.out.println("(2) Fibonacci Sequence");
                System.out.println("(3) Pythagorean Theorem");
                System.out.println("(4) Quadratic Formula");
                System.out.println("(5) Exit");
                System.out.println();

                System.out.print("Enter your command: ");
                int cmd = input.nextInt();
                System.out.println();

                    // Calculator Command
                    if (cmd == 1) {

                        char operator;
                        Double number1, number2, result;

                        // ask users to enter first number
                        System.out.print("Enter first number: ");
                        number1 = input.nextDouble();

                        // ask users to enter operator
                        System.out.print("Choose an operator: +, -, *, or /: ");
                        operator = input.next().charAt(0);

                        // ask users to enter second number
                        System.out.print("Enter second number: ");
                        number2 = input.nextDouble();

                        switch (operator) {

                        // performs addition between numbers
                        case '+':
                            result = number1 + number2;
                            System.out.println(number1 + " + " + number2 + " = " + result);
                            System.out.println();
                            break;

                        // performs subtraction between numbers
                        case '-':
                            result = number1 - number2;
                            System.out.println(number1 + " - " + number2 + " = " + result);
                            System.out.println();
                            break;

                        // performs multiplication between numbers
                        case '*':
                            result = number1 * number2;
                            System.out.println(number1 + " * " + number2 + " = " + result);
                            System.out.println();
                            break;

                        // performs division between numbers
                        case '/':
                            result = number1 / number2;
                            System.out.println(number1 + " / " + number2 + " = " + result);
                            System.out.println();
                            break;

                        // wrong operator
                        default:
                            System.out.println("Invalid operator!");
                            System.out.println();
                            break;
                        }

                    // Fibonacci Sequence Command
                    } else if (cmd == 2) {
                        while (cmd == 2) {
                            System.out.print("Enter the nth term: ");
                            int n = input.nextInt();

                            if (n >= 0) {
                                int result = (int) (((Math.pow(1.618034, n)) + (Math.pow(0.618034, n)))/2.236068);

                                System.out.println("The term is" + " " + result + "!");
                                System.out.println();

                            } else if (n == -1) {
                                System.out.println("Command Change.");
                                System.out.println();
                                break;

                            } else {
                                System.out.println("Please try again!");
                                System.out.println();
                            }
                        }

                    // Pythagorean Theorem Command
                    } else if (cmd == 3) {

                        Double a, b, c;

                        // value of a-side
                        System.out.print("Value of a: ");
                        a = input.nextDouble();
                        // value of b-side
                        System.out.print("Value of b: ");
                        b = input.nextDouble();
                        // value of c-side (hypotenuse)
                        c = Math.sqrt((Math.pow(a, 2) + Math.pow(b, 2)));

                        System.out.println("The Value of the Hypotenuse: " + c);
                        System.out.println();

                    // Quadratic Formula Command
                    } else if (cmd == 4) {
                        
                        Double a, b, c, d, x1, x2;

                        // Quadratic Formula: ax^2 + bx + c
                        // value of a
                        System.out.print("Value of a: ");
                        a = input.nextDouble();
                        // value of b
                        System.out.print("Value of b: ");
                        b = input.nextDouble();
                        // value of constant
                        System.out.print("Value of c: ");
                        c = input.nextDouble();

                        x1 = (-b + Math.sqrt((Math.pow(b, 2) + 4*a*c))) / 2*a;
                        x2 = (-b - Math.sqrt((Math.pow(b, 2) + 4*a*c))) / 2*a;
                        d = (Math.pow(b, 2) + 4*a*c);

                        System.out.println("The Value of your:");
                        System.out.println("x1 = " + x1);
                        System.out.println("x2 = " + x2);
                        
                        if (d > 0) {
                            System.out.println("There are two real solutions!");
                            System.out.println();
                        } else if (d == 0) {
                            System.out.println("There are one real solution!");
                            System.out.println();
                        } else if (d < 0) {
                            System.out.println("There are no real solution!");
                            System.out.println();
                        }

                    // Exit Command
                    } else if (cmd == 5) {
                        System.out.println("Goodbye, " + name + "!");
                        System.out.println();
                        break;
                    }
                }
                
            } else {
                System.out.println("Access Denied!");
                System.out.println();
            }
        }
    }
}



