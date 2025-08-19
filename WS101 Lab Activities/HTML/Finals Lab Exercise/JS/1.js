function GetName() {
    let name = document.getElementById('name').value;
    document.getElementById('msg').innerHTML = "Welcome to the site " + name + "!";
}