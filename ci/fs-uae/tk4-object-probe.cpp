#include <cstdio>

#ifndef PROBE_MARKER
#define PROBE_MARKER "SYS:save/m3-tk4-objects-main.txt"
#endif

#ifndef PROBE_LABEL
#define PROBE_LABEL "TK4_OBJECTS_MAIN=1\n"
#endif

int main()
{
    FILE *f = std::fopen(PROBE_MARKER, "w");
    if (f) {
        std::fputs(PROBE_LABEL, f);
        std::fclose(f);
    }
    return 0;
}
