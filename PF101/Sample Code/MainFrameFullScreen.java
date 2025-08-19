package sample1;

import java.sql.*;
import javax.swing.*;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;


public class MainFrameFullScreen extends JFrame {

    // GUI Components
    private JLabel lblProductName, lblProductPrice, lblProductQuantity, lblProductId, lblTitle;
    private JTextField txtPName, txtPPrice, txtPQuantity;
    private JComboBox<String> txtPId;
    private JButton btnAdd, btnUpdate, btnDelete, btnSearch;
    private JTable jTable1;
    private DefaultTableModel tableModel;
    private JScrollPane jScrollPane;

    // Database components
    Connection con;
    PreparedStatement pst;
    ResultSet rs;

    public MainFrameFullScreen() {
        setTitle("Java CRUD Operation");
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

        // Set to full-screen mode
        setExtendedState(JFrame.MAXIMIZED_BOTH);

        // Set Layout Manager
        setLayout(new BorderLayout());

        // Connect to database
        Connect();

        // Initialize Components
        initComponents();

        // Load Data
        LoadProductNo();
        Fetch();

        setVisible(true);
    }

    public void Connect() {
        try {
            Class.forName("com.mysql.jdbc.Driver");
            con = DriverManager.getConnection("jdbc:mysql://localhost/javacrud", "root", "");
        } catch (ClassNotFoundException | SQLException ex) {
            ex.printStackTrace();
        }
    }
    
    

    
    private void initComponents() {
        // Title Panel
        JPanel titlePanel = new JPanel();
        lblTitle = new JLabel("JAVA CRUD OPERATION", SwingConstants.CENTER);
        lblTitle.setFont(new java.awt.Font("Arial", java.awt.Font.BOLD, 16));
        titlePanel.setLayout(new BorderLayout());
        titlePanel.add(lblTitle, BorderLayout.CENTER);
        add(titlePanel, BorderLayout.NORTH);

        // Input Fields and Buttons Panel
        JPanel inputPanel = new JPanel(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(10, 10, 10, 10);
        gbc.fill = GridBagConstraints.HORIZONTAL;

        lblProductName = new JLabel("Product Name:");
        lblProductPrice = new JLabel("Product Price:");
        lblProductQuantity = new JLabel("Product Quantity:");
        lblProductId = new JLabel("Product ID:");

        txtPName = new JTextField(15);
        txtPPrice = new JTextField(15);
        txtPQuantity = new JTextField(15);
        txtPId = new JComboBox<>();

        btnSearch = new JButton("Search");

        // Add components to the input panel
        gbc.gridx = 0; 
        gbc.gridy = 0;
        inputPanel.add(lblProductName, gbc);
        gbc.gridx = 1;
        inputPanel.add(txtPName, gbc);

        gbc.gridx = 0; 
        gbc.gridy = 1;
        inputPanel.add(lblProductPrice, gbc);
        gbc.gridx = 1;
        inputPanel.add(txtPPrice, gbc);

        gbc.gridx = 0; 
        gbc.gridy = 2;
        inputPanel.add(lblProductQuantity, gbc);
        gbc.gridx = 1;
        inputPanel.add(txtPQuantity, gbc);

        gbc.gridx = 2; 
        gbc.gridy = 0;
        inputPanel.add(lblProductId, gbc);
        gbc.gridx = 3;
        inputPanel.add(txtPId, gbc);
        gbc.gridx = 4;
        inputPanel.add(btnSearch, gbc);

        // Buttons Panel
        JPanel buttonsPanel = new JPanel(new FlowLayout(FlowLayout.CENTER, 20, 10));
        btnAdd = new JButton("Add");
        btnUpdate = new JButton("Update");
        btnDelete = new JButton("Delete");
        

        buttonsPanel.add(btnAdd);
        buttonsPanel.add(btnUpdate);
        buttonsPanel.add(btnDelete);
    

        gbc.gridx = 0;
        gbc.gridy = 4;
        gbc.gridwidth = 5;
        inputPanel.add(buttonsPanel, gbc);

        add(inputPanel, BorderLayout.CENTER);

        // Table Panel
        tableModel = new DefaultTableModel(new Object[]{"Product ID", "Product Name", "Price", "Quantity"}, 0);
        jTable1 = new JTable(tableModel);
        jScrollPane = new JScrollPane(jTable1);

        add(jScrollPane, BorderLayout.SOUTH);

        // Add Action Listeners
        btnAdd.addActionListener(evt -> addRecord());
        btnUpdate.addActionListener(evt -> updateRecord());
        btnDelete.addActionListener(evt -> deleteRecord());
        //btnSearch.addActionListener(evt -> searchRecord());
        
        btnSearch.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent evt) {
                searchRecord();
            }
        });
   
    }

    private void Fetch() {
        try {
            pst = con.prepareStatement("SELECT * FROM product_tbl");
            rs = pst.executeQuery();
            //clears the current rows in the table before adding new ones. 
            tableModel.setRowCount(0);
            while (rs.next()) {
                tableModel.addRow(new Object[]{
                        rs.getString("id"),
                        rs.getString("pname"),
                        rs.getString("price"),
                        rs.getString("qty")
                });
            }
        } catch (SQLException ex) {
            ex.printStackTrace();
        }
    }

    private void LoadProductNo() {
        try {
            pst = con.prepareStatement("SELECT id FROM product_tbl");
            rs = pst.executeQuery();
            txtPId.removeAllItems();
            while (rs.next()) {
                //This gets the value of the first column in the current row. In this case, it’s the id from the product_tbl table.
                txtPId.addItem(rs.getString(1));
                //System.out.println("ang output ay "+rs.getString(1));
            }
        } catch (SQLException ex) {
            ex.printStackTrace();
        }
    }
  
    

    private void addRecord() {
    // Retrieve input values
    //The trim() method removes any extra spaces at the beginning and end of the string.
    String pname = txtPName.getText().trim();
    String price = txtPPrice.getText().trim();
    String qty = txtPQuantity.getText().trim();

    // Validation: Check for empty fields
    if (pname.isEmpty() || price.isEmpty() || qty.isEmpty()) {
        JOptionPane.showMessageDialog(this, "All fields must be filled out!", "Validation Error", JOptionPane.WARNING_MESSAGE);
        return; // Stop further execution if validation fails
    }

    // Additional validation for numeric fields
    try {
        Double.parseDouble(price); // Ensure price is a valid number
        Integer.parseInt(qty); // Ensure quantity is a valid integer
    } catch (NumberFormatException e) {
        JOptionPane.showMessageDialog(this, "Price must be a valid number and Quantity must be an integer!", "Validation Error", JOptionPane.WARNING_MESSAGE);
        return;
    }

    // Insert the record into the database
    try {
        pst = con.prepareStatement("INSERT INTO product_tbl (pname, price, qty) VALUES (?, ?, ?)");
        pst.setString(1, pname);
        pst.setString(2, price);
        pst.setString(3, qty);
        pst.executeUpdate();

        JOptionPane.showMessageDialog(this, "Record Added Successfully");
        // Clear the fields after successful addition
        txtPName.setText("");
        txtPPrice.setText("");
        txtPQuantity.setText("");

        // Refresh table and dropdowns
        Fetch();
        LoadProductNo();
    } catch (SQLException ex) {
        ex.printStackTrace();
        JOptionPane.showMessageDialog(this, "Failed to add record!", "Database Error", JOptionPane.ERROR_MESSAGE);
    }
}


    private void updateRecord() {
        String pname = txtPName.getText();
        String price = txtPPrice.getText();
        String qty = txtPQuantity.getText();
        String pid = txtPId.getSelectedItem().toString();
        try {
            pst = con.prepareStatement("UPDATE product_tbl SET pname = ?, price = ?, qty = ? WHERE id = ?");
            pst.setString(1, pname);
            pst.setString(2, price);
            pst.setString(3, qty);
            pst.setString(4, pid);
            pst.executeUpdate();
            JOptionPane.showMessageDialog(this, "Record Updated Successfully");
            Fetch();
        } catch (SQLException ex) {
            ex.printStackTrace();
        }
    }

    private void deleteRecord() {
        String pid = txtPId.getSelectedItem().toString();
        try {
            pst = con.prepareStatement("DELETE FROM product_tbl ");
            //1 refers to the first placeholder in the query (there's only one in this case).
            pst.setString(1, pid);
            pst.executeUpdate();
            JOptionPane.showMessageDialog(this, "Record Deleted Successfully");
            Fetch();
            LoadProductNo();
        } catch (SQLException ex) {
            ex.printStackTrace();
        }
    }

    private void searchRecord() {
        String pid = txtPId.getSelectedItem().toString();
        try {
            pst = con.prepareStatement("SELECT * FROM product_tbl WHERE id = ?");
            pst.setString(1, pid);
            rs = pst.executeQuery();
            if (rs.next()) {
                txtPName.setText(rs.getString("pname"));
                txtPPrice.setText(rs.getString("price"));
                txtPQuantity.setText(rs.getString("qty"));
            } else {
                JOptionPane.showMessageDialog(this, "No Record Found!");
            }
        } catch (SQLException ex) {
            ex.printStackTrace();
        }
    }

   

    public static void main(String[] args) {

        new MainFrameFullScreen();
    }
}
