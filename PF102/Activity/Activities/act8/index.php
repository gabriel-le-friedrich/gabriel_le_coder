<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AJAX XML Data Loader</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }

        .container {
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            max-width: 700px;
            width: 100%;
            padding: 40px;
        }

        h1 {
            color: #333;
            margin-bottom: 15px;
            font-size: 2em;
            text-align: center;
        }

        .description {
            color: #666;
            margin-bottom: 30px;
            text-align: center;
            line-height: 1.6;
        }

        .button-container {
            text-align: center;
            margin-bottom: 30px;
        }

        #loadBtn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 15px 40px;
            font-size: 16px;
            border-radius: 50px;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
        }

        #loadBtn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(102, 126, 234, 0.6);
        }

        #loadBtn:active {
            transform: translateY(0);
        }

        #xmlData {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 25px;
            min-height: 100px;
            border: 2px dashed #ddd;
            transition: all 0.3s ease;
        }

        #xmlData.loaded {
            border: 2px solid #667eea;
            background: #f0f4ff;
        }

        .xml-content {
            animation: fadeIn 0.5s ease-in;
        }

        @keyframes fadeIn {
            from {
                opacity: 0;
                transform: translateY(10px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        .message-field {
            margin-bottom: 15px;
        }

        .message-field label {
            font-weight: bold;
            color: #667eea;
            display: block;
            margin-bottom: 5px;
        }

        .message-field .content {
            color: #333;
            line-height: 1.6;
        }

        .placeholder {
            color: #999;
            text-align: center;
            font-style: italic;
        }

        .error {
            color: #e74c3c;
            text-align: center;
            font-weight: bold;
        }

        .loading {
            text-align: center;
            color: #667eea;
        }

        .loading::after {
            content: '...';
            animation: dots 1.5s steps(4, end) infinite;
        }

        @keyframes dots {
            0%, 20% { content: '.'; }
            40% { content: '..'; }
            60%, 100% { content: '...'; }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📧 AJAX XML Data Loader</h1>
        <p class="description">
            This application demonstrates how to use AJAX (Asynchronous JavaScript and XML) 
            to load and display XML data dynamically without refreshing the page. 
            Click the button below to load message data from an XML file.
        </p>

        <div class="button-container">
            <button id="loadBtn" onclick="loadXMLData()">Load XML Data</button>
        </div>

        <div id="xmlData">
            <p class="placeholder">Click the button above to load XML data...</p>
        </div>
    </div>

    <script>
        function loadXMLData() {
            // Step 1: Create XMLHttpRequest object
            const xhr = new XMLHttpRequest();
            
            // Show loading message
            document.getElementById('xmlData').innerHTML = '<p class="loading">Loading XML data</p>';
            
            // Step 2: Configure the request
            xhr.open('GET', 'data.xml', true);
            
            // Step 3: Set up the callback function
            xhr.onreadystatechange = function() {
                // Check if request is complete and successful
                if (xhr.readyState === 4) {
                    if (xhr.status === 200) {
                        // Step 4: Parse the XML response
                        const xmlDoc = xhr.responseXML;
                        
                        // Step 5: Extract data from XML elements
                        const to = xmlDoc.getElementsByTagName('to')[0].childNodes[0].nodeValue;
                        const from = xmlDoc.getElementsByTagName('from')[0].childNodes[0].nodeValue;
                        const heading = xmlDoc.getElementsByTagName('heading')[0].childNodes[0].nodeValue;
                        const body = xmlDoc.getElementsByTagName('body')[0].childNodes[0].nodeValue;
                        
                        // Step 6: Display the extracted data
                        const outputDiv = document.getElementById('xmlData');
                        outputDiv.className = 'loaded';
                        outputDiv.innerHTML = `
                            <div class="xml-content">
                                <div class="message-field">
                                    <label>To:</label>
                                    <div class="content">${to}</div>
                                </div>
                                <div class="message-field">
                                    <label>From:</label>
                                    <div class="content">${from}</div>
                                </div>
                                <div class="message-field">
                                    <label>Subject:</label>
                                    <div class="content">${heading}</div>
                                </div>
                                <div class="message-field">
                                    <label>Message:</label>
                                    <div class="content">${body}</div>
                                </div>
                            </div>
                        `;
                    } else {
                        // Handle error
                        document.getElementById('xmlData').innerHTML = 
                            '<p class="error">Error loading XML data. Please make sure the file exists and the server is running.</p>';
                    }
                }
            };
            
            // Step 7: Send the request
            xhr.send();
        }
    </script>
</body>
</html>