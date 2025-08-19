
name = str(input('Name: '))

while name == name:

    grade = int(input('\nEnter Grade: '))

    if grade >= 90 and grade <= 100:
        print('A')
    elif grade >= 80 and grade <= 89:
        print('B')
    elif grade >= 70 and grade <= 79:
        print('C')
    elif grade >= 60 and grade <= 69:
        print('D')
    elif grade >= 0 and grade <= 59:
        print('F')
    else:
        print('Invalid Input!')

    again = input('\nDo you want to enter another grade (y/n): ').lower()

    if again == 'y' or again == 'yes':
        continue
    elif again == 'n' or again == 'no':
        print('Exiting Program...')
        break
    else:
        print('Exiting Program...')
        break
    
