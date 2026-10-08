#include <cstdio>

#ifndef BISECT_GROUP
#define BISECT_GROUP "unknown"
#endif

int main()
{
    char path[128];
    std::snprintf(path, sizeof(path), "SYS:save/m3-bisect-%s-main.txt", BISECT_GROUP);
    FILE *f = std::fopen(path, "w");
    if (f) {
        std::fprintf(f, "BISECT_GROUP=%s\n", BISECT_GROUP);
        std::fclose(f);
    }
    return 0;
}
