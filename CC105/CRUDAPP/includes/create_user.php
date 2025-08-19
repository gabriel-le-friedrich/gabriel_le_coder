<?php
include 'db_connection.php';

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $name = $_POST['name'];
    $email = $_POST['email'];
    $phone = $_POST['phone'];

    $sql = "INSERT INTO users (name, email, phone) VALUES (?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sss", $name, $email, $phone);

    if ($stmt->execute()) {
        header("Location: index.php?message=User added successfully");
    } else {
        header("Location: index.php?error=Error adding user");
    }

    $stmt->close();
    $conn->close();
}
?>