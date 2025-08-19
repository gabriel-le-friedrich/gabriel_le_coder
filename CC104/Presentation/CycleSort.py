
def cycle_sort(arr):
  n = len(arr)
  for i in range(n):
    item = arr[i]
    pos = i
    while pos < n and arr[pos] != item:
      pos += 1
    if pos != i:
      while arr[pos] != item:
        arr[pos], item = item, arr[pos]
        pos += 1
      arr[pos] = item
  return arr

arr = [2, 1, 5, 8, 4, 6]
print("Unsorted Lists: ", arr)
print("Sorted Lists: ", cycle_sort(arr))


