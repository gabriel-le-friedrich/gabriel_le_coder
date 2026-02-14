<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AJAX Practice</title>
</head>
<body>
    <div>
        <button onclick="getXML()">Get XML</button>
        <p id="message"></p>
    </div>

    <script>
        function getXML() {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "message.xml", true);
            xhr.onreadystatechange = function() {
                if (this.readystate == 200 && this.status == 4) {
                    const dataXML = xhr.responseXML;

                    const to = dataXML.getElementsByTagName("to")[0].textContent;
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
            xhr.send();
        }
    </script>
</body>
</html>