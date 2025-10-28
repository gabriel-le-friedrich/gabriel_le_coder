<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AJAX_Lab8</title>
</head>
<body>
    <div>
        <h1>
            Implementing AJAX and XML
        </h1>
        <p id="description">
            This is a website for implementing AJAX and XML
        </p>
    </div>
    <div>
        <button onclick="getXML()">Load XML Data</button>
        <p id="message">

        </p>

        <script>
            function getXML() {
                var xhttp = new XMLHttpRequest();
                xhttp.open("GET", "data.xml", true);
                xhttp.onreadystatechange = function() {
                    if (this.readyState == 4 && this.status == 200) {
                        const dataXML = xhttp.responseXML;

                        const to = dataXML.getElementsByTagName("to")[0].childNodes[0].nodeValue;
                        const from = dataXML.getElementsByTagName("from")[0].textContent;
                        const heading = dataXML.getElementsByTagName("heading")[0].textContent;
                        const body = dataXML.getElementsByTagName("body")[0].textContent;

                        const output = document.getElementById("message");
                        output.innerHTML = 
                        `
                            <div>
                                <p>To: ${to} </p>
                            </div>
                            <div>
                                <p>From: ${from} </p>
                            </div>
                            <div>
                                <p>Heading: ${heading} </p>
                            </div>
                            <div>
                                <p>Message: ${body} </p>
                            </div>
                        `;
                    }
                };
                
                xhttp.send();
            }
        </script>
    </div>
</body>
</html>