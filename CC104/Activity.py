
#ask the name of the user
name = input('Input name: ')
if name == str(name):
    print('Hello, ' + name + '!')

#a while loop to loop the activity if the user wants to use another command
while name == str(name):
    print('\n(1) Positive, Negative or Zero')
    print('(2) Even or Odd')
    print('(3) Print Numbers')
    print('(4) Guessing Game')
    print('(5) Exit')
    cmd = int(input('Command: '))
    
    #if the user input 1
    if cmd == 1:
        print('\nPositive, Negative or Zero')
        number = int(input('Enter a number: '))
        
        if number < 0:
            print('Negative')
        elif number > 0:
            print('Positive!')
        else:
            print('Zero! ')
            
    #if the user input 2
    elif cmd == 2:
        print('\nEven or Odd')
        number = int(input('Enter a number: '))
        
        if number == 0:
            print('Zero!')
        elif number % 2 == 0:
            print('Even!')
        else:
            print('Odd! ')
            
    #if the user input 3
    elif cmd == 3:
        print('\nPrint Numbers')
        number = int(input('Enter a number: '))
        print(f'Numbers from 1 to {number}: \n')
        
        for i in range(1, number+1):
            print(i)
    
    #if the user input 4
    elif cmd == 4:
        print('\nGuessing Game')
        secret_number = 7
        guess = None

        while guess != secret_number:
            guess = int(input('Guess the secret number (1-10): '))

            if guess < secret_number:
                print('Too low!')
            elif guess > secret_number:
                print('Too high!')
            else:
                print('You got it!')
    
    #if the user input 5, it will exit the program
    elif cmd == 5:
        print('\nGoodbye, ' + name + '!')
        break
    
    #if the user input is not from the given commands
    else:
        print('Incorrect Command!')

    #the program will ask the user to choose another command
    again = input('\nDo you want another command (yes/no): ').lower()
    if again == 'yes' or again == 'y':
        continue
    elif again == 'no' or again == 'n':
        print('\nGoodbye, ' + name + '!')
        break
    else:
        print('\nGoodbye, ' + name + '!')
        break

#if the users input is incorrect
else:
    print('\nIncorrect Input!')


