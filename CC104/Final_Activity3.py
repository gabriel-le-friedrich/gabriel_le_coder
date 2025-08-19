
stack = []

stack.append(5)
stack.append(10)
stack.append(15)

print(stack.pop())
print(stack.pop())
print(stack.pop())

from collections import deque

queue = deque()

queue.append('A')
queue.append('B')
queue.append('C')

print(queue.popleft())
print(queue.popleft())
print(queue.popleft())


def linear_search(arr, target):
    for i in range(len(arr)):
        if arr[i] == target:
            return i

    return -1

arr = [48, 50, 52, 8, 20, 5, 8, 8]
print(linear_search(arr, 8))
