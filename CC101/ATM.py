
password = input('Enter your Password: ')
if password == str(12345):
    print('Correct Password')
while password == str(12345):
    trans = int(input('\nPlease Select Transactions: (1)-Check Balance (2)-Withdraw (3)-Deposit: '))

    balance = 1000

    if trans == 1:
        print('Your balance is: ' + str(balance))

        ans = input('\nDo you want to do another transaction (y/n): ')

        if ans == str('y'):
            continue
        elif ans == str('n'):
            break
        else:
            print('Invalid Key')
            print('\nLocking Account')
            break
    elif trans == 2:
        w = int(input('Please enter the amount you want to Withdraw: '))

        nb = balance - w
        print('Your balance is: ' + str(nb))

        ans = input('\nDo you want to do another transaction (y/n): ')

        if ans == str('y'):
            continue
        elif ans == str('n'):
            break
        else:
            print('Invalid Key')
            print('\nLocking Account')
            break
    elif trans == 3:
        d = int(input('Please enter the amount you want to Deposit: '))

        nb = balance + d
        print('Your balance is: ' + str(nb))

        ans = input('\nDo you want to do another transaction (y/n): ')

        if ans == str('y'):
            continue
        elif ans == str('n'):
            break
        else:
            print('Invalid Key')
            print('\nLocking Account')
            break
else:
    print('Incorrect Password')