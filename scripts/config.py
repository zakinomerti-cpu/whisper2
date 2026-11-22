import sys
import os
import platform

def hello():
    print("=" * 45)
    print("Python")
    print("=" * 45)
    
    # Базовая информация о среде
    print(f"Python Version : {sys.version.split()}")
    print(f"System       : {platform.system()} ({platform.architecture()})")
    print(f"Kodepage Fs  : {sys.getfilesystemencoding()}")
    print(f"Work dir : {os.getcwd()}")
    print(f"Current script: {__file__}")
    
    # Список путей, где Python ищет модули
    print("\n(sys.path):")
    for index, path in enumerate(sys.path):
        print(f"  [{index}] {path}")
        
    print("=" * 45)

# Проверка при прямом запуске
if __name__ == "__main__":
    hello()
