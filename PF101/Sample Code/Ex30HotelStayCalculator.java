import java.util.Scanner;

public class Ex30HotelStayCalculator {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Input: Ask the user for the number of nights
        System.out.print("Enter the number of nights you want to stay: ");
        int nights = scanner.nextInt();

        // Input: Ask the user for the room type
        System.out.println("Select room type: ");
        System.out.println("1. Single Room");
        System.out.println("2. Double Room");
        System.out.println("3. Suite");
        int roomType = scanner.nextInt();

        double roomRate = 0;

        // Determine the room rate based on the room type
        if (roomType == 1) {
            roomRate = 3000.00;  // Single Room rate: PHP 3000 per night
            System.out.println("You selected Single Room. Rate: PHP 3000 per night.");
        } else if (roomType == 2) {
            roomRate = 5000.00;  // Double Room rate: PHP 5000 per night
            System.out.println("You selected Double Room. Rate: PHP 5000 per night.");
        } else if (roomType == 3) {
            roomRate = 8000.00;  // Suite rate: PHP 8000 per night
            System.out.println("You selected Suite. Rate: PHP 8000 per night.");
        } else {
            System.out.println("Invalid room type selected.");
            scanner.close();
            return;
        }

        // Calculate the initial total price
        double totalPrice = roomRate * nights;

        // Nested condition: Apply a discount based on the number of nights
        if (nights >= 5) {
            totalPrice = totalPrice * 0.85;  // Apply a 15% discount
            System.out.println("A 15% discount has been applied.");
        } else if (nights >= 3) {
            totalPrice = totalPrice * 0.90;  // Apply a 10% discount
            System.out.println("A 10% discount has been applied.");
        }

        // Display the final price
        System.out.println("Your total price for " + nights + " night(s) is: PHP " + totalPrice);

        // Close the scanner
        scanner.close();
    }
}
