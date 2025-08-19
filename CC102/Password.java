import java.util.Scanner;

public class Password {
    public static void main(String []args) {
        try (Scanner input = new Scanner(System.in)) {
            
            System.out.print("Enter your First Name: ");
            String Fn = input.next();

            if (Fn.contains("Frederick")) {

                System.out.print("Enter your Second Name: ");
                String Sn = input.next();

                if (Sn.contains("Gabrielle")) {

                    System.out.print("Enter your Middle Name: ");
                    String Mn = input.next();

                    if (Mn.contains("Fegarido")) {

                        System.out.print("Enter your Last Name: ");
                        String Ln = input.next();

                        if (Ln.contains("Cunanan")) {
                            System.out.println("Access Granted!");
                            System.out.println("Welcome, Master " + Fn + " " + Sn + " " + Ln + "!");

                        } else {
                            System.out.print("Access Denied!");
                        }

                    } else {
                        System.out.print("Access Denied!");
                    }

                } else {
                    System.out.print("Access Denied!");
                }

            } else {
                System.out.print("Access Denied!");
            }
        }
    }
}




