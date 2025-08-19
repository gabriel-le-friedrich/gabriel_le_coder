/*
Original Script by Sir OJ Liwanag
VERSION 2
// Program to check leap year
function checkLeapYear(year) {
const leap = new Date(year, 1, 29).getDate() === 29;
if (leap) {
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
function checkLeapYear2(year) {
    var year = document.getElementById("year2").value;

    const leap = new Date(year, 1, 29).getDate() === 29;
    if (leap) {
        document.getElementById("result2").innerHTML = year + ' is a leap year';
    } else {
        document.getElementById("result2").innerHTML = year + ' is not a leap year';
    }
}

