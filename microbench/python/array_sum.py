def build_and_sum(size):
    lst = []
    for i in range(size):
        lst.append(i)

    total = 0
    for item in lst:
        total += item
    return total


if __name__ == "__main__":
    result = build_and_sum(1000000)
    print(result)
