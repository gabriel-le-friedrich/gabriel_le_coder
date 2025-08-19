
import random

def guessing_game():
    number_to_guess = random.randint(1, 100)
    attempts = 0

    print("Welcome to the Number Guessing Game!")
    print("I'm thinking of a number between 1 and 100. Can you guess what it is?")

    while True:
        guess = int(input("Enter your guess: "))
        attempts += 1

        if guess < number_to_guess:
            print("Too low!")
        elif guess > number_to_guess:
            print("Too high!")
        else:
            print(f"Congratulations! You guessed it in {attempts} attempts.")
            break

    if attempts >= 10:
        print(f"Sorry, you've run out of guesses. The number was {number_to_guess}.")

guessing_game()
