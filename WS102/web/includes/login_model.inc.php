<?php

declare(strict_types=1);

function get_user(object $pdo, string $username) {
    $query = "SELECT * FROM users WHERE username = :username;";
    $ps = $pdo->prepare($query);
    $ps->bindParam(":username", $username);
    $ps->execute();

    $result = $ps->fetch(PDO::FETCH_ASSOC);
    return $result;
}