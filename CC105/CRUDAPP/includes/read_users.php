<?php
include 'db_connection.php';

$sql = "SELECT * FROM users";
$result = $conn->query($sql);
?>