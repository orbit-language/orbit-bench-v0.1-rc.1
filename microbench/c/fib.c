#include <stdio.h>

long long fib(int n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

int main(void) {
    long long result = fib(32);
    printf("%lld\n", result);
    return 0;
}
