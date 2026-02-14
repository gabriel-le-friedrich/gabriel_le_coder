import tkinter as tk
from tkinter import ttk

class Calculator:
    def __init__(self, root):
        self.root = root
        self.root.title("Calculator")
        self.root.geometry("400x600")
        self.root.resizable(False, False)
        
        # Variables
        self.current = ""
        self.display_text = tk.StringVar()
        self.display_text.set("0")
        
        # Configure style
        self.root.configure(bg="#2b2b2b")
        self.setup_styles()
        
        # Create display
        self.create_display()
        
        # Create buttons
        self.create_buttons()
    
    def setup_styles(self):
        style = ttk.Style()
        
        # Configure button styles
        style.configure("Number.TButton", 
                       font=("Arial", 20, "bold"),
                       background="#505050",
                       foreground="#ffffff",
                       borderwidth=0,
                       focuscolor="none")
        
        style.configure("Operator.TButton",
                       font=("Arial", 20, "bold"),
                       background="#ff9500",
                       foreground="#ffffff",
                       borderwidth=0,
                       focuscolor="none")
        
        style.configure("Special.TButton",
                       font=("Arial", 20, "bold"),
                       background="#3a3a3a",
                       foreground="#ffffff",
                       borderwidth=0,
                       focuscolor="none")
        
        # Map hover effects
        style.map("Number.TButton",
                 background=[("active", "#666666")])
        style.map("Operator.TButton",
                 background=[("active", "#ffad33")])
        style.map("Special.TButton",
                 background=[("active", "#555555")])
    
    def create_display(self):
        display_frame = ttk.Frame(self.root)
        display_frame.pack(expand=True, fill="both", padx=10, pady=(20, 10))
        
        display = tk.Entry(
            display_frame,
            textvariable=self.display_text,
            font=("Arial", 32, "bold"),
            bg="#1e1e1e",
            fg="#ffffff",
            bd=0,
            justify="right",
            state="readonly",
            readonlybackground="#1e1e1e"
        )
        display.pack(expand=True, fill="both", ipady=20)
    
    def create_buttons(self):
        button_frame = ttk.Frame(self.root)
        button_frame.pack(expand=True, fill="both", padx=10, pady=10)
        
        # Button layout
        buttons = [
            ['C', '⌫', '%', '/'],
            ['7', '8', '9', '*'],
            ['4', '5', '6', '-'],
            ['1', '2', '3', '+'],
            ['±', '0', '.', '=']
        ]
        
        for i, row in enumerate(buttons):
            for j, button_text in enumerate(row):
                # Determine button style
                if button_text in ['/', '*', '-', '+', '=']:
                    style = "Operator.TButton"
                elif button_text in ['C', '⌫', '%', '±']:
                    style = "Special.TButton"
                else:
                    style = "Number.TButton"
                
                btn = ttk.Button(
                    button_frame,
                    text=button_text,
                    style=style,
                    command=lambda x=button_text: self.on_button_click(x),
                    cursor="hand2"
                )
                btn.grid(row=i, column=j, sticky="nsew", padx=2, pady=2)
        
        # Configure grid weights for responsiveness
        for i in range(5):
            button_frame.grid_rowconfigure(i, weight=1)
        for j in range(4):
            button_frame.grid_columnconfigure(j, weight=1)
    
    def on_button_click(self, char):
        if char == 'C':
            self.clear()
        elif char == '⌫':
            self.backspace()
        elif char == '=':
            self.calculate()
        elif char == '±':
            self.toggle_sign()
        elif char in ['+', '-', '*', '/', '%']:
            self.append_operator(char)
        else:
            self.append_number(char)
    
    def clear(self):
        self.current = ""
        self.display_text.set("0")
    
    def backspace(self):
        if self.current:
            self.current = self.current[:-1]
            self.display_text.set(self.current if self.current else "0")
    
    def append_number(self, num):
        if self.current == "0" and num != ".":
            self.current = num
        elif num == "." and "." in self.current.split()[-1]:
            return  # Don't allow multiple decimals in one number
        else:
            self.current += num
        self.display_text.set(self.current)
    
    def append_operator(self, op):
        if self.current and self.current[-1] not in ['+', '-', '*', '/', '%']:
            self.current += f" {op} "
            self.display_text.set(self.current)
    
    def toggle_sign(self):
        if self.current:
            try:
                # Get the last number in the expression
                parts = self.current.split()
                if parts:
                    last_num = parts[-1]
                    if last_num.replace('.', '').replace('-', '').isdigit():
                        if last_num.startswith('-'):
                            parts[-1] = last_num[1:]
                        else:
                            parts[-1] = '-' + last_num
                        self.current = ' '.join(parts)
                        self.display_text.set(self.current)
            except:
                pass
    
    def calculate(self):
        if self.current:
            try:
                result = eval(self.current)
                # Format result to avoid floating point issues
                if isinstance(result, float):
                    if result.is_integer():
                        result = int(result)
                    else:
                        result = round(result, 10)
                self.current = str(result)
                self.display_text.set(self.current)
            except ZeroDivisionError:
                self.display_text.set("Error: Div by 0")
                self.current = ""
            except:
                self.display_text.set("Error")
                self.current = ""

def main():
    root = tk.Tk()
    calculator = Calculator(root)
    root.mainloop()

if __name__ == "__main__":
    main()

