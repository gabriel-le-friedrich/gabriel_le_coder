public class Assignment1 {
    public static void main(String[] args) {
        Values val = new Values();
        double num1 = val.value1();
        double num2 = val.value2();
        // Calculate and display result
        double sum =  num1 + num2;
        System.out.println("The sum is " + sum);
    }
}