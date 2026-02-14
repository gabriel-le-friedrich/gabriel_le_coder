import tkinter as tk
from tkinter import ttk

root = tk.Tk()
root.title('Sum of 4 Numbers')
root.geometry('560x720')

def get_sum():
    try:
        n1 = float(entry1.get())
        n2 = float(entry2.get())
        n3 = float(entry3.get())
        n4 = float(entry4.get())
        n5 = float(entry5.get())
        n6 = float(entry6.get())

        total = n1 + n2 + n3 + n4 + n5 + n6
        result_label.config(text=f'Ang sum ay: {total}')
    except ValueError:
        result_label.config(text='Please enter valid numbers.')

def get_avg():
    try:
        n1 = float(entry1.get())
        n2 = float(entry2.get())
        n3 = float(entry3.get())
        n4 = float(entry4.get())
        n5 = float(entry5.get())
        n6 = float(entry6.get())

        avg = (n1 + n2 + n3 + n4 + n5 + n6)/6
        result_label.config(text=f'Ang average ay: {avg}')
    except ValueError:
        result_label.config(text='Please enter valid numbers.')

def get_high():
    try:
        n1 = float(entry1.get())
        n2 = float(entry2.get())
        n3 = float(entry3.get())
        n4 = float(entry4.get())
        n5 = float(entry5.get())
        n6 = float(entry6.get())

        high = max(n1, n2, n3, n4, n5, n6)
        result_label.config(text=f'Ang highest ay: {high}')
    except ValueError:
        result_label.config(text='Please enter valid numbers.')
def get_low():
    try:
        n1 = float(entry1.get())
        n2 = float(entry2.get())
        n3 = float(entry3.get())
        n4 = float(entry4.get())
        n5 = float(entry5.get())
        n6 = float(entry6.get())

        low = min(n1, n2, n3, n4, n5, n6)
        result_label.config(text=f'Ang lowest ay: {low}')
    except ValueError:
        result_label.config(text='Please enter valid numbers.')

ttk.Label(root, text='Number 1:').grid(row=0, column=0, sticky='w', padx=12, pady=6)
entry1 = ttk.Entry(root)
entry1.grid(row=0, column=1, sticky='ew', padx=12, pady=6)

ttk.Label(root, text='Number 2:').grid(row=1, column=0, sticky='w', padx=12, pady=6)
entry2 = ttk.Entry(root)
entry2.grid(row=1, column=1, sticky='ew', padx=12, pady=6)

ttk.Label(root, text='Number 3:').grid(row=2, column=0, sticky='w', padx=12, pady=6)
entry3 = ttk.Entry(root)
entry3.grid(row=2, column=1, sticky='ew', padx=12, pady=6)

ttk.Label(root, text='Number 4:').grid(row=3, column=0, sticky='w', padx=12, pady=6)
entry4 = ttk.Entry(root)
entry4.grid(row=3, column=1, sticky='ew', padx=12, pady=6)

ttk.Label(root, text='Number 5:').grid(row=4, column=0, sticky='w', padx=12, pady=6)
entry5 = ttk.Entry(root)
entry5.grid(row=4, column=1, sticky='ew', padx=12, pady=6)

ttk.Label(root, text='Number 6:').grid(row=5, column=0, sticky='w', padx=12, pady=6)
entry6 = ttk.Entry(root)
entry6.grid(row=5, column=1, sticky='ew', padx=12, pady=6)

ttk.Button(root, text='Compute Sum', command=get_sum).grid(row=6, column=1, sticky='w', padx=92, pady=30)
ttk.Button(root, text='Compute Average', command=get_avg).grid(row=7, column=1, sticky='w', padx=92, pady=30)
ttk.Button(root, text='Highest', command=get_high).grid(row=8, column=1, sticky='w', padx=92, pady=30)
ttk.Button(root, text='Lowest', command=get_low).grid(row=9, column=1, sticky='w', padx=92, pady=30)

result_label = ttk.Label(root, text='Number: ')
result_label.grid(row=10, column=0, columnspan=2, sticky='w', padx=12, pady=8)

root.columnconfigure(1, weight=1)
root.mainloop()
