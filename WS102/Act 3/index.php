<?php
    require_once 'pages.php';
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Log in/Sign up</title>
    <link rel="stylesheet" href="./css/reset.css">
    <!-- <link rel="stylesheet" href="./css/main.css"> -->

<style>
    body {
        height: 920px;
        display: flex;
        justify-content: center;
        align-items: center;
    }

    .main {
        width: 100%;
        height: 100%;
        display: flex;
        justify-content: space-around;
        align-items: center;
        flex-direction: column;
    }

    .login {
        color: white;
        font-size: large;
        margin: 1% ;
    }

    .login-form {
        height: 50%;
        width: 30%;
        display: flex;
        justify-content: center;
        align-items: center;
        flex-direction: column;
    }

    .form {
        display: flex;
        align-items: center;
        flex-direction: column;
        background-color: rgba(95, 95, 95, 0.397);
        color: rgb(255, 255, 255);
        height: 100%;
        width: 100%;
        font-size: 25px;
        border-radius: 5%;
    }

    form.l {
        height: 50%;
        width: 100%;
        display: flex;
        justify-content: space-evenly;
        align-items: center;
        flex-direction: column;
    }

    input.txt {
        width: 70%;
        height: 15%;
        font-size: large;
        border: 3px rgb(255, 255, 255) solid;
        border-radius: 10px;
    }

    input.btnl {
        width: 50%;
        height: 15%;
        font-size: large;
        color: white;
        border-radius: 10px;
        border: 1px black solid;
        background-color: black;
        cursor: pointer;
    }

    .terminate-form {
        height: 50%;
        width: 30%;
        color: white;
        display: flex;
        justify-content: center;
        align-items: center;
        flex-direction: column;
    }

    form.t {
        height: 5%;
        width: 100%;
        display: flex;
        justify-content: space-evenly;
        align-items: center;
        flex-direction: column;
    }

    input.btnt {
        width: 50%;
        height: auto;
        font-size: large;
        color: white;
        border-radius: 10px;
        border: 1px black solid;
        background-color: black;
        cursor: pointer;
    }

    .btnt:hover,.btnl:hover {
        background-color: white;
        color: black;
        transition: 0.5s ;
    }

</style>

</head>
<body>
    <div class="main">

        <div class="login">
            <?php
                output_username()
            ?>
        </div>

        <div class="login-form">
            <?php
                if (!isset($_SESSION["user_id"])) { ?>
                <div class="form">
                    <h1>Log in</h1>
                    <form class="l" action="contents.php" method="post">
                        <input required class="txt" type="text" name="user" placeholder="Username">
                        <input required class="txt" type="password" name="pass" placeholder="Password">
                        <input class="btnl" type="submit" value="Log in">
                    </form>
                </div>
            <?php }
            ?>
        </div>
        
    </div>
</body>
</html>