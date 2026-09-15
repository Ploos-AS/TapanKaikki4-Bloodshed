#include <stdio.h>
#include <string>

struct ProbeCtor {
    ProbeCtor() {
        FILE* f = fopen("SYS:save/m3-cxx-ctor.txt", "w");
        if (f) {
            fputs("ctor\n", f);
            fclose(f);
        }
    }
};

static ProbeCtor g_probe_ctor;
static std::string g_probe_string("cxx-init-ok");

int main()
{
    FILE* f = fopen("SYS:save/m3-cxx-main.txt", "w");
    if (!f)
        return 20;
    fputs(g_probe_string.c_str(), f);
    fputs("\n", f);
    fclose(f);
    return 0;
}
