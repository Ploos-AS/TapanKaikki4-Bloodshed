#include <cstdio>

int main()
{
    FILE *f = std::fopen("SYS:save/m3-tk4-objects-main.txt", "w");
    if (f) {
        std::fputs("TK4_OBJECTS_MAIN=1\n", f);
        std::fclose(f);
    }
    return 0;
}
