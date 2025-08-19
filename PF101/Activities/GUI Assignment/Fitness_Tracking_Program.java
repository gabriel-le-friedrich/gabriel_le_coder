import javax.swing.JOptionPane;

public class Fitness_Tracking_Program {
    public static void main(String[] args) {
        // Set system look and feel
        try {
            javax.swing.UIManager.setLookAndFeel(
                javax.swing.UIManager.getSystemLookAndFeelClassName()
            );
        } catch (Exception e) {
            System.out.println("Look and feel not set");
        }

        // Get favorite sport
        String sport = JOptionPane.showInputDialog(
            null,
            "What is your favorite sport?",
            "Sport Preference",
            JOptionPane.QUESTION_MESSAGE
        );

        // Check if user canceled or left sport empty
        if (sport == null || sport.trim().isEmpty()) {
            JOptionPane.showMessageDialog(
                null,
                "No sport entered. Program will exit.",
                "Exit",
                JOptionPane.INFORMATION_MESSAGE
            );
            System.exit(0);
        }

        // Get weekly practice hours
        double weeklyHours = 0;
        boolean validInput = false;
        
        while (!validInput) {
            String hoursInput = JOptionPane.showInputDialog(
                null,
                "How many hours per week do you practice " + sport + "?",
                "Practice Hours",
                JOptionPane.QUESTION_MESSAGE
            );

            // Check if user canceled
            if (hoursInput == null) {
                JOptionPane.showMessageDialog(
                    null,
                    "No hours entered. Program will exit.",
                    "Exit",
                    JOptionPane.INFORMATION_MESSAGE
                );
                System.exit(0);
            }

            try {
                weeklyHours = Double.parseDouble(hoursInput);
                if (weeklyHours < 0) {
                    JOptionPane.showMessageDialog(
                        null,
                        "Please enter a positive number.",
                        "Invalid Input",
                        JOptionPane.ERROR_MESSAGE
                    );
                } else {
                    validInput = true;
                }
            } catch (NumberFormatException e) {
                JOptionPane.showMessageDialog(
                    null,
                    "Please enter a valid number.",
                    "Invalid Input",
                    JOptionPane.ERROR_MESSAGE
                );
            }
        }

        // Calculate monthly hours
        double monthlyHours = weeklyHours * 4;

        // Create and display message
        String message = String.format("If you keep playing %s, you'll spend %.1f hours on it each month!", 
            sport.trim(), monthlyHours);

        JOptionPane.showMessageDialog(
            null,
            message,
            "Monthly Practice Time",
            JOptionPane.INFORMATION_MESSAGE
        );
    }
}