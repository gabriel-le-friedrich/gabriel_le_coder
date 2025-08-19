<?php
require_once 'includes/config_session.inc.php';
require_once 'includes/signup_view.inc.php';
require_once 'includes/login_view.inc.php';
?>


<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Document</title>
    <link rel="stylesheet" href="css/reset.css">
    <link rel="stylesheet" href="css/main.css">

</head>
<body>

    <h1>
        <?php
            output_username();
        ?>
    </h1>

    <?php
    if (!isset($_SESSION["user_id"])) { ?>
        <div class="form">
            <h1>Log in</h1>
            <form action="includes/login.inc.php" method="post">
                <input class="txt" type="text" name="user" placeholder="Username">
                <input class="txt" type="password" name="pass" placeholder="Password">
                <input class="btn" type="submit" value="Log in">
            </form>
        </div>
    <?php }
    ?>

    <?php 
        check_login_errors();
    ?>

    <div class="form">
        <h1>Sign up</h1>
        <form action="includes/signup.inc.php" method="post">
            <?php
            signup_inputs();
            ?>
            <input class="btn" type="submit" value="Sign up">
        </form>
    </div>

    <?php 
        check_signup_errors();
    ?>

    <div class="form">
        <h1>Log out</h1>
        <form action="includes/logout.inc.php" method="post">
            <input class="btn" type="submit" value="Log out">
        </form>
    </div>

</body>
</html>