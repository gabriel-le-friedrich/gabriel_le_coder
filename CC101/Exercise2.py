avg = int(input('Average: '))

if avg > 100:
    print('Excessive Grade! Invalid!')
elif avg >= 98 and avg <= 100:
    print('Grade: 1.00')
elif avg >= 90 and avg <= 97:
    print('Grade: 1.50')
elif avg >= 85 and avg <= 89:
    print('Grade: 2.00')
elif avg >= 80 and avg <= 84:
    print('Grade: 2.50')
elif avg >= 75 and avg <= 79:
    print('Grade: 3.00')
elif avg >= 70 and avg <= 74:
    print('Grade: 5.00')
else:
    print('Insufficient Grade! Invalid!')