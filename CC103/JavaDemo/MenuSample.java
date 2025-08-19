import javax.swing.*;
import java.awt.event.*;

public class MenuSample implements ActionListener{

	JTextArea textarea;
	JMenuItem undo,cut,copy,paste,selectAll;
	
	MenuSample() {
	
	//JFrame - container of Swing Components
	JFrame f = new JFrame("Menu Sample");
	//JMenuBar - container of JMenu
	JMenuBar menubar = new JMenuBar();
	//creating JMenu
	JMenu file = new JMenu("File");
	JMenu edit = new JMenu("Edit");
	JMenu search = new JMenu("Search");
	JMenu view = new JMenu("View");
	menubar.add(file);menubar.add(edit);
	menubar.add(search);menubar.add(view);
	//creating JMenuItems inside of Edit JMenu
	undo = new JMenuItem("Undo");
	cut = new JMenuItem("Cut");
	copy = new JMenuItem("Copy");
	paste= new JMenuItem("Paste");
	selectAll = new JMenuItem("Select All");
	undo.addActionListener(this);
	cut.addActionListener(this);
	copy.addActionListener(this);
	paste.addActionListener(this);
	selectAll.addActionListener(this);
	//adding JMenuItems to JMenu
	edit.add(undo);
	edit.addSeparator();
	edit.add(cut);
	edit.addSeparator();
	edit.add(copy);
	edit.addSeparator();
	edit.add(paste);
	edit.addSeparator();
	edit.add(selectAll);
	
	//JTextArea
	textarea = new JTextArea();
	textarea.setBounds(5,5,380,380);
	f.add(textarea);
	
	//adding submenu
	JMenu insert = new JMenu("Insert");
	edit.add(insert);
	JMenuItem date = new JMenuItem("Date Time (short)");
	JMenuItem time = new JMenuItem("Date Time (long)");
	insert.add(date);
	insert.addSeparator();
	insert.add(time);
	
	f.setJMenuBar(menubar);//adding JMenuBar to JFrame
	f.setSize(400,400);
	f.setLayout(null);
	f.setVisible(true);
	
	}public void actionPerformed(ActionEvent e){
		// if(e.getSource()==undo)
		// 	textarea.undo();
		if(e.getSource()==cut)
			textarea.cut();
		if(e.getSource()==copy)
			textarea.copy();
		if(e.getSource()==paste)
			textarea.paste();
		if(e.getSource()==selectAll)
			textarea.selectAll();
	}
	
	public static void main(String[]args){
		new MenuSample();
	}
}