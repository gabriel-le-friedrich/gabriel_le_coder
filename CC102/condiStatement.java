// condition statement: if else
// comparison operator: >, <, >=, <=, ==

public class condiStatement {
    public static void main(String [] args) {
        
        int grade = 75;

        if (grade >= 75) {
            //System.out.print("Passed");
            
            if (grade > 79) {
                System.out.print("Passed! You got the required retention policy!");
            } else {
                System.out.print("Passed! But you didn't got the requirement for the retention policy!");
            }

        } else {
            System.out.print("Failed");
        }
    }
}
