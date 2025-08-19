import java.util.Scanner;

public class problem {
    
    static double avg(double tgrade, double num) {
        
        double avg = tgrade/num;
        
        return avg;
    }
    
    static int total(int num) {
        Scanner input = new Scanner(System.in);
        
        int tgrade = 0;
        
        for(int i = 1; num >= i; i++) {
            System.out.print("Enter number " + i + ": " );
            int grade = input.nextInt();
            
            tgrade += grade;
        }
        return tgrade;
        
    }
    
    
    public static void main(String [] args) {
        Scanner input = new Scanner(System.in);
        
        System.out.print("How many numbers will you enter: ");
        int num = input.nextInt();
        
        int tgrade = total(num);
        
        System.out.println("Total: " + tgrade);
        System.out.println("Average: " + avg(tgrade, num));
        
        
        
        input.close();
    }
}