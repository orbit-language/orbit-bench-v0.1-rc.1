#include <stdio.h>
#include <stdlib.h>

long long build_and_sum(int size) {
    int* list = (int*)malloc(sizeof(int) * size);
    for (int i = 0; i < size; i++) {
        list[i] = i;
    }

    long long total = 0;
    for (int i = 0; i < size; i++) {
        total += list[i];
    }

    free(list);
    return total;
}

int main(void) {
    long long result = build_and_sum(1000000);
    printf("%lld\n", result);
    return 0;
}
