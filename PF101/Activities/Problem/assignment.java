public class assignment {
    public static void main(String[] args) {
        value val = new value();
        double first_value = val.value1();
        double second_value = val.value2();
        
        double sum = first_value + second_value;
        System.out.println("The sum of " + first_value + " and " + second_value + " is " + sum);
    }
}