<?php
include 'db_connection.php';

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $id = $_POST['id'];
    $name = $_POST['name'];
    $email = $_POST['email'];
    $phone = $_POST['phone'];

    $sql = "UPDATE users SET name = ?, email = ?, phone = ? WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssi", $name, $email, $phone, $id);

    if ($stmt->execute()) {
        header("Location: index.php?message=User updated successfully");
    } else {
        header("Location: index.php?error=Error updating user");
    }

    $stmt->close();
    $conn->close();
}
?>