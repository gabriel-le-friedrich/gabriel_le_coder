import java.util.Scanner;

public class Ex33TripCostCalculator {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Initialize constants for base rates and accommodation costs
        final double TRANSPORTATION_BASE_RATE = 1000.00; // Base rate for transportation
        final double HOTEL_COST_PER_NIGHT = 1500.00;     // Cost per night for a hotel
        final double HOSTEL_COST_PER_NIGHT = 800.00;    // Cost per night for a hostel
        final double AIRBNB_COST_PER_NIGHT = 1200.00;   // Cost per night for an Airbnb
        final int DISCOUNT_THRESHOLD_DAYS = 7;          // Number of days to qualify for a discount
        final double DISCOUNT_RATE = 0.10;              // 10% discount for long stays

        // Input: Ask the user for the number of days
        System.out.print("Enter the number of days for your trip: ");
        int numberOfDays = scanner.nextInt();

        // Input: Ask the user for the mode of transportation
        System.out.println("Select mode of transportation: ");
        System.out.println("1. Car (Base rate: PHP 1000)");
        System.out.println("2. Bus (Base rate: PHP 1200)");
        System.out.println("3. Train (Base rate: PHP 1500)");
        int transportationMode = scanner.nextInt();

        double transportationCost = TRANSPORTATION_BASE_RATE;

        // Determine the cost for transportation based on the mode selected
        if (transportationMode == 1) {
            transportationCost = TRANSPORTATION_BASE_RATE;
            System.out.println("You selected Car. Base rate: PHP 1000.");
        } else if (transportationMode == 2) {
            transportationCost = 1200.00;
            System.out.println("You selected Bus. Base rate: PHP 1200.");
        } else if (transportationMode == 3) {
            transportationCost = 1500.00;
            System.out.println("You selected Train. Base rate: PHP 1500.");
        } else {
            System.out.println("Invalid transportation mode selected.");
            scanner.close();
            return;
        }

        // Input: Ask the user for the type of accommodation
        System.out.println("Select type of accommodation: ");
        System.out.println("1. Hotel (PHP 1500 per night)");
        System.out.println("2. Hostel (PHP 800 per night)");
        System.out.println("3. Airbnb (PHP 1200 per night)");
        int accommodationType = scanner.nextInt();

        double accommodationCostPerNight = 0;

        // Determine the cost per night for accommodation based on the type selected
        if (accommodationType == 1) {
            accommodationCostPerNight = HOTEL_COST_PER_NIGHT;
            System.out.println("You selected Hotel. Cost: PHP 1500 per night.");
        } else if (accommodationType == 2) {
            accommodationCostPerNight = HOSTEL_COST_PER_NIGHT;
            System.out.println("You selected Hostel. Cost: PHP 800 per night.");
        } else if (accommodationType == 3) {
            accommodationCostPerNight = AIRBNB_COST_PER_NIGHT;
            System.out.println("You selected Airbnb. Cost: PHP 1200 per night.");
        } else {
            System.out.println("Invalid accommodation type selected.");
            scanner.close();
            return;
        }

        // Calculate the total accommodation cost
        double accommodationCost = accommodationCostPerNight * numberOfDays;

        // Calculate the total trip cost
        double totalCost = transportationCost + accommodationCost;

        // Apply discount if the number of days exceeds the discount threshold
        if (numberOfDays >= DISCOUNT_THRESHOLD_DAYS) {
            totalCost = totalCost * (1 - DISCOUNT_RATE); // Apply a 10% discount
            System.out.println("A 10% discount has been applied for long stays.");
        }

        // Display the final total cost
        System.out.println("Transportation cost: PHP " + transportationCost);
        System.out.println("Accommodation cost: PHP " + accommodationCost);
        System.out.println("Your total trip cost is: PHP " + totalCost);

        // Close the scanner
        scanner.close();
    }
}
