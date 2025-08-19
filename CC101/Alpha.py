print('Hello, I am Alpha.py!')
print('I am a Python Program created by Mr. Frederick Gabrielle F. Cunanan.')
name = input('And you are? ')

print('Hello, ' + name + '!')
p = input('To unlock my commands.\nPlease enter the password: ')

while p == str('pass'):
    if p == str('pass'):
        print('\nHere are my commands!')
        print('(1) Calculator')
        print('(0) Exit')

        cmd = int(input('\nEnter your command: '))

        if cmd == 1:

            print('Welcome to Calculator!')
            num1 = float(input('First Value: '))
            op = input('Operator (+, -, *, /): ')
            num2 = float(input('Second Value: '))
        
        elif cmd == 0:
            print('Goodbye!')
            break
        else:
            print('Unrecognizable Command!\n')
    else:
        print('Incorrect Password!')