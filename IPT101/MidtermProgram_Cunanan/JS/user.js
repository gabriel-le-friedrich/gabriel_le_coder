// Looping Name Validation
let isNameValid = false;
let user;

while (!isNameValid) {
    // Ask the User's Name
    user = prompt("Input your name:","");

    // If the user clicked the cancel button on the prompt
    if (user === null) {
        alert("Please enter your name. Clicking Cancel is not allowed.");
        continue;
    }

    // Trimming the input
    user = user.trim();

    // Input Validation
    if (!user) {
        alert("Please enter a name.");
    } else if (user.length < 2) {
        alert("Name is too short.");
    } else if (/[0-9]/.test(user)) {
        alert("Name shouldn't contain numbers.");
    } else {
        isNameValid = true;
    }
}

document.getElementById("Greetings").innerHTML = "Welcome, " + user + "!";