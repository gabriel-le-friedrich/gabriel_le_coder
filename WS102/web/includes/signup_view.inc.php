<?php

declare(strict_types=1);

function signup_inputs() {

    if (isset($_SESSION["signup_data"]["username"]) && !isset($_SESSION["errors_signup"]["username_taken"])) {
        echo '<input class="txt" type="text" name="user" placeholder="Username" value="'. $_SESSION["signup_data"]["username"] .'">';
    } else {
        echo '<input class="txt" type="text" name="user" placeholder="Username">';
    }

    echo '<input class="txt" type="password" name="pass" placeholder="Password">';

    if (isset($_SESSION["signup_data"]["email"]) && !isset($_SESSION["errors_signup"]["email_used"]) && !isset($_SESSION["errors_signup"]["invalid_email"])) {
        echo '<input class="txt" type="text" name="email" placeholder="E-mail" value="'. $_SESSION["signup_data"]["email"] .'">';
    } else {
        echo '<input class="txt" type="text" name="email" placeholder="E-mail">';
    }
}

function check_signup_errors() {
    if (isset($_SESSION["errors_signup"])) {
        $errors = $_SESSION["errors_signup"];

        echo "<br>";

        foreach ($errors as $error) {
            echo '<p class="form-error">'. $error .'</p>';
        }

        unset($_SESSION["errors_signup"]);
    } elseif (isset($_GET["signup"]) && $_GET["signup"]) {
        echo '<br>';
        echo '<p class="form-success">Signup Success!</p>';
    }
}