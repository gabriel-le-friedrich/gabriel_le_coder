import javax.swing.*;

public class JDemo {
    public static void main(String[] args) {
        JFrame f = new JFrame("Demo");
        f.setSize(500, 500);
        f.setVisible(true);
        f.setLayout(null);

        JLabel l1 = new JLabel("Are you a BSIT 1A Student?");
        l1.setBounds(50, 50, 250, 15);
        f.add(l1);

        JCheckBox cb1 = new JCheckBox("Yes");
        cb1.setBounds(50, 70, 70, 15);
        f.add(cb1);

        JCheckBox cb2 = new JCheckBox("No");
        cb2.setBounds(130, 70, 70, 15);
        f.add(cb2);

        JLabel l2 = new JLabel("Are you a BSIT 1A Student?");
        l2.setBounds(50, 90, 250, 15);
        f.add(l2);

        JRadioButton rb1 = new JRadioButton("Yes");
        rb1.setBounds(50, 110, 70, 15);
        f.add(rb1);

        JRadioButton rb2 = new JRadioButton("No");
        rb2.setBounds(130, 110, 70, 15);
        f.add(rb2);

        ButtonGroup bg = new ButtonGroup();
        bg.add(rb1);
        bg.add(rb2);

        JLabel l3 = new JLabel("Favorite Foods?");
        l3.setBounds(50, 140, 250, 15);
        f.add(l3);

        String foods [] = {"Ice Cream", "Halo-Halo", "Ice Buko"};
        JComboBox b1 = new JComboBox(foods);
        b1.setBounds(50, 160, 250, 25);
        f.add(b1);

    }
}
