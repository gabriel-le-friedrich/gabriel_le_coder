function checkLeapYear2() {
    // Parse the input and validate
    const yearInput = document.getElementById("year2");
    const year = parseInt(yearInput.value.trim(), 10);
    const resultElement = document.getElementById("result2");

    // Validate input
    if (isNaN(year) || year < 0) {
        resultElement.textContent = 'Please enter a valid positive year';
        resultElement.classList.add('error');
        return;
    }

    // Leap year calculation using Date method
    const leap = new Date(year, 1, 29).getDate() === 29;
    
    // Update result with appropriate message
    resultElement.textContent = leap 
        ? `${year} is a leap year` 
        : `${year} is not a leap year`;
    
    // Remove any error class
    resultElement.classList.remove('error');
}
