#include <stdio.h>

#ifndef PROBE_MARKER
#define PROBE_MARKER "SYS:save/m3-probe-main.txt"
#endif

#ifndef PROBE_LABEL
#define PROBE_LABEL "PROBE_MAIN=1\n"
#endif

#ifndef PROBE_PAD_BYTES
#define PROBE_PAD_BYTES 0
#endif

#if PROBE_PAD_BYTES > 0
__attribute__((used, section(".text")))
static const unsigned char probe_text_padding[PROBE_PAD_BYTES] = { 0x4e };
#endif

int main()
{
    FILE *f = fopen(PROBE_MARKER, "w");
    if (f) {
        fputs(PROBE_LABEL, f);
        fclose(f);
    }
    return 0;
}
