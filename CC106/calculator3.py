import tkinter as tk
from tkinter import font

class Calculator:
    def __init__(self, root):
        self.root = root
        self.root.title("Calculator")
        self.root.geometry("400x550")
        self.root.resizable(False, False)
        self.root.configure(bg='#2b2b2b')
        
        # Variables
        self.current_value = ""
        self.display_value = tk.StringVar()
        self.display_value.set("0")
        
        # Create UI
        self.create_display()
        self.create_buttons()
        
    def create_display(self):
        """Create the calculator display"""
        display_frame = tk.Frame(self.root, bg='#2b2b2b')
        display_frame.pack(pady=20, padx=20)
        
        display_font = font.Font(family='Arial', size=32, weight='bold')
        display = tk.Entry(
            display_frame,
            textvariable=self.display_value,
            font=display_font,
            justify='right',
            bd=0,
            bg='#3d3d3d',
            fg='white',
            insertbackground='white',
            state='readonly',
            readonlybackground='#3d3d3d'
        )
        display.pack(ipady=20, ipadx=10, fill='both')
        
    def create_buttons(self):
        """Create calculator buttons"""
        button_frame = tk.Frame(self.root, bg='#2b2b2b')
        button_frame.pack(pady=10, padx=20)
        
        button_font = font.Font(family='Arial', size=18, weight='bold')
        
        # Button layout
        buttons = [
            ['C', '⌫', '%', '/'],
            ['7', '8', '9', '*'],
            ['4', '5', '6', '-'],
            ['1', '2', '3', '+'],
            ['±', '0', '.', '=']
        ]
        
        # Color schemes
        number_color = '#4a4a4a'
        operator_color = '#ff9500'
        special_color = '#5a5a5a'
        
        for row_idx, row in enumerate(buttons):
            for col_idx, button_text in enumerate(row):
                # Determine button color
                if button_text in ['/', '*', '-', '+', '=']:
                    bg_color = operator_color
                    fg_color = 'white'
                elif button_text in ['C', '⌫', '%', '±']:
                    bg_color = special_color
                    fg_color = 'white'
                else:
                    bg_color = number_color
                    fg_color = 'white'
                
                btn = tk.Button(
                    button_frame,
                    text=button_text,
                    font=button_font,
                    bg=bg_color,
                    fg=fg_color,
                    activebackground=bg_color,
                    activeforeground='white',
                    bd=0,
                    cursor='hand2',
                    command=lambda x=button_text: self.on_button_click(x)
                )
                
                btn.grid(row=row_idx, column=col_idx, sticky='nsew', padx=5, pady=5)
                button_frame.grid_rowconfigure(row_idx, weight=1, minsize=70)
                button_frame.grid_columnconfigure(col_idx, weight=1, minsize=70)
                
    def on_button_click(self, char):
        """Handle button clicks"""
        if char == 'C':
            self.clear()
        elif char == '⌫':
            self.backspace()
        elif char == '=':
            self.calculate()
        elif char == '±':
            self.toggle_sign()
        elif char == '%':
            self.percentage()
        elif char in ['+', '-', '*', '/']:
            self.append_operator(char)
        else:
            self.append_number(char)
            
    def clear(self):
        """Clear the display"""
        self.current_value = ""
        self.display_value.set("0")
        
    def backspace(self):
        """Remove the last character"""
        if self.current_value:
            self.current_value = self.current_value[:-1]
            self.display_value.set(self.current_value if self.current_value else "0")
            
    def append_number(self, num):
        """Append a number or decimal point"""
        if num == '.' and '.' in self.get_current_number():
            return  # Don't allow multiple decimal points in one number
            
        if self.current_value == "" and num == '.':
            self.current_value = "0."
        elif self.display_value.get() == "0" and num != '.':
            self.current_value = num
        else:
            self.current_value += num
            
        self.display_value.set(self.current_value)
        
    def append_operator(self, operator):
        """Append an operator"""
        if self.current_value and self.current_value[-1] in ['+', '-', '*', '/']:
            # Replace the last operator
            self.current_value = self.current_value[:-1] + operator
        elif self.current_value:
            self.current_value += operator
        elif operator == '-':
            # Allow negative numbers at the start
            self.current_value = '-'
            
        self.display_value.set(self.current_value)
        
    def get_current_number(self):
        """Get the current number being entered"""
        for i in range(len(self.current_value) - 1, -1, -1):
            if self.current_value[i] in ['+', '-', '*', '/']:
                return self.current_value[i + 1:]
        return self.current_value
        
    def calculate(self):
        """Perform the calculation"""
        if not self.current_value:
            return
            
        try:
            # Replace visual multiplication/division symbols if needed
            expression = self.current_value
            
            # Evaluate the expression
            result = eval(expression)
            
            # Format the result
            if isinstance(result, float):
                # Remove trailing zeros and unnecessary decimal point
                result = f"{result:.10f}".rstrip('0').rstrip('.')
            else:
                result = str(result)
                
            self.current_value = result
            self.display_value.set(result)
            
        except (SyntaxError, ZeroDivisionError):
            self.display_value.set("Error")
            self.current_value = ""
        except Exception:
            self.display_value.set("Error")
            self.current_value = ""
            
    def toggle_sign(self):
        """Toggle the sign of the current number"""
        if not self.current_value:
            return
            
        current_num = self.get_current_number()
        if not current_num:
            return
            
        # Find where the current number starts
        prefix = self.current_value[:-len(current_num)]
        
        if current_num.startswith('-'):
            new_num = current_num[1:]
        else:
            new_num = '-' + current_num
            
        self.current_value = prefix + new_num
        self.display_value.set(self.current_value)
        
    def percentage(self):
        """Convert current number to percentage"""
        if not self.current_value:
            return
            
        current_num = self.get_current_number()
        if not current_num or current_num == '-':
            return
            
        try:
            value = float(current_num) / 100
            prefix = self.current_value[:-len(current_num)]
            self.current_value = prefix + str(value)
            self.display_value.set(self.current_value)
        except ValueError:
            pass


def main():
    root = tk.Tk()
    calculator = Calculator(root)
    root.mainloop()


if __name__ == "__main__":
    main()