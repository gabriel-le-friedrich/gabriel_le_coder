<?php
include 'db_connection.php';

if (isset($_GET['id'])) {
    $id = $_GET['id'];

    $sql = "DELETE FROM users WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);

    if ($stmt->execute()) {
        header("Location: index.php?message=User deleted successfully");
    } else {
        header("Location: index.php?error=Error deleting user");
    }

    $stmt->close();
    $conn->close();
}
?>