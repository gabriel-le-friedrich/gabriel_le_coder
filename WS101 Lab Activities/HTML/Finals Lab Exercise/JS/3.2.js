const tipCalculator = (sum, percentage, currency, prefix) => {
    let tip = (sum*(percentage/100)); 
    let total = sum + tip;
    
    if (prefix == true) {
        console.log(`
        Sum before tip: ${sum}${currency}
        Tip percentage: ${percentage}%
        Tip:            ${tip.toFixed(2)}${currency}
        Total:          ${total.toFixed(2)}${currency}
        `)
    } else {
        console.log(`
        Sum before tip: ${currency}${sum}
        Tip percentage: ${percentage}%
        Tip:            ${currency}${tip.toFixed(2)}
        Total:          ${currency}${total.toFixed(2)}
        `)
    }
    
    
}

tipCalculator(29.95, 18, "$", false);
tipCalculator(29.95, 18, "Php", true);