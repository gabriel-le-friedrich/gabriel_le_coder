import java.util.Scanner;

public class Average {

    static double CalculateAverage(double[] grades) {
        double total = 0;

        for(double grade : grades) {
            total += grade;
        }

        double avg = total/grades.length;
        
        return avg;
    }

    static double HighestGrade(double[] grades) {
        double highest = grades[0];
        for(double high : grades) {
            if (high > highest) {
                highest = high;
            }
        }
        
        return highest;
    }

    static double LowestGrade(double[] grades) {
        double lowest = grades[0];
        for(double low : grades) {
            if (low < lowest) {
                lowest = low;
            }
        }
        
        return lowest;
    }

    public static void main(String[] args) {
        try(Scanner input = new Scanner(System.in)) {

            System.out.print("Number of students: ");
            int num = input.nextInt();

            double[] grades = new double[num];
            for(int i = 0; i < num; i++) {
                System.out.print("Student " + (i+1) + ": ");
                grades[i] = input.nextDouble();
            }

            System.out.println("Average: " + CalculateAverage(grades));
            System.out.println("Average: " + HighestGrade(grades));
            System.out.println("Average: " + LowestGrade(grades));
        }
    }
}
