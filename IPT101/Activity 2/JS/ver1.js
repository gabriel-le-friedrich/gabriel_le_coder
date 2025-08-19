/*
Original Script by Sir OJ Liwanag
VERSION 1
// Program to check leap year
function checkLeapYear(year) {
// Three conditions to find out the leap year
if ((year % 4 === 0 && year % 100 !== 0) || year % 400 === 0) {
console.log(year + ' is a leap year');
} else {
console.log(year + ' is not a leap year');
}
}

// Take input
const year = prompt('Enter a year:');
checkLeapYear(year);

*/

// Revised Script by Frederick Gabrielle Cunanan
function checkLeapYear1(year) {
    var year = document.getElementById("year1").value;

    if ((year % 4 === 0 && year % 100 !== 0) || year % 400 === 0) {
        document.getElementById("result1").innerHTML = year + ' is a leap year';
    } else {
        document.getElementById("result1").innerHTML = year + ' is not a leap year';
    }
}

