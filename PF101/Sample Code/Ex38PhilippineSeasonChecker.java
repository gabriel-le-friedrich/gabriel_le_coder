import java.util.Scanner;

public class Ex38PhilippineSeasonChecker {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Input: Ask the user for the number of months to check
        System.out.print("Enter the number of months to check (1-12): ");
        int numberOfMonths = scanner.nextInt();

        // Loop through each month number to determine the Philippine season
        for (int i = 1; i <= numberOfMonths; i++) {
            System.out.print("Enter month number " + i + " (1-12): ");
            int monthNumber = scanner.nextInt();

            // Use switch statement to determine the Philippine season
            String season;
            switch (monthNumber) {
                case 12:
                case 1:
                case 2:
                    season = "Tag-lamig (Cool or Christmas Season)";
                    break;
                case 3:
                case 4:
                case 5:
                    season = "Tag-init (Dry Season)";
                    break;
                case 6:
                case 7:
                case 8:
                case 9:
                case 10:
                case 11:
                    season = "Tag-ulan (Rainy Season)";
                    break;
                default:
                    season = "Invalid month number";
                    break;
            }

            // Output the result
            System.out.println("Month number " + monthNumber + " is in " + season + ".");
        }

        // Close the scanner
        scanner.close();
    }
}
