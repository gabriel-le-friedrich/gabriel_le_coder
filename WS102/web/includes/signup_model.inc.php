<?php

declare(strict_types=1);

function get_username(object $pdo, string $username) {
    $query = "SELECT username FROM users WHERE username = :username;";
    $ps = $pdo->prepare($query);
    $ps->bindParam(":username", $username);
    $ps->execute();

    $result = $ps->fetch(PDO::FETCH_ASSOC);
    return $result;
}

function get_email(object $pdo, string $email) {
    $query = "SELECT email FROM users WHERE email = :email;";
    $ps = $pdo->prepare($query);
    $ps->bindParam(":email", $email);
    $ps->execute();

    $result = $ps->fetch(PDO::FETCH_ASSOC);
    return $result;
}

function set_user(object $pdo, string $username, string $pwd, string $email) {
    $query = "INSERT INTO users (username, pwd, email) VALUES (:username, :pwd, :email)";
    $ps = $pdo->prepare($query);

    $options =  [
        'cost' => 12
    ];

    $hashedPwd = password_hash($pwd, PASSWORD_BCRYPT, $options);

    $ps->bindParam(":username", $username);
    $ps->bindParam(":pwd", $hashedPwd);
    $ps->bindParam(":email", $email);
    $ps->execute();
}