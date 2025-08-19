import java.util.Scanner;

public class Jarvis {

    public static void main(String []args) {
        try (Scanner input = new Scanner(System.in)) {

            System.out.println("Hello! I am JARVIS!");
            System.out.println("Acronym for 'Just A Really Very Intelligent System'");

            System.out.print("And you are? ");
            String name = input.next();

            System.out.println("Hello, " + name + "!");

            System.out.print("Please write your command: ");
            String cmd = input.next();

            if (cmd.contains("Calculator")) {
                
                while (cmd.contains("Calculator")) {
                
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

                        default:
                            System.out.println("Syntax Error!");
                            System.out.println();
                            break;
                    }
                }

                input.close();

            } else {
                System.out.println("Invalid Command!");
                System.out.println();
            }
        }
    }
}

