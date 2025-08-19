import java.util.Scanner;

public class Ex29FareCalculator {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Input: Ask the user for the type of commuter
        System.out.println("Select your commuter type: ");
        System.out.println("1. Student");
        System.out.println("2. Regular");
        System.out.println("3. Senior Citizen");
        int commuterType = scanner.nextInt();

        // Input: Ask the user for the distance traveled in kilometers
        System.out.print("Enter the distance traveled (in kilometers): ");
        double distance = scanner.nextDouble();

        double fare = 0;

        // Determine the fare based on the commuter type and distance
        if (commuterType == 1) {
            fare = distance * 8.00;  // Student fare rate: PHP 8 per kilometer
            System.out.println("You selected Student. Base fare: PHP 8.00 per kilometer.");
        } else if (commuterType == 2) {
            fare = distance * 12.00;  // Regular fare rate: PHP 12 per kilometer
            System.out.println("You selected Regular. Base fare: PHP 12.00 per kilometer.");
        } else if (commuterType == 3) {
            fare = distance * 10.00;  // Senior Citizen fare rate: PHP 10 per kilometer
            System.out.println("You selected Senior Citizen. Base fare: PHP 10.00 per kilometer.");
        } else {
            System.out.println("Invalid commuter type selected.");
            scanner.close();
            return;
        }

        // Nested condition: Apply a discount if the fare exceeds a certain amount
        if (fare > 100.00) {
            fare = fare * 0.90;  // Apply a 10% discount
            System.out.println("A 10% discount has been applied. Your discounted fare is: PHP " + fare);
        } else {
            System.out.println("Your total fare is: PHP " + fare);
        }

        // Close the scanner
        scanner.close();
    }
}
