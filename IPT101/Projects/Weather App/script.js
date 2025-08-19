document.getElementById('getWeatherBtn').addEventListener('click', getWeather);

function getWeather() {
    const location = document.getElementById('locationInput').value;
    if (location === '') {
        alert('Please enter a city name');
        return;
    }

    const apiKey = '69654aea926c7294e931bb7ac92ed450'; // Replace with your API Key
    const url = `https://api.openweathermap.org/data/2.5/weather?q=${location}&units=metric&appid=${apiKey}`;

    fetch(url)
        .then(response => response.json())
        .then(data => displayWeather(data))
        .catch(error => console.error('Error:', error));
}

function displayWeather(weatherData) {
    const weatherElement = document.getElementById('weatherData');
    weatherElement.innerHTML = `
        <h2>Weather in ${weatherData.name}</h2>
        <p><strong>Temperature:</strong> ${weatherData.main.temp}°C</p>
        <p><strong>Feels Like:</strong> ${weatherData.main.feels_like}°C</p>
        <p><strong>Humidity:</strong> ${weatherData.main.humidity}%</p>
        <p><strong>Weather Condition:</strong> ${weatherData.weather[0].description}</p>
    `;
}
