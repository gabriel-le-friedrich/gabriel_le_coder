<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Edit User</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 400px;
            margin: 0 auto;
            padding: 20px;
        }
        form {
            background-color: #f4f4f4;
            padding: 20px;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <h1>Edit User</h1>
    <?php
    include 'db_connection.php';

    if (isset($_GET['id'])) {
        $id = $_GET['id'];
        $sql = "SELECT * FROM users WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();
    }
    ?>
    <form action="update_user.php" method="post">
        <input type="hidden" name="id" value="<?php echo $user['id']; ?>">
        <input type="text" name="name" value="<?php echo $user['name']; ?>" required>
        <input type="email" name="email" value="<?php echo $user['email']; ?>" required>
        <input type="tel" name="phone" value="<?php echo $user['phone']; ?>">
        <button type="submit">Update User</button>
    </form>
</body>
</html>