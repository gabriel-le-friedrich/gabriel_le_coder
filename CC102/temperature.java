import java.util.Scanner;

public class temperature{
	public static void main(String[] Args){
        try (Scanner input = new Scanner (System.in)){
        
        System.out.print("Enter your current Body Temperature:");
        double temperature = input.nextDouble ();
        
            if (temperature < 30) {
                System.out.println("Your temperature is lower than 30°C, It is not normal.");
            } else {
                if (temperature >= 38) {
                    System.out.println("You have a fever. Please take a rest and consult a doctor.");
                } else {
                    System.out.println("Your temperature is normal.");
                }
            }
        }
	}	
}