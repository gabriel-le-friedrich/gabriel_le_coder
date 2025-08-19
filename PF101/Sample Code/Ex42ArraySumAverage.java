import java.util.Scanner;

public class Ex42ArraySumAverage {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Define the size of the array
        final int SIZE = 5;
        int[] numbers = new int[SIZE];

        // Prompt the user to enter integers
        System.out.println("Please enter " + SIZE + " integers:");

        // Use a for loop to read user input into the array
        for (int i = 0; i < SIZE; i++) {
            System.out.print("Enter integer " + (i + 1) + ": ");
            numbers[i] = scanner.nextInt();
        }

        // Initialize variables to calculate the sum and average
        int sum = 0;
        double average;

        // Use a for loop to calculate the sum of the numbers
        for (int i = 0; i < SIZE; i++) {
            sum += numbers[i];
        }

        // Calculate the average
        average = (double) sum / SIZE;

        // Display the results
        System.out.println("The numbers you entered are:");
        for (int i = 0; i < SIZE; i++) {
            System.out.println(numbers[i]);
        }
        System.out.println("Sum: " + sum);
        System.out.println("Average: " + average);

        // Close the scanner
        scanner.close();
    }
}
