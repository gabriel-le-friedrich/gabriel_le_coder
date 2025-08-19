import java.util.Scanner;

public class Calculator{
  public static void main(String[] args) {
    // create an object of Scanner class
    Scanner input = new Scanner(System.in);

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
        break;

      // performs subtraction between numbers
      case '-':
        result = number1 - number2;
        System.out.println(number1 + " - " + number2 + " = " + result);
        break;

      // performs multiplication between numbers
      case '*':
        result = number1 * number2;
        System.out.println(number1 + " * " + number2 + " = " + result);
        break;

      // performs division between numbers
      case '/':
        result = number1 / number2;
        System.out.println(number1 + " / " + number2 + " = " + result);
        break;

      default:
        System.out.println("Invalid operator!");
        break;
    }

    input.close();
  }
}