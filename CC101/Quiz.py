name = input('Name: ')
g1 = float(input('Math Grade: '))
g2 = float(input('Science Grade: '))
g3 = int(input('English Grade: '))
g4 = float(input('CC101: '))

avg = (g1 + g2 + g3 + g4)/4

if avg >= 75:
    print('Status: Passed!')
else:
    print('Status: Failed!')