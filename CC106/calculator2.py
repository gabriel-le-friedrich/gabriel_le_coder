import tkinter as tk
import sys
import platform

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
        
        # Detect system theme
        self.is_dark_mode = self.detect_dark_mode()
        
        # Configure style
        self.setup_colors()
        self.root.configure(bg=self.colors['bg'])
        
        # Create display
        self.create_display()
        
        # Create buttons
        self.create_buttons()
    
    def detect_dark_mode(self):
        """Detect if system is in dark mode"""
        try:
            if platform.system() == "Darwin":  # macOS
                import subprocess
                result = subprocess.run(
                    ['defaults', 'read', '-g', 'AppleInterfaceStyle'],
                    capture_output=True,
                    text=True
                )
                return result.returncode == 0  # Returns 0 if dark mode is on
            elif platform.system() == "Windows":
                try:
                    import winreg
                    registry = winreg.ConnectRegistry(None, winreg.HKEY_CURRENT_USER)
                    key = winreg.OpenKey(registry, r'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize')
                    value, _ = winreg.QueryValueEx(key, 'AppsUseLightTheme')
                    winreg.CloseKey(key)
                    return value == 0  # 0 means dark mode
                except:
                    pass
            else:  # Linux and others
                # Try to detect from GTK settings
                try:
                    import subprocess
                    result = subprocess.run(
                        ['gsettings', 'get', 'org.gnome.desktop.interface', 'gtk-theme'],
                        capture_output=True,
                        text=True
                    )
                    return 'dark' in result.stdout.lower()
                except:
                    pass
        except:
            pass
        
        # Default to dark mode if detection fails
        return True
    
    def setup_colors(self):
        """Setup color scheme based on system theme"""
        if self.is_dark_mode:
            self.colors = {
                'bg': '#2b2b2b',
                'display_bg': '#1e1e1e',
                'display_fg': '#ffffff',
                'number_bg': '#505050',
                'number_fg': '#ffffff',
                'operator_bg': '#ff9500',
                'operator_fg': '#ffffff',
                'special_bg': '#3a3a3a',
                'special_fg': '#ffffff',
                'number_hover': '#666666',
                'operator_hover': '#ffad33',
                'special_hover': '#555555'
            }
        else:
            self.colors = {
                'bg': '#f0f0f0',
                'display_bg': '#ffffff',
                'display_fg': '#000000',
                'number_bg': '#e0e0e0',
                'number_fg': '#000000',
                'operator_bg': '#ff9500',
                'operator_fg': '#ffffff',
                'special_bg': '#d0d0d0',
                'special_fg': '#000000',
                'number_hover': '#c0c0c0',
                'operator_hover': '#ffad33',
                'special_hover': '#b0b0b0'
            }
    

    
    def create_display(self):
        display_frame = tk.Frame(self.root, bg=self.colors['bg'])
        display_frame.pack(expand=True, fill="both", padx=10, pady=(20, 10))
        
        display = tk.Entry(
            display_frame,
            textvariable=self.display_text,
            font=("Arial", 32, "bold"),
            bg=self.colors['display_bg'],
            fg=self.colors['display_fg'],
            bd=0,
            justify="right",
            state="readonly",
            readonlybackground=self.colors['display_bg']
        )
        display.pack(expand=True, fill="both", ipady=20)
    
    def create_buttons(self):
        button_frame = tk.Frame(self.root, bg=self.colors['bg'])
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
                # Determine button colors
                if button_text in ['/', '*', '-', '+', '=']:
                    bg_color = self.colors['operator_bg']
                    fg_color = self.colors['operator_fg']
                    hover_color = self.colors['operator_hover']
                elif button_text in ['C', '⌫', '%', '±']:
                    bg_color = self.colors['special_bg']
                    fg_color = self.colors['special_fg']
                    hover_color = self.colors['special_hover']
                else:
                    bg_color = self.colors['number_bg']
                    fg_color = self.colors['number_fg']
                    hover_color = self.colors['number_hover']
                
                btn = tk.Button(
                    button_frame,
                    text=button_text,
                    font=("Arial", 20, "bold"),
                    bg=bg_color,
                    fg=fg_color,
                    bd=0,
                    command=lambda x=button_text: self.on_button_click(x),
                    activebackground=hover_color,
                    activeforeground=fg_color,
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