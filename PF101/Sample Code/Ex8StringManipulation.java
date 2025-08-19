public class Ex8StringManipulation {
    public static void main(String[] args) {
        // Declare and initialize string variables
        String firstName = "Jane";
        String lastName = "Doe";
        
        // Concatenate strings
        String fullName = firstName + " " + lastName;
        
        // Print the full name
        System.out.println("Full Name: " + fullName);
        
        // Get the length of the full name
        int length = fullName.length();
        System.out.println("Length: " + length);
        
        // Convert to uppercase
        String upperCaseName = fullName.toUpperCase();
        System.out.println("Uppercase: " + upperCaseName);
    }
}
