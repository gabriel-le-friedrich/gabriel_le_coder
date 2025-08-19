function checkLeapYear1() {
    // Parse the input and validate
    const yearInput = document.getElementById("year1");
    const year = parseInt(yearInput.value.trim(), 10);
    const resultElement = document.getElementById("result1");

    // Validate input
    if (isNaN(year) || year < 0) {
        resultElement.textContent = 'Please enter a valid positive year';
        resultElement.classList.add('error');
        return;
    }

    // Leap year calculation
    const isLeapYear = (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
    
    // Update result with appropriate message
    resultElement.textContent = isLeapYear 
        ? `${year} is a leap year` 
        : `${year} is not a leap year`;
    
    // Remove any error class
    resultElement.classList.remove('error');
}
