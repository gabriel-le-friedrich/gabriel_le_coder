
def counting_sort(arr):
  n = len(arr)
  max_element = max(arr)
  count = [0] * (max_element + 1)
  for i in range(n):
    count[arr[i]] += 1
  for i in range(1, max_element + 1):
    count[i] += count[i - 1]
  output = [0] * n
  for i in range(n - 1, -1, -1):
    output[count[arr[i]] - 1] = arr[i]
    count[arr[i]] -= 1
  return output

arr = [2, 1, 5, 8, 4, 6]
print("Unsorted Lists: ", arr)
print("Sorted Lists: ", counting_sort(arr))


