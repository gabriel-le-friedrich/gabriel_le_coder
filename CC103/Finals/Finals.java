import javax.swing.*;
import java.awt.event.*;

public class Finals {
    public static void main (String [] args) {
        JFrame f = new JFrame("Finals");
        JMenuBar mb = new JMenuBar();

        JMenu file = new JMenu("File");
        JMenu edit = new JMenu("Edit");
        JMenu selection = new JMenu("Selection");
        JMenu view = new JMenu("View");
        
        mb.add(file);
        mb.add(edit);
        mb.add(selection);
        mb.add(view);

        JMenuItem undo = new JMenuItem("Undo");
        JMenuItem copy = new JMenuItem("Copy");
        JMenuItem cut = new JMenuItem("Cut");
        JMenuItem paste = new JMenuItem("Paste");
        JMenuItem selectAll = new JMenuItem("Select All");
        JMenu insert = new JMenu("Insert");
        edit.add(undo);
        edit.add(copy);
        edit.add(cut);
        edit.add(paste);
        edit.add(selectAll);
        edit.add(insert);

        JMenuItem date = new JMenuItem("Date");
        JMenuItem time = new JMenuItem("Time");
        insert.add(date);
        insert.add(time);
        
        f.setJMenuBar(mb);
        f.setSize(400, 400);
        f.setLayout(null);
        f.setVisible(true);
    }
}