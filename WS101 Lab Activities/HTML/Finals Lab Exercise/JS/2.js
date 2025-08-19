function Addition() {
    let num1 = document.getElementById('num1').value;
    let num2 = document.getElementById('num2').value;
    
    result = parseFloat(num1) + parseFloat(num2);
    document.getElementById('res').innerHTML = result.toFixed(2);
}

function Subtraction() {
    let num1 = document.getElementById('num1').value;
    let num2 = document.getElementById('num2').value;
    
    result = parseFloat(num1) - parseFloat(num2);
    document.getElementById('res').innerHTML = result.toFixed(2);
}

function Multiplication() {
    let num1 = document.getElementById('num1').value;
    let num2 = document.getElementById('num2').value;
    
    result = parseFloat(num1) * parseFloat(num2);
    document.getElementById('res').innerHTML = result.toFixed(2);
}

function Division() {
    let num1 = document.getElementById('num1').value;
    let num2 = document.getElementById('num2').value;
    
    result = parseFloat(num1) / parseFloat(num2);
    document.getElementById('res').innerHTML = result.toFixed(2);
}

function Clear() {
    document.getElementById('num1').value = "";
    document.getElementById('num2').value = "";
    document.getElementById('res').innerHTML= "";

}

function About() {
    document.getElementById('num1').value = "";
    document.getElementById('num2').value = "";
    document.getElementById('res').innerHTML = "Work of Frederick Gabrielle Cunanan!";
}