import javax.swing.*;
import java.awt.event.*;

public class MenuSample implements ActionListener {

    JTextArea textarea;
    JMenuItem undo, copy, cut, paste, selectAll;
        
    MenuSample() {
        JFrame f = new JFrame("Finals");
        JMenuBar menuBar = new JMenuBar();

        JMenu file = new JMenu("File");
        JMenu edit = new JMenu("Edit");
        JMenu search = new JMenu("Search");
        JMenu view = new JMenu("View");
        menuBar.add(file);
        menuBar.add(edit);
        menuBar.add(search);
        menuBar.add(view);

        undo = new JMenuItem("Undo");
        copy = new JMenuItem("Copy");
        cut = new JMenuItem("Cut");
        paste = new JMenuItem("Paste");
        selectAll = new JMenuItem("Select All");

        undo.addActionListener(this);
        cut.addActionListener(this);
        copy.addActionListener(this);
        paste.addActionListener(this);
        selectAll.addActionListener(this);

        edit.add(undo);
        edit.addSeparator();
        edit.add(copy);
        edit.addSeparator();
        edit.add(cut);
        edit.addSeparator();
        edit.add(paste);
        edit.addSeparator();
        edit.add(selectAll);

        textarea = new JTextArea();
        textarea.setBounds(5, 5, 380, 380);
        f.add(textarea);

        JMenu insert = new JMenu("Insert");
        edit.addSeparator();
        edit.add(insert);
        JMenuItem date = new JMenuItem("Date Time (short)");
        JMenuItem time = new JMenuItem("Date Time (long)");
        insert.add(date);
        insert.addSeparator();
        insert.add(time);

        f.setJMenuBar(menuBar);
        f.setSize(500, 500);
        f.setLayout(null);
        f.setVisible(true);
    }

    public void actionPerformed(ActionEvent e) {
        // if (e.setSource()==undo)
        //     ta1.undo();
        if (e.getSource()==cut)
            textarea.cut();
        if (e.getSource()==copy)
            textarea.copy();
        if (e.getSource()==paste)
            textarea.paste();
        if (e.getSource()==selectAll)
            textarea.selectAll();
    }

    public static void main(String[] args) {
        new MenuSample();
    }
}
