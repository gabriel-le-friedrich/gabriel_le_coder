function numDeterminer() {
    let num = document.getElementById('num').value;
    let rem = (num % 2);

    if (rem == 0) {
        if (num > 0) {
            document.getElementById('ES5').innerHTML = num + " is even and positive";
        } else if (num == 0) {
            document.getElementById('ES5').innerHTML = num + " is even";
        } else {
            document.getElementById('ES5').innerHTML = num + " is even and negative";
        }
    } else {
        if (num > 0) {
            document.getElementById('ES5').innerHTML = num + " is odd and positive";
        } else {
            document.getElementById('ES5').innerHTML = num + " is odd and negative";
        }
    }
}

const numDeterminer2 = () => {
    let num1 = document.getElementById('num').value;
    let rem1 = (num1 % 2);

    if (rem1 == 0) {
        if (num1 > 0) {
            document.getElementById('ES6').innerHTML = (`${num1} is even and positive`);
        } else if (num1 == 0) {
            document.getElementById('ES6').innerHTML = (`${num1} is even`);
        } else {
            document.getElementById('ES6').innerHTML = (`${num1} is even and negative`);
        }
    } else {
        if (num1 > 0) {
            document.getElementById('ES6').innerHTML = (`${num1} is odd and positive`);
        } else {
            document.getElementById('ES6').innerHTML = (`${num1} is odd and negative`);
        }
    }
}