#include <stdio.h>

int main(void)
{
    FILE *f = fopen("SYS:save/m3-loader-probe.txt", "w");
    if (!f)
        return 20;
    fputs("M3_LOADER_PROBE=1\n", f);
    fclose(f);
    return 0;
}
