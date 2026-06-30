def test_return() -> int:
    defer print("4. defer перед самым return")
    print("3. Внутри функции test_return")
    return 42 # <-- смысл жизни ыы 42 хехе

def main() -> int:
    print("Тест 1: Порядок LIFO")
    defer print("-> Третий (первый добавленный defer)")
    defer print("-> Второй (второй добавленный defer)")
    defer print("-> Первый (последний добавленный defer)")
    print("Основное тело")

    print("\n Тест 2: Область видимости (if)")
    if 1 == 1:
        defer print("-> Выход из блока IF")
        print("Внутри IF")
    print("Снаружи IF")

    print("\nТест 3: Блочный defer")
    defer:
        print("-> Блочный defer: строка 1")
        print("-> Блочный defer: строка 2")
    
    print("Тело перед блочным defer")

    print("\nТест 4: Перехват return")
    test_return()
    
    print("\nКонец функции main!")
    endofcode