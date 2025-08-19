<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>User Management System</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        table, th, td {
            border: 1px solid #ddd;
            padding: 8px;
        }
        form {
            background-color: #f4f4f4;
            padding: 20px;
            border-radius: 5px;
        }
        .message {
            color: green;
            margin-bottom: 10px;
        }
        .error {
            color: red;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <h1>User Management System</h1>

    <?php
    // Display messages
    if (isset($_GET['message'])) {
        echo "<div class='message'>" . htmlspecialchars($_GET['message']) . "</div>";
    }
    if (isset($_GET['error'])) {
        echo "<div class='error'>" . htmlspecialchars($_GET['error']) . "</div>";
    }
    ?>

    <!-- Add User Form -->
    <form action="includes/create_user.php" method="post">
        <h2>Add New User</h2>
        <input type="text" name="name" placeholder="Name" required>
        <input type="email" name="email" placeholder="Email" required>
        <input type="tel" name="phone" placeholder="Phone">
        <button type="submit">Add User</button>
    </form>

    <!-- User List -->
    <h2>User List</h2>
    <table>
        <thead>
            <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Email</th>
                <th>Phone</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
            <?php
            include 'includes/read_users.php';
            if ($result->num_rows > 0) {
                while($row = $result->fetch_assoc()) {
                    echo "<tr>";
                    echo "<td>" . $row['id'] . "</td>";
                    echo "<td>" . $row['name'] . "</td>";
                    echo "<td>" . $row['email'] . "</td>";
                    echo "<td>" . $row['phone'] . "</td>";
                    echo "<td>
                        <a href='includes/edit_user.php?id=" . $row['id'] . "'>Edit</a> | 
                        <a href='includes/delete_user.php?id=" . $row['id'] . "' onclick='return confirm(\"Are you sure?\")'>Delete</a>
                    </td>";
                    echo "</tr>";
                }
            } else {
                echo "<tr><td colspan='5'>No users found</td></tr>";
            }
            ?>
        </tbody>
    </table>
</body>
</html>