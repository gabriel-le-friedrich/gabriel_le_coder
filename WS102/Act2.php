<!-- Coded by Frederick Gabrielle Cunanan -->
<!-- BSIT 2-A -->
<!-- Activity 2 on WS102 -->

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gabriel_le_Friedrich Pizzeria</title>

    <!-- Style -->
    <style>
        * {
            margin: 0;
            padding: 1px;
        }

        .navbar {
            display: flex;
            justify-content: space-evenly;
            padding: 10px;
            margin: 10px;
            
        }

        .main-nav {
            width: 50%;
            font-size: 30px;
            font-family: Impact, Haettenschweiler, 'Arial Narrow Bold', sans-serif;
            display: flex;
            justify-content: space-evenly;
        }

        .main-nav a {
            text-decoration: none;
            color: black;
        }

        .main-nav a:hover {
            color: burlywood;
        }

        .log {
            width: 20%;
        }

        .form {
                display: flex;
                justify-content: space-evenly;
            }

        .home {
            width: auto;
            display: flex;
            justify-content: center;
            align-items: center;
            flex-direction: column;
        }

        .products {
            width: 100%;
            margin-bottom: 10px;
            display: flex;
            flex-direction: column;
        }

        .pizza {
            display: flex;
            justify-content: space-evenly;
            flex-direction: column;

        }

        .selections {
            display: flex;
            justify-content: space-evenly;
        }

        .Pepperoni, .Hawaiian, .Creamy {
            width: 30%;
            font-size: 30px;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }

        .Pepperoni label, .Hawaiian label, .Creamy label {
            margin: 5px;
        }

        .input {
            width: 20%;
            height: 50px;
            font-size: large;
        }

        img {
            width: 500px;
            height: 500px;

        }

        .box-order {
            display: flex;
            justify-content: center;
            align-items: center;
        }

        .order {
            width: 200px;
            height: 50px;
            font-size: 30px;
        }
    </style>

</head>
<body>
    <nav class="navbar">
        <!-- Navigation Bar -->
        <div class="main-nav">
            <a href="#home">HOME</a>
            <a href="#products">PRODUCTS</a>
            <a href="#about">ABOUT</a>
        </div>

        <!-- Login/Register Form -->
        <div class="log">
            <!-- <button class="form-box">Log-in/Register</button> -->
            <p id="User"></p>
            <form action="Act2.php" method="post">
                <label>Username:</label>
                <input type="text" id="username" name="username" placeholder="Username"><br>
                <label>Password:</label>
                <input type="password" name="password" placeholder="Password"><br>
                <input type="submit" value="Log in" onclick="EchoUser()">
            </form>
        </div>
    </nav>
    
    
    <!-- Main Content -->
    <div class="home">
        <h1 id="home">Home</h1>
        <h2>Gabriel_le_Friedrich's Pizzeria</h2>    
    
    <!-- Product Content -->
    </div>
    <div class="products">
        <h1 id="products">Products</h1>
        <h2>Pizzas</h2>

        <!-- Item Form -->
        <form class="pizza" action="Act2.php" method="get">
            <div class="selections">
                <div class="Pepperoni">
                    <img src="./img/Act2/Pepperoni.jpg" alt="Pepperoni Pizza">
                    <label for="">Pepperoni Pizza</label>
                    <p>Php 199</p>
                    <input class="input" type="number" name="Pepperoni" id="" placeholder="Quantity"><br><br>
                </div>
    
                <div class="Hawaiian">
                    <img src="./img/Act2/Hawaiian.jpg" alt="Hawaiian Pizza">
                    <label for="">Hawaiian Pizza</label>
                    <p>Php 299</p>
                    <input class="input" type="number" name="Hawaiian" id="" placeholder="Quantity"><br><br>
                </div>
    
                <div class="Creamy">
                    <img src="./img/Act2/Creamy Spinach.jpg" alt="Creamy Spinach Pizza">
                    <label for="">Creamy Spinach Pizza</label>
                    <p>Php 399</p>
                    <input class="input" type="number" name="Creamy" id="" placeholder="Quantity"><br><br>
                </div>
            </div>

            <div class="box-order">
                <input class="order" type="submit" value="Order">
            </div>
        </form>
        
    </div>
    <!-- PHP Code -->
    <?php

        // Getting the value of each item from the form
        $pepperoni = $_GET["Pepperoni"];
        $hawaiian = $_GET["Hawaiian"];
        $creamy = $_GET["Creamy"];

        // Prices of the items
        $price_of_pepperoni = 199;
        $price_of_hawaiian = 299;
        $price_of_creamy = 399;

        // Declaration of variable
        // Set to null because it will be assigned after input
        $totalPepperoni = null;
        $totalHawaiian = null;
        $totalCreamy = null;

        // Calculation of prices
        $totalPepperoni = $pepperoni * $price_of_pepperoni;
        $totalHawaiian = $hawaiian * $price_of_hawaiian;
        $totalCreamy = $creamy * $price_of_creamy;

        // Calculation of the total price
        $total_price_of_order = $totalPepperoni + $totalHawaiian + $totalCreamy;

        // if-else statement
        // If the item has zero value, the price will not be calculated
        // If the item has value, the price will be calculated and will be printed
        if ($pepperoni == 0) {
            echo "<center>You have ordered {$pepperoni} pepperoni pizza.<br></center>";
        } else {
            echo "<center>You have ordered {$pepperoni} pepperoni and that will be {$totalPepperoni} for pepperoni pizza.<br></center>";
        }
        if ($hawaiian == 0) {
            echo "<center>You have ordered {$hawaiian} hawaiian pizza.<br></center>";
        } else {
            echo "<center>You have ordered {$hawaiian} hawaiian and that will be {$totalHawaiian} for hawaiian pizza.<br></center>";
        }
        if ($creamy == 0) {
            echo "<center>You have ordered {$creamy} creamy spinach pizza.<br></center>";
        } else {
            echo "<center>You have ordered {$creamy} creamy spinach and that will be {$totalCreamy} for creamy spinach pizza.<br></center>";
        }

        // Printing of the total price
        echo "<center>Your total order is: PHP{$total_price_of_order}.</center>";

    ?>

    <!-- About Page -->
    <div>
        <h1 id="about">About</h1>
        <p>Lorem ipsum dolor, sit amet consectetur adipisicing elit. Dolor, ipsum rem harum cupiditate quis necessitatibus deleniti repellendus eaque at pariatur quidem modi reprehenderit ipsa? Consectetur temporibus veniam laudantium repellendus? Fugiat?</p>
        <br><br>
    </div>

    <!-- Script for the Login/Registration Form -->
    <!-- BUG: It cannot display the username -->
    <!-- After clicking the Log in button, the form should be replaced by the username -->
    <script>
        function EchoUser() {
            var user = document.getElementById("username");
            document.getElementById("User").innerHTML = "Hello, " + user.innerHTML + "!";
        }
    </script>
</body>
</html>