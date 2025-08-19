function toggleTheme(value) 
{
    // Obtain the name of stylesheet
    // as a parameter and set it
    // using href attribute.
    var sheets = document
        .getElementsByTagName('link');
        sheets[0].href = value;
}
/*Note: The corresponding CSS files with required names 
should be available and the path to them should be passed 
using the function. The files specified here are placed in the 
same folder of the HTML file so that the path resembles ‘light.css’.*/