import java.util.Scanner;

public class Ex28MealPriceCalculator {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // Input: Ask the user to choose a meal type
        System.out.println("Choose a meal type: ");
        System.out.println("1. Breakfast");
        System.out.println("2. Lunch");
        System.out.println("3. Dinner");
        int mealType = scanner.nextInt();

        double basePrice = 0;

        // Determine the base price based on the meal type
        if (mealType == 1) {
            basePrice = 150.00;
            System.out.println("You chose Breakfast. Base price: PHP " + basePrice);
        } else if (mealType == 2) {
            basePrice = 300.00;
            System.out.println("You chose Lunch. Base price: PHP " + basePrice);
        } else if (mealType == 3) {
            basePrice = 450.00;
            System.out.println("You chose Dinner. Base price: PHP " + basePrice);
        } else {
            System.out.println("Invalid meal type chosen.");
            scanner.close();
            return;
        }

        // Nested condition: Ask if the customer wants a drink
        System.out.print("Would you like to add a drink for PHP 50.00? (yes/no): ");
        String addDrink = scanner.next();

        double totalPrice = basePrice;

        if (addDrink.equalsIgnoreCase("yes")) {
            totalPrice += 50.00;
            System.out.println("Drink added. Total price: PHP " + totalPrice);
        } else {
            System.out.println("No drink added. Total price: PHP " + totalPrice);
        }

        // Close the scanner
        scanner.close();
    }
}
