# Coded by gabriel_le_friedrich

# Import Libraries
import tkinter as tk
from tkinter import ttk

root = tk.Tk() # Object
root.title('My Calculator') # Window Title
root.geometry('250x250') # Window Size

# Calculation Function
def calc(op):
    try:
        # Value Entry
        n1 = float(entry1.get())
        n2 = float(entry2.get())

        # Arithmetic Operation Condition
        if op == 'add':
            total = n1 + n2
            result_label.config(text=f'Sum: {total}')
        elif op == 'sub':
            dif = n1 - n2
            result_label.config(text=f'Difference: {dif}')
        elif op == 'mul':
            pro = n1 * n2
            result_label.config(text=f'Product: {pro}')
        elif op == 'div':
            quo = n1 / n2
            result_label.config(text=f'Quotient: {quo}')
        elif op == 'whole':
            whole = n1 // n2
            result_label.config(text=f'Whole: {whole}')
        elif op == 'rem':
            rem = n1 % n2
            result_label.config(text=f'Remainder: {rem}')
        elif op == 'exp':
            exp = n1 ** n2
            result_label.config(text=f'Exponent: {exp}')
        elif op == 'clear':
            result_label.config(text=f'Result: ')
    except ValueError: # Error for invalid input/entry
        result_label.config(text='Please enter valid numbers.')
    except ZeroDivisionError: # Error for dividing numbers with zero
        result_label.config(text='Error: Division by zero!')

# Widgets
## Result Display
result_label = ttk.Label(root, text='Result: ')
result_label.grid(row=0, column=0, columnspan=2, sticky='w', padx=12, pady=8)

## Input Fields
ttk.Label(root, text='Number 1:').grid(row=1, column=0, sticky='w', padx=12, pady=6)
entry1 = ttk.Entry(root)
entry1.grid(row=1, column=1, sticky='ew', padx=12, pady=6)

ttk.Label(root, text='Number 2:').grid(row=2, column=0, sticky='w', padx=12, pady=6)
entry2 = ttk.Entry(root)
entry2.grid(row=2, column=1, sticky='ew', padx=12, pady=6)

# Operation Buttons
ttk.Button(root, text='+', command=lambda: calc('add')).grid(row=3, column=0)
ttk.Button(root, text='-', command=lambda: calc('sub')).grid(row=3, column=1)
ttk.Button(root, text='*', command=lambda: calc('mul')).grid(row=4, column=0)
ttk.Button(root, text='/', command=lambda: calc('div')).grid(row=4, column=1)
ttk.Button(root, text='//', command=lambda: calc('whole')).grid(row=5, column=0)
ttk.Button(root, text='%', command=lambda: calc('rem')).grid(row=5, column=1)
ttk.Button(root, text='**', command=lambda: calc('exp')).grid(row=6, column=0)
ttk.Button(root, text='C', command=lambda: calc('clear')).grid(row=6, column=1)

# Column Configuration
root.columnconfigure(1, weight=1)

root.mainloop()
