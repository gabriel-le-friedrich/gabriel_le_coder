<?php
    require_once 'pages.php';
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gaming Hub</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.2/css/all.min.css" integrity="sha512-z3gLpd7yknf1YoNbCzqRKc4qyor8gaKU1qmn+CShxbuBusANI9QpRohGBreCFkKxLhei6S9CQXFEbbKuqLg0DA==" crossorigin="anonymous" referrerpolicy="no-referrer">
    <link rel="stylesheet" href="./css/reset.css">
    <!-- <link rel="stylesheet" href="./css/content.css"> -->

<style>
    nav {
        width: 100%;
        display: flex;
        flex-direction: row;
        justify-content: space-between;
        background-color: rgb(0, 0, 0);
    }

    .nav {
        width: 60%;
        display: flex;
        justify-content: space-evenly;
        align-items: center;
    }

    .nav a, .user p {
        color: white;
        text-decoration: none;
        font-size: 175%;
    }

    .nav a:hover {
        color: gray;
    }

    .user {
        width: 40%;
        display: flex;
        justify-content: flex-end;
        align-items: center;
        margin-right: 1%;
    }

    .greetings {
        margin-right: 5%;
    }

    .logout-btn {
        border: 2px white solid;
        border-radius: 10%;
        background-color: black;
        color: white;
        font-size: 20px;
        cursor: pointer;
    }

    .logout-btn:hover {
        border: 2px black solid;
        background-color: white;
        color: black;
        transition: 0.5s;
    }

    #HOME p,#GAMES p,#ABOUT p {
        color: white;
        font-family: 'Franklin Gothic Medium', 'Arial Narrow', Arial, sans-serif;
        font-size: 250%;
        display: flex;
        justify-content: center;
    }

    .apps {
        background-color: rgba(0, 0, 0, 0.562);
        display: flex;
        justify-content: center;
        flex-wrap: wrap;
    }

    .game {
        background-color: rgb(87, 87, 87);
        height: 400px;
        width: 300px;
        border-radius: 5%;
        margin: 2.5%;
        display: flex;
        justify-content: center;
        align-items: center;
        flex-direction: column;
    }

    .game img {
        height: 250px;
        width: 250px;
        border-radius: 15%;
        display: flex;
        justify-content: center;
    }

    footer {
        height: 10%;
        width: 100%;
    }

    .footer {
        height: 70%;
        display: flex;
        justify-content: center;
        padding: 1% 5% 1% 5%;
    }

    .socialIcons {
        display: flex;
        justify-content: center;
    }

    .socialIcons a {
        text-decoration: none;
        padding: 5%;
        background-color: white;
        margin: 5%;
        border-radius: 50%;
    }

    .socialIcons a i {
        font-size: 200%;
        color: black;
        opacity: 0.9;
    }

    .socialIcons a:hover {
        background-color: #111;
        transition: 0.5s;
    }

    .socialIcons a:hover i {
        color: white;
        transition: 0.5s;
    }

    .footerBottom {
        height: 40%;
        background-color: black;
        font-family: 'Franklin Gothic Medium', 'Arial Narrow', Arial, sans-serif;
        font-size: 30px;
        color: white;
        display: flex;
        justify-content: center;
        align-items: center;
    }
</style>

</head>
<body>
    <nav>
        <div class="nav">
            <a href="#HOME">HOME</a>
            <a href="#GAMES">GAMES</a>
            <a href="#ABOUT">ABOUT</a>
        </div>
        
        <div class="user">
            <p class="greetings">Welcome, <?php 
            variables();
            ?>!</p>
            <form action="index.php" method="post">
                <button class="logout-btn">
                    Log out
                </button>
            </form>
        </div>
    </nav>

    <div class="main">
        <main id="HOME">
            <p>WELCOME TO GAMING HUB</p>
        </main>
    </div>

    <div class="contents">
        <div id="GAMES">
            <p>GAMES</p>
            <div class="apps">
                <div class="game">
                    <div class="img">
                        <img src="./pics/ML.jpg" alt="Mobile Legends Icon">
                    </div>
                    <p>Mobile Legends</p>
                </div>
                <div class="game">
                    <div class="img">
                        <img src="./pics/COC.jpg" alt="Clash of Clans Icon">
                    </div>
                    <p>Clash of Clans</p>
                </div>
                <div class="game">
                    <div class="img">
                        <img src="./pics/COD.jpg" alt="Call of Duty Icon">
                    </div>
                    <p>Call of Duty</p>
                </div>
                <div class="game">
                    <div class="img">
                        <img src="./pics/SL.jpg" alt="Solo Leveling Icon">
                    </div>
                    <p>Solo Leveling</p>
                </div>
            </div>
        </div>
        <div id="ABOUT">
            <p>ABOUT</p>
            <div>
                <p>This is a gaming site.</p>
            </div>
        </div>
    </div>

    <div>
        <footer>
            <div class="footer">
                <div>
                    <div class="socialIcons">
                        <a href="" target="_blank"><i class="fa-brands fa-facebook"></i></a>
                        <a href="" target="_blank"><i class="fa-brands fa-instagram"></i></a>
                        <a href="" target="_blank"><i class="fa-brands fa-twitter"></i></a>
                    </div>
                </div>
            </div>
            <div class="footerBottom">
                <p>
                    Copyright © 2025. All Rights Reserved.
                </p>            
            </div>
        </footer>
    </div>
    
</body>
</html>