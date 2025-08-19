import java.util.Scanner;

public class Ex37DayOfWeekChecker {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Input: Ask the user for the number of days to check
        System.out.print("Enter the number of days to check (1-7): ");
        int numberOfDays = scanner.nextInt();

        // Loop through each day number to classify it
        for (int i = 1; i <= numberOfDays; i++) {
            System.out.print("Enter the day number " + i + " (1-7): ");
            int dayNumber = scanner.nextInt();

            // Use switch statement to determine the type of day
            String dayType;
            switch (dayNumber) {
                case 1:
                case 2:
                case 3:
                case 4:
                case 5:
                    dayType = "Weekday";
                    break;
                case 6:
                case 7:
                    dayType = "Weekend";
                    break;
                default:
                    dayType = "Invalid day number";
                    break;
            }

            // Output the result
            System.out.println("Day number " + dayNumber + " is a " + dayType + ".");
        }

        // Close the scanner
        scanner.close();
    }
}
