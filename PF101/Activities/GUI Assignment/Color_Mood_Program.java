import javax.swing.*;

public class Color_Mood_Program {
    public static void main(String[] args) {
        // Set up the look and feel to match the system
        try {
            javax.swing.UIManager.setLookAndFeel(
                javax.swing.UIManager.getSystemLookAndFeelClassName()
            );
        } catch (Exception e) {
            System.out.println("Look and feel not set");
        }

        // Show input dialog and store the user's response
        String favoriteFood = JOptionPane.showInputDialog(
            null,
            "What is your favorite food?",
            "Food Preference",
            JOptionPane.QUESTION_MESSAGE
        );

        // Check if user clicked cancel or closed the dialog
        if (favoriteFood == null || favoriteFood.trim().isEmpty()) {
            JOptionPane.showMessageDialog(
                null,
                "No food entered. Program will exit.",
                "Exit",
                JOptionPane.INFORMATION_MESSAGE
            );
            System.exit(0);
        }

        // Create personalized message
        String message = String.format("Wow, %s is delicious! Great choice!", favoriteFood.trim());

        // Show message dialog with personalized response
        JOptionPane.showMessageDialog(
            null,
            message,
            "Your Food Choice",
            JOptionPane.INFORMATION_MESSAGE
        );
    }
}