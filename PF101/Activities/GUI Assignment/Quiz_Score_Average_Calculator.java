import javax.swing.*;
import java.awt.*;
import java.awt.event.*;

public class Quiz_Score_Average_Calculator extends JFrame {
    private final JTextField[] quizFields;
    private final JLabel resultLabel;
    private final JLabel errorLabel;

    public Quiz_Score_Average_Calculator() {
        // Set up the frame
        setTitle("Quiz Average Calculator");
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setLayout(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        
        // Create panel for quiz inputs
        JPanel quizPanel = new JPanel(new GridLayout(4, 2, 10, 10));
        quizFields = new JTextField[4];
        
        // Create and add quiz input fields
        for (int i = 0; i < 4; i++) {
            quizPanel.add(new JLabel("Quiz " + (i + 1) + " Score:"));
            quizFields[i] = new JTextField(10);
            quizPanel.add(quizFields[i]);
        }
        
        // Create calculate button
        JButton calculateButton = new JButton("Calculate Average");
        
        // Create labels for results and errors
        resultLabel = new JLabel(" ");
        resultLabel.setFont(new Font("SansSerif", Font.BOLD, 14));
        
        errorLabel = new JLabel(" ");
        errorLabel.setForeground(Color.RED);
        
        // Add action listener to button
        calculateButton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                calculateAverage();
            }
        });
        
        // Layout components using GridBagConstraints
        gbc.gridx = 0;
        gbc.gridy = 0;
        gbc.insets = new Insets(10, 10, 10, 10);
        gbc.fill = GridBagConstraints.HORIZONTAL;
        add(quizPanel, gbc);
        
        gbc.gridy = 1;
        add(calculateButton, gbc);
        
        gbc.gridy = 2;
        add(resultLabel, gbc);
        
        gbc.gridy = 3;
        add(errorLabel, gbc);
        
        // Pack and center the frame
        pack();
        setLocationRelativeTo(null);
    }
    
    private void calculateAverage() {
        double total = 0;
        errorLabel.setText(" ");
        resultLabel.setText(" ");
        
        try {
            // Validate and sum all scores
            for (JTextField field : quizFields) {
                double score = Double.parseDouble(field.getText().trim());
                
                // Validate score range
                if (score < 0 || score > 100) {
                    errorLabel.setText("Error: Scores must be between 0 and 100");
                    return;
                }
                
                total += score;
            }
            
            // Calculate and display average
            double average = total / quizFields.length;
            resultLabel.setText(String.format("Average Score: %.2f", average));
            
            // Add color coding based on average
            if (average >= 90) {
                resultLabel.setForeground(new Color(0, 128, 0)); // Dark Green
            } else if (average >= 70) {
                resultLabel.setForeground(new Color(0, 0, 128)); // Dark Blue
            } else {
                resultLabel.setForeground(new Color(128, 0, 0)); // Dark Red
            }
            
        } catch (NumberFormatException ex) {
            errorLabel.setText("Error: Please enter valid numeric values");
        }
    }
    
    public static void main(String[] args) {
        // Set system look and feel
        try {
            UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        } catch (Exception e) {
            System.out.println("Look and feel not set");
        }
        
        // Create and show GUI
        SwingUtilities.invokeLater(new Runnable() {
            @Override
            public void run() {
                new Quiz_Score_Average_Calculator().setVisible(true);
            }
        });
    }
}