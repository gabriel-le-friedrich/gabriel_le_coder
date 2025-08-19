import javax.swing.*;

public class JScroll {
    public static void main(String[] args) {
        
        JFrame f = new JFrame("Scroll Bar Example");
        f.setSize(420, 420);
        f.setVisible(true);
        f.setLayout(null);

        JScrollBar s = new JScrollBar();
        s.setBounds(380, 10, 20, 390);
        f.add(s);


    }
}