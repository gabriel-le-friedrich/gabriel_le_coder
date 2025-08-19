import java.util.Scanner;

public class Ex31ShoppingCartCalculator {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Initialize constants for item prices
        final double ELECTRONICS_PRICE = 1500.00;
        final double CLOTHING_PRICE = 800.00;
        final double GROCERIES_PRICE = 200.00;

        // Initialize variables for total cost
        double totalCost = 0;

        // Input: Ask the user for the number of different item types
        System.out.print("Enter the number of different item types in your cart: ");
        int numItemTypes = scanner.nextInt();

        // Loop to input details for each item type
        for (int i = 0; i < numItemTypes; i++) {
            // Input: Ask the user for the item type
            System.out.println("Select item type for item " + (i + 1) + ": ");
            System.out.println("1. Electronics (PHP 1500 each)");
            System.out.println("2. Clothing (PHP 800 each)");
            System.out.println("3. Groceries (PHP 200 each)");
            int itemType = scanner.nextInt();

            // Input: Ask the user for the number of items of this type
            System.out.print("Enter the number of items of this type: ");
            int numItems = scanner.nextInt();

            double pricePerItem = 0;

            // Determine the price per item based on the type selected
            if (itemType == 1) {
                pricePerItem = ELECTRONICS_PRICE;
                System.out.println("You selected Electronics. Price: PHP 1500 each.");
            } else if (itemType == 2) {
                pricePerItem = CLOTHING_PRICE;
                System.out.println("You selected Clothing. Price: PHP 800 each.");
            } else if (itemType == 3) {
                pricePerItem = GROCERIES_PRICE;
                System.out.println("You selected Groceries. Price: PHP 200 each.");
            } else {
                System.out.println("Invalid item type selected.");
                continue;  // Skip to the next item type
            }

            // Calculate the cost for this type of item
            double itemCost = pricePerItem * numItems;
            totalCost += itemCost;
        }

        // Nested condition: Apply a discount based on the total number of items
        if (totalCost >= 10000) {
            totalCost = totalCost * 0.85;  // Apply a 15% discount
            System.out.println("A 15% discount has been applied.");
        } else if (totalCost >= 5000) {
            totalCost = totalCost * 0.90;  // Apply a 10% discount
            System.out.println("A 10% discount has been applied.");
        }

        // Display the final total cost
        System.out.println("Your total cost for all items is: PHP " + totalCost);

        // Close the scanner
        scanner.close();
    }
}
