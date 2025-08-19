let displayValue = '0';
let pendingOperation = null;
let storedValue = null;
let lastResult = null;
let waitingForSecondOperand = false;

function updateDisplay() {
    document.getElementById('display').textContent = displayValue;
}

function clearDisplay() {
    displayValue = '0';
    pendingOperation = null;
    storedValue = null;
    lastResult = null;
    waitingForSecondOperand = false;
    updateDisplay();
}

function backspace() {
    if (displayValue.length > 1) {
        displayValue = displayValue.slice(0, -1);
    } else {
        displayValue = '0';
    }
    updateDisplay();
}

function addToDisplay(value) {
    if (waitingForSecondOperand) {
        displayValue = value;
        waitingForSecondOperand = false;
    } else {
        if (displayValue === '0' && value !== '.') {
            displayValue = value;
        } else {
            displayValue += value;
        }
    }
    updateDisplay();
}

function evaluateExpression() {
    try {
        if (pendingOperation === 'powY') {
            // Handle the x^y operation
            let exponent = parseFloat(displayValue);
            let result = Math.pow(storedValue, exponent);
            displayValue = result.toString();
            pendingOperation = null;
            storedValue = null;
            updateDisplay();
            return;
        }
        
        // Handle other expressions
        let expression = displayValue.replace(/×/g, '*');
        expression = expression.replace(/π/g, Math.PI);
        expression = expression.replace(/e/g, Math.E);
        
        lastResult = eval(expression);
        displayValue = lastResult.toString();
        updateDisplay();
    } catch (error) {
        displayValue = 'Error';
        updateDisplay();
        setTimeout(clearDisplay, 1500);
    }
}

function factorial(n) {
    if (n === 0 || n === 1) {
        return 1;
    }
    let result = 1;
    for (let i = 2; i <= n; i++) {
        result *= i;
    }
    return result;
}

function calculate(operation) {
    try {
        let value = parseFloat(displayValue);
        let result;
        
        switch (operation) {
            case 'sin':
                result = Math.sin(value);
                break;
            case 'cos':
                result = Math.cos(value);
                break;
            case 'tan':
                result = Math.tan(value);
                break;
            case 'sqrt':
                result = Math.sqrt(value);
                break;
            case 'log':
                result = Math.log10(value);
                break;
            case 'ln':
                result = Math.log(value);
                break;
            case 'pi':
                result = Math.PI;
                break;
            case 'e':
                result = Math.E;
                break;
            case 'pow2':
                result = Math.pow(value, 2);
                break;
            case 'pow3':
                result = Math.pow(value, 3);
                break;
            case 'powY':
                storedValue = value;
                pendingOperation = 'powY';
                waitingForSecondOperand = true;
                return;
            case 'fact':
                if (value < 0 || !Number.isInteger(value)) {
                    throw new Error("Factorial only defined for non-negative integers");
                }
                result = factorial(value);
                break;
            default:
                result = value;
        }
        
        displayValue = result.toString();
        updateDisplay();
    } catch (error) {
        displayValue = 'Error';
        updateDisplay();
        setTimeout(clearDisplay, 1500);
    }
}