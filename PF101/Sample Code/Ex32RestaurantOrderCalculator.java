import java.util.Scanner;

public class Ex32RestaurantOrderCalculator {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Initialize constants for dish prices
        final double PASTA_PRICE = 250.00;
        final double BURGER_PRICE = 180.00;
        final double SALAD_PRICE = 120.00;

        // Initialize variables for total cost
        double totalCost = 0;

        // Input: Ask the user for the number of different dish types
        System.out.print("Enter the number of different dish types in your order: ");
        int numDishTypes = scanner.nextInt();

        // Loop to input details for each dish type
        for (int i = 0; i < numDishTypes; i++) {
            // Input: Ask the user for the dish type
            System.out.println("Select dish type for dish " + (i + 1) + ": ");
            System.out.println("1. Pasta (PHP 250 each)");
            System.out.println("2. Burger (PHP 180 each)");
            System.out.println("3. Salad (PHP 120 each)");
            int dishType = scanner.nextInt();

            // Input: Ask the user for the quantity of this dish type
            System.out.print("Enter the quantity of this dish type: ");
            int quantity = scanner.nextInt();

            double pricePerDish = 0;

            // Determine the price per dish based on the type selected
            if (dishType == 1) {
                pricePerDish = PASTA_PRICE;
                System.out.println("You selected Pasta. Price: PHP 250 each.");
            } else if (dishType == 2) {
                pricePerDish = BURGER_PRICE;
                System.out.println("You selected Burger. Price: PHP 180 each.");
            } else if (dishType == 3) {
                pricePerDish = SALAD_PRICE;
                System.out.println("You selected Salad. Price: PHP 120 each.");
            } else {
                System.out.println("Invalid dish type selected.");
                continue;  // Skip to the next dish type
            }

            // Calculate the cost for this dish type
            double dishCost = pricePerDish * quantity;
            totalCost += dishCost;
        }

        // Calculate the service charge (10% of the total cost)
        double serviceCharge = totalCost * 0.10;

        // Add service charge to total cost
        totalCost += serviceCharge;

        // Nested condition: Apply a discount based on the total cost
        if (totalCost >= 1000) {
            totalCost = totalCost * 0.90;  // Apply a 10% discount
            System.out.println("A 10% discount has been applied.");
        }

        // Display the final total cost with service charge
        System.out.println("Your total cost including service charge is: PHP " + totalCost);

        // Close the scanner
        scanner.close();
    }
}
