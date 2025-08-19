import javax.swing.*;

import java.awt.CheckboxGroup;
import java.awt.Color;

public class Check {
    public static void main(String[] args) {
        JFrame f = new JFrame("Checkbox");
        f.setBounds(150, 60, 300, 300);

        //Checkbox
        JLabel q = new JLabel("Are you a BSIT Student?");
        q.setBounds(20, 50, 200, 30);

        JCheckBox cb1 = new JCheckBox("Yes");
        cb1.setBounds(50, 80, 60, 20);

        JCheckBox cb2 = new JCheckBox("No");
        cb2.setBounds(150, 80, 60, 20);

        // CheckboxGroup cb = new CheckboxGroup();
        // cb.add(cb1);
        // cb.add(cb2);


        //RadioButton
        JLabel q2 = new JLabel("Are you a BSIT Student?");
        q2.setBounds(20, 150, 200, 30);

        JRadioButton r1 = new JRadioButton("Yes");
        r1.setBounds(50, 180, 60, 20);

        JRadioButton r2 = new JRadioButton("No");
        r2.setBounds(150, 180, 60, 20);

        ButtonGroup bg = new ButtonGroup();
        bg.add(r1);
        bg.add(r2);

        //ComboBox
        JLabel q3 = new JLabel("Provinces");
        q3.setBounds(20, 220, 200, 30);

        String provinces [] = {"Tarlac", "Pampanga", "Bulacan"};
        JComboBox prov = new JComboBox(provinces);
        prov.setBounds(20, 250, 200, 30);

        f.getContentPane().setBackground(Color.GREEN);
        f.add(q);
        f.add(q2);
        f.add(q3);
        f.add(cb1);
        f.add(cb2);
        f.add(r1);
        f.add(r2);
        f.add(prov);
        f.setSize(400, 400);
        f.setLayout(null);
        f.setVisible(true);
    }
}