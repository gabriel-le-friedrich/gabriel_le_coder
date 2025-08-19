<?php

// Initializing Setting
ini_set('session.use_only_cookies', 1); // Cookies
ini_set('session.use_strict_mode', 1); // Security

// Setting Cookie Parameters
session_set_cookie_params([
    'lifetime' => 1800, //time
    'domain' => 'localhost', //domain
    'path' => '/', //path or sub-path
    'secure' => true, //secured
    'httponly' => true //to avoid the user to change the cookie using a script
]);

// Starting Session
session_start();


// Cookie regeneration every 30 minutes
if (!isset($_SESSION["last_regeneration"])) {
    regenerate_session_id();
} else {
    $interval = 60 * 30;
    if (time() - $_SESSION["last_regeneration"] >= $interval) {
        regenerate_session_id();
    }
}

function regenerate_session_id() {
    session_regenerate_id(true);
    $_SESSION["last_regeneration"] = time();
}

//Storing variables from index.php
function variables() {
    $username = $_POST["user"];
    $pwd = $_POST["pass"];
    echo $username;
}

function output_username() {
    if (isset($_SESSION["user_id"])) {
        echo "You are logged in as " . $_SESSION["user_username"];
    } else {
        echo "You are not logged in!";
    }
}

// Exterminate the session
function Logout() {
    session_start();
    session_unset();
    session_destroy();

    header("Location: ./index.php");
    die();
}

