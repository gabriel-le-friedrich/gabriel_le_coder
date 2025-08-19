public class Act1 {
    public static void main(String[] args) {
        Double subject1, subject2, subject3, average;

        subject1 = 85.5;
        subject2 = 90.0;
        subject3 = 78.0;

        average = (subject1 + subject2 + subject3)/3;

        if (average >= 75) {
            System.out.println("Passed!");
        } else {
            System.out.println("Failed!");
        }
    }
}
