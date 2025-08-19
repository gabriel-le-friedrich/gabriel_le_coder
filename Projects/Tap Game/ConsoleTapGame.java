import java.util.Scanner;
import java.util.Timer;
import java.util.TimerTask;

public class ConsoleTapGame {
    private static int score = 0;
    private static boolean gameRunning = false;
    private static final int GAME_DURATION = 10; // 10 seconds

    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        System.out.println("Welcome to Console Tap Game!");
        System.out.println("Press Enter as many times as you can in " + GAME_DURATION + " seconds.");
        System.out.println("Press Enter to start the game...");
        scanner.nextLine(); // Wait for user to press Enter

        startGame();

        while (gameRunning) {
            if (scanner.hasNextLine()) {
                scanner.nextLine(); // Consume the Enter key press
                score++;
                System.out.println("Score: " + score);
            }
        }

        System.out.println("Game Over! Your final score is: " + score);
        scanner.close();
    }

    private static void startGame() {
        gameRunning = true;
        score = 0;

        Timer timer = new Timer();
        timer.schedule(new TimerTask() {
            int timeLeft = GAME_DURATION;

            @Override
            public void run() {
                if (timeLeft > 0) {
                    System.out.println("Time left: " + timeLeft + " seconds");
                    timeLeft--;
                } else {
                    gameRunning = false;
                    timer.cancel();
                }
            }
        }, 0, 1000); // Run every second
    }
}
