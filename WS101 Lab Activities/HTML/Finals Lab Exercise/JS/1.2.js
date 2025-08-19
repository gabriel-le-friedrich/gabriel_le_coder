function Multiplication() {
    let num1 = document.getElementById('num1').value;
    let num2 = document.getElementById('num2').value;
    
    result = parseInt(num1) * parseInt(num2);
    document.getElementById('res').innerHTML = result;
}

function Division() {
    let num1 = document.getElementById('num1').value;
    let num2 = document.getElementById('num2').value;
    
    result = parseInt(num1) / parseInt(num2);
    document.getElementById('res').innerHTML = result;
}