public class Assignment2 {
    public static void main(String[] args) {
        Values2 val = new Values2();
        // Get values once and store them
        double num1 = val.value1();
        double num2 = val.value2();
        
        // Calculate and display result using stored values
        double sum = num1 + num2;
        System.out.println("The sum is " + sum);
    }
}
