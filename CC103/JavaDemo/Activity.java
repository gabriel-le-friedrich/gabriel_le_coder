import javax.swing.*;
import java.awt.*;

public class Activity {
    public static void main(String[] args) {
        JFrame f = new JFrame("Activity...");
        f.setBounds(500, 100, 800, 800);
        f.setSize(800, 800);
        f.setLayout(null);
        f.setVisible(true);

        JLabel l1 = new JLabel("What is your name?");
        l1.setBounds(100, 50, 150, 15);
        f.add(l1);

        JLabel l2 = new JLabel("Email:");
        l2.setBounds(50, 100, 100, 15);
        f.add(l2);

        JTextField t1 = new JTextField();
        t1.setBounds(50, 120, 150, 15);
        f.add(t1);

        JLabel l3 = new JLabel("Password:");
        l3.setBounds(50, 140, 100, 15);
        f.add(l3);

        JTextField t2 = new JTextField();
        t2.setBounds(50, 160, 150, 15);
        f.add(t2);



        JButton btn1 = new JButton("Submit");
        btn1.setBounds(50, 200, 200, 25);
        f.add(btn1);

    }
}