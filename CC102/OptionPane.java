import javax.swing.*;

public class OptionPane {
    JFrame f;
    OptionPane() {
        f=new JFrame();
        String name=JOptionPane.showInputDialog(f,"Enter Name");
    }
public static void main(String[] args) {
    new OptionPane();
    }
}
