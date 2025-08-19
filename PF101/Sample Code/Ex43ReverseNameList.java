import java.util.Scanner;

public class Ex43ReverseNameList {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Define the number of names
        final int NUMBER_OF_NAMES = 5;
        String[] names = new String[NUMBER_OF_NAMES];

        // Prompt the user to enter names
        System.out.println("Please enter " + NUMBER_OF_NAMES + " names:");

        // Use a for loop to read user input into the array
        for (int i = 0; i < NUMBER_OF_NAMES; i++) {
            System.out.print("Enter name " + (i + 1) + ": ");
            names[i] = scanner.nextLine();
        }

        // Display the names in reverse order
        System.out.println("Names in reverse order:");
        for (int i = NUMBER_OF_NAMES - 1; i >= 0; i--) {
            System.out.println(names[i]);
        }

        // Close the scanner
        scanner.close();
    }
}
