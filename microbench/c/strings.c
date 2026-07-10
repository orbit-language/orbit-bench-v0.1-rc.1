#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    size_t capacity = 64;
    size_t len = 0;
    char* result = (char*)malloc(capacity);
    result[0] = '\0';

    for (int i = 0; i < 50000; i++) {
        size_t needed = len + 1 + 1;
        if (needed > capacity) {
            capacity *= 2;
            result = (char*)realloc(result, capacity);
        }
        result[len] = 'x';
        result[len + 1] = '\0';
        len += 1;
    }

    printf("%zu\n", len);
    free(result);
    return 0;
}
